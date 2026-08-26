// Tests for word-level karaoke and bar-synced scenes.
//   node --experimental-strip-types scripts/test-karaoke.mjs

import { activeWordIndex, sceneAt, syllables, windowLyrics, wordSpans } from "../remotion/karaoke.ts";

let failures = 0;
const check = (name, cond, detail = "") => {
  if (!cond) failures++;
  console.log(`  ${cond ? "ok   " : "FAIL "} ${name}${detail && !cond ? ` — ${detail}` : ""}`);
};
const near = (a, b, tol = 0.5) => Math.abs(a - b) <= tol;

console.log("word spans:");
{
  const spans = wordSpans("Late checkout I'm still here", 0, 90); // 3s at 30fps
  check("one span per word", spans.length === 5);
  check("starts at the line start", spans[0].startF === 0);
  check("ends before the line ends (breath gap)", spans[4].endF < 90 && spans[4].endF > 70,
    String(spans[4].endF));
  let mono = true;
  for (let i = 1; i < spans.length; i++) if (spans[i].startF < spans[i - 1].endF - 1e-6) mono = false;
  check("words never overlap", mono);

  const long = wordSpans("go supercalifragilistic now", 0, 120);
  const durs = long.map((s) => s.endF - s.startF);
  check("syllable weighting: long word holds longest", durs[1] > durs[0] * 3 && durs[1] > durs[2] * 2,
    durs.map((d) => d.toFixed(1)).join(","));

  check("empty line yields no spans", wordSpans("   ", 0, 60).length === 0);
  check("zero-length window yields no spans", wordSpans("hi there", 50, 50).length === 0);
}

console.log("\nactive word:");
{
  const spans = wordSpans("one two three", 30, 90);
  check("before the line: none", activeWordIndex(spans, 10) === -1);
  check("first frame: word one", activeWordIndex(spans, 30) === 0);
  const mid = Math.floor((spans[1].startF + spans[1].endF) / 2);
  check("mid-line: word two", activeWordIndex(spans, mid) === 1, `frame ${mid}`);
  check("after the line: holds the last word", activeWordIndex(spans, 500) === 2);
  check("no spans: -1", activeWordIndex([], 10) === -1);
}

console.log("\nwindowing (must match scripts/lib/align.mjs behaviour):");
{
  const full = [
    { text: "before", start: 2, end: 4 },
    { text: "inside", start: 11, end: 13 },
    { text: "straddles", start: 19, end: 22 },
  ];
  const w = windowLyrics(full, 10, 12);
  check("drops lines outside", w.length === 2);
  check("rebases", near(w[0].start, 1, 0.01));
  check("clamps the straddler", near(w[1].end, 12, 0.01));
}

console.log("\nscenes:");
{
  const grid = { bpm: 120, offset: 0 }; // bar = 2s, scene = 8s
  check("scene 0 at the start", sceneAt(1, grid, 30).index === 0);
  check("scene 1 after four bars", sceneAt(8.5, grid, 30).index === 1);
  check("scene 3 at 25s", sceneAt(25, grid, 30).index === 3);
  check("framesIn resets on the boundary", sceneAt(8.05, grid, 30).framesIn < 5,
    String(sceneAt(8.05, grid, 30).framesIn));
  const variants = new Set([sceneAt(1, grid, 30).variant, sceneAt(9, grid, 30).variant, sceneAt(17, grid, 30).variant]);
  check("three variants cycle", variants.size === 3);
  check("variant repeats on the fourth scene", sceneAt(25, grid, 30).variant === sceneAt(1, grid, 30).variant);

  check("no grid: single settled scene", sceneAt(30, null, 30).index === 0 && sceneAt(30, null, 30).framesIn > 1000);
  check("zero bpm: no divide-by-zero", Number.isFinite(sceneAt(5, { bpm: 0, offset: 0 }, 30).index));
  const grid143 = { bpm: 143, offset: 0.12 };
  const s = sceneAt(0.05, grid143, 30);
  check("before the first beat: settled scene 0", s.index === 0 && s.framesIn > 1000);
}

console.log(failures === 0 ? "\nPASS" : `\nFAIL — ${failures}`);
process.exit(failures === 0 ? 0 : 1);
