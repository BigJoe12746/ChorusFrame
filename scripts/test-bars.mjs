// Tests for the visualizer's frequency-to-bar mapping.
//   node --experimental-strip-types scripts/test-bars.mjs

import { barLevels } from "../remotion/bars.ts";

let failures = 0;
const check = (name, cond, detail = "") => {
  if (!cond) failures++;
  console.log(`  ${cond ? "ok   " : "FAIL "} ${name}${detail && !cond ? ` — ${detail}` : ""}`);
};

// 128-bin spectra shaped like real visualizeAudio output: loud bass bins and
// a tail that decays fast (~c/i^1.5 across the mids on a typical mix; a loud
// modern master decays slower, ~c/i^1.2, and is what pins naive mappings).
const music = Array.from({ length: 128 }, (_, i) => (i === 0 ? 0.8 : 0.78 / Math.pow(i, 1.5)));
const loud = Array.from({ length: 128 }, (_, i) => (i === 0 ? 1.0 : 0.98 / Math.pow(i, 1.2)));
const quiet = Array.from({ length: 128 }, (_, i) => (i === 0 ? 0.25 : 0.2 / Math.pow(i, 1.5)));

console.log("shape:");
{
  const flat = new Array(128).fill(0.1);
  const levels = barLevels(flat, 32);
  check("one level per bar", levels.length === 32);
  check("levels stay in 0..1", levels.every((v) => v >= 0 && v <= 1));
  check("empty spectrum yields zeros", barLevels([], 32).every((v) => v === 0));
  check("zero bars yields empty", barLevels(flat, 0).length === 0);
}

console.log("typical music:");
{
  const m = barLevels(music, 32);
  const alive = m.filter((v) => v > 0.06).length;
  check(
    "at least 80% of bars visibly react (the frozen-right-half regression)",
    alive >= 26,
    `${alive}/32 alive`
  );
  check(
    "the silhouette decays left to right like an analyzer",
    m[0] > m[8] && m[8] > m[16] && m[16] > m[24],
    m.map((v) => v.toFixed(2)).join(" ")
  );
  const clones = m.slice(0, 8).some((v, i, a) => i > 0 && Math.abs(v - a[i - 1]) < 1e-6);
  check("no adjacent bars clone a bin and move in lockstep", !clones);
}

console.log("loud master (the frozen-at-max regression):");
{
  const l = barLevels(loud, 32);
  const pinned = l.filter((v) => v > 0.985).length;
  check("at most 2 bars graze full scale", pinned <= 2, `${pinned} pinned`);

  // The bass end must still MOVE when the bass moves, even at high loudness.
  const dipped = loud.map((v, i) => (i <= 6 ? v * 0.6 : v));
  const d = barLevels(dipped, 32);
  check(
    "a 40% bass dip visibly moves the bass bars",
    Math.abs(l[0] - d[0]) >= 0.04 && Math.abs(l[2] - d[2]) >= 0.04,
    `Δ0 ${(l[0] - d[0]).toFixed(3)} Δ2 ${(l[2] - d[2]).toFixed(3)}`
  );
}

console.log("dynamics:");
{
  const l = barLevels(loud, 32);
  const q = barLevels(quiet, 32);
  const moved = l.filter((v, i) => Math.abs(v - q[i]) > 0.05).length;
  check("loud vs quiet moves nearly every bar", moved >= 28, `${moved}/32 moved`);
  check("silence maps to zero", barLevels(new Array(128).fill(0), 32).every((v) => v === 0));
}

console.log("frequency ordering:");
{
  const bassOnly = Array.from({ length: 128 }, (_, i) => (i >= 1 && i <= 6 ? 0.5 : 0));
  const b = barLevels(bassOnly, 32);
  const bl = b.slice(0, 8).reduce((s, v) => s + v, 0);
  const br = b.slice(24).reduce((s, v) => s + v, 0);
  check("bass lights the left side", bl > 1 && br < 0.05, `left ${bl.toFixed(2)} right ${br.toFixed(2)}`);

  const trebleOnly = Array.from({ length: 128 }, (_, i) => (i >= 60 && i < 96 ? 0.03 : 0));
  const t = barLevels(trebleOnly, 32);
  const tl = t.slice(0, 8).reduce((s, v) => s + v, 0);
  const tr = t.slice(24).reduce((s, v) => s + v, 0);
  check("treble lights the right side", tr > tl, `left ${tl.toFixed(2)} right ${tr.toFixed(2)}`);
}

console.log("wide format (28 bars):");
{
  const m = barLevels(music, 28);
  const alive = m.filter((v) => v > 0.06).length;
  const pinned = barLevels(loud, 28).filter((v) => v > 0.985).length;
  check("28-bar mapping stays alive and unpinned", m.length === 28 && alive >= 22 && pinned <= 2,
    `${alive}/28 alive, ${pinned} pinned`);
}

if (failures) {
  console.error(`\n${failures} failure(s)`);
  process.exit(1);
}
console.log("\nall bar-mapping tests passed");
