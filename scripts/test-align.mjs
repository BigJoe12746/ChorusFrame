// Tests for lyric alignment.  node scripts/test-align.mjs
//
// The interesting cases are the ways a transcriber gets it WRONG: mishearing
// words, dropping them, hallucinating extras. Alignment has to survive all of
// that and still put the official line on screen at the right moment.

import {
  alignLyrics,
  alignWords,
  estimateTimings,
  normalizeWord,
  similarity,
  splitLines,
  syllables,
  timingsForWindow,
} from "./lib/align.mjs";

let failures = 0;
const check = (name, cond, detail = "") => {
  if (!cond) failures++;
  console.log(`  ${cond ? "ok   " : "FAIL "} ${name}${detail && !cond ? ` — ${detail}` : ""}`);
};
const near = (a, b, tol = 0.35) => Math.abs(a - b) <= tol;

console.log("normalize + syllables:");
check("strips punctuation and case", normalizeWord("Runnin',") === "runnin");
check("handles curly apostrophes", normalizeWord("don’t") === "dont");
check("one syllable: run", syllables("run") === 1);
check("two syllables: midnight", syllables("midnight") === 2);
check("three syllables: everything >= 3", syllables("everything") >= 3);
check("silent e: name is 1", syllables("name") === 1);

console.log("\nsimilarity:");
check("identical = 1", similarity("run", "run") === 1);
check("near miss is high", similarity("running", "runnin") > 0.8);
check("unrelated is low", similarity("midnight", "banana") < 0.4);

console.log("\nword alignment against an imperfect transcript:");
{
  const official = ["city", "lights", "are", "calling", "out", "my", "name"];
  // transcriber misheard "lights"->"nights", dropped "are", added "uh"
  const heard = ["city", "nights", "uh", "calling", "out", "my", "name"];
  const map = alignWords(official, heard);
  check("city -> 0", map[0] === 0);
  check("lights matches misheard nights", map[1] === 1, `got ${map[1]}`);
  check("dropped word maps to nothing", map[2] === null, `got ${map[2]}`);
  check("calling realigns after the gap", map[3] === 3, `got ${map[3]}`);
  check("name -> last", map[6] === 6, `got ${map[6]}`);
}

console.log("\nfull alignment, clean transcript:");
{
  const lyrics = "City lights are calling\nFoot down chasing flame";
  const words = [
    { word: "city", start: 10.0, end: 10.4 },
    { word: "lights", start: 10.4, end: 10.9 },
    { word: "are", start: 10.9, end: 11.1 },
    { word: "calling", start: 11.1, end: 11.8 },
    { word: "foot", start: 13.0, end: 13.3 },
    { word: "down", start: 13.3, end: 13.7 },
    { word: "chasing", start: 13.7, end: 14.2 },
    { word: "flame", start: 14.2, end: 14.9 },
  ];
  const t = alignLyrics(lyrics, words, 30);
  check("two lines", t.length === 2);
  check("line 1 starts at the first word", near(t[0].start, 10.0), `got ${t[0].start}`);
  check("line 1 ends at its last word", near(t[0].end, 11.8), `got ${t[0].end}`);
  check("line 2 starts at 13.0", near(t[1].start, 13.0), `got ${t[1].start}`);
  check("line 2 ends at 14.9", near(t[1].end, 14.9), `got ${t[1].end}`);
  check("no overlap", t[0].end <= t[1].start);
}

console.log("\nfull alignment, transcriber dropped a whole line:");
{
  const lyrics = "First line here\nSecond line missing\nThird line here";
  const words = [
    { word: "first", start: 5.0, end: 5.4 },
    { word: "line", start: 5.4, end: 5.8 },
    { word: "here", start: 5.8, end: 6.2 },
    // second line never transcribed
    { word: "third", start: 12.0, end: 12.4 },
    { word: "line", start: 12.4, end: 12.8 },
    { word: "here", start: 12.8, end: 13.2 },
  ];
  const t = alignLyrics(lyrics, words, 30);
  check("still three lines", t.length === 3);
  check("missing line lands between its neighbours", t[1].start >= 6.0 && t[1].end <= 12.5,
    `got ${t[1].start.toFixed(1)}-${t[1].end.toFixed(1)}`);
  check("order preserved", t[0].end <= t[1].start && t[1].end <= t[2].start + 0.01);
  check("last line still correct", near(t[2].start, 12.0), `got ${t[2].start}`);
}

console.log("\nmonotonicity and clamping:");
{
  const t = alignLyrics("one\ntwo\nthree", [
    { word: "one", start: 9.0, end: 9.5 },
    { word: "two", start: 8.0, end: 8.5 }, // out-of-order transcript
    { word: "three", start: 40.0, end: 41.0 }, // past the end
  ], 20);
  let mono = true;
  for (let i = 1; i < t.length; i++) if (t[i].start < t[i - 1].end - 1e-9) mono = false;
  check("never goes backwards", mono, t.map((l) => `${l.start.toFixed(1)}-${l.end.toFixed(1)}`).join(" "));
  check("clamped to audio length", t.every((l) => l.end <= 20.0001));
}

console.log("\nno transcript at all (fallback):");
{
  const t = alignLyrics("a\nsupercalifragilistic expialidocious phrase\nb", [], 30);
  check("marked as estimated", t.every((l) => l.estimated));
  const short = t[0].end - t[0].start;
  const long = t[1].end - t[1].start;
  check("long line gets more time than short", long > short * 2, `${short.toFixed(2)} vs ${long.toFixed(2)}`);
  check("covers the window in order", t[0].start === 0 && t[2].end > t[1].end);
}

console.log("\nsyllable-weighted estimate:");
{
  const t = estimateTimings(["go", "everything is complicated"], 0, 12);
  check("weights by syllables not line count", t[1].end - t[1].start > t[0].end - t[0].start);
  check("fills the window exactly", near(t[1].end, 12, 0.01), `got ${t[1].end}`);
}

console.log("\nwindowing a clip out of a full song:");
{
  const full = [
    { text: "before", start: 2, end: 4 },
    { text: "inside", start: 11, end: 13 },
    { text: "straddles", start: 19, end: 22 },
    { text: "after", start: 40, end: 42 },
  ];
  // Window is 10s..22s, so only "inside" and "straddles" survive
  const w = timingsForWindow(full, 10, 12);
  check("drops lines outside the window", w.length === 2, `got ${w.length}`);
  check("keeps the right ones", w[0].text === "inside" && w[1].text === "straddles");
  check("rebases to window start", near(w[0].start, 1), `got ${w[0].start}`);
  check("clamps a straddling line to the window", near(w[1].end, 12), `got ${w[1].end}`);
  check("never negative", w.every((l) => l.start >= 0));
}

console.log("\nline splitting:");
{
  const long = "word ".repeat(40).trim();
  const lines = splitLines(`short line\n${long}`);
  check("re-wraps a paragraph", lines.length > 2);
  check("respects the max width", lines.every((l) => l.length <= 90));
  check("keeps short lines intact", lines[0] === "short line");
}

console.log(failures === 0 ? "\nPASS — alignment behaves" : `\nFAIL — ${failures} problem(s)`);
process.exit(failures === 0 ? 0 : 1);
