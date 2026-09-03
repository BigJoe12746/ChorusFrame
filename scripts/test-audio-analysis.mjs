// Tests for hook detection.  node --experimental-strip-types scripts/test-audio-analysis.mjs
//
// Built from synthesized audio where the right answer is known: a quiet intro,
// a loud chorus in a specific place, a quiet outro. The suggestion has to land
// on the chorus, not on the opening.

import {
  analyzeAudio,
  energyEnvelope,
  estimateTempo,
  findBestWindow,
  findHookCandidates,
  onsetStrength,
  rankHooks,
  snapToOnset,
} from "../lib/audio-analysis.ts";

const SR = 22050;
let failures = 0;
const check = (name, cond, detail = "") => {
  if (!cond) failures++;
  console.log(`  ${cond ? "ok   " : "FAIL "} ${name}${detail && !cond ? ` — ${detail}` : ""}`);
};

/** Build a song: sections of [seconds, amplitude], optional beat at bpm. */
function song(sections, bpm = 0) {
  const total = sections.reduce((s, [secs]) => s + secs, 0);
  const out = new Float32Array(Math.round(total * SR));
  let t = 0;
  for (const [secs, amp] of sections) {
    const from = Math.round(t * SR);
    const to = Math.round((t + secs) * SR);
    for (let i = from; i < to; i++) {
      const time = i / SR;
      let v = Math.sin(2 * Math.PI * 220 * time) * amp;
      if (bpm) {
        // a percussive transient on every beat
        const beat = 60 / bpm;
        const phase = time % beat;
        if (phase < 0.03) v += amp * 1.6 * Math.exp(-phase * 90) * (Math.random() * 2 - 1);
      }
      out[i] = v;
    }
    t += secs;
  }
  return out;
}

console.log("energy envelope:");
{
  const s = song([[2, 0.1], [2, 1.0]]);
  const env = energyEnvelope(s, SR);
  const half = Math.floor(env.length / 2);
  const quiet = env.slice(0, half).reduce((a, b) => a + b, 0) / half;
  const loud = env.slice(half).reduce((a, b) => a + b, 0) / (env.length - half);
  check("tracks loudness", loud > quiet * 3, `quiet ${quiet.toFixed(3)} loud ${loud.toFixed(3)}`);
  check("normalised to 1", Math.max(...env) <= 1.0001);
  check("frame count ≈ 50/s", Math.abs(env.length - 4 * 50) < 6, `got ${env.length}`);
}

console.log("\nfinds the chorus, not the intro:");
{
  // 30s quiet intro, 30s loud chorus at 0:30, 20s quiet outro
  const s = song([[30, 0.15], [30, 1.0], [20, 0.15]]);
  const a = analyzeAudio(s, SR, 15, 900);
  check("suggests inside the loud section", a.bestStart >= 28 && a.bestStart <= 46,
    `got ${a.bestStart.toFixed(1)}s`);
  check("does not suggest the intro", a.bestStart > 20, `got ${a.bestStart.toFixed(1)}s`);
}

console.log("\nprefers a later hook over an equally loud opening:");
{
  // Loud opening AND a loud chorus later — the intro penalty should break the tie
  const s = song([[20, 1.0], [20, 0.2], [20, 1.0]]);
  const a = analyzeAudio(s, SR, 15, 900);
  check("skips the loud intro", a.bestStart > 20, `got ${a.bestStart.toFixed(1)}s`);
}

console.log("\nrespects the start ceiling:");
{
  const s = song([[10, 0.2], [40, 1.0]]);
  const a = analyzeAudio(s, SR, 15, 12); // never start later than 12s
  check("never exceeds maxStart", a.bestStart <= 12.0001, `got ${a.bestStart}`);
}

console.log("\nhandles songs shorter than the clip:");
{
  const s = song([[8, 0.5]]);
  const a = analyzeAudio(s, SR, 15, 900);
  check("returns 0 rather than negative", a.bestStart === 0, `got ${a.bestStart}`);
  check("no NaN", Number.isFinite(a.bestStart));
}

console.log("\ntempo:");
{
  const s = song([[20, 0.8]], 120);
  const env = energyEnvelope(s, SR);
  const bpm = estimateTempo(onsetStrength(env));
  // Octave errors are inherent to autocorrelation, so the result is folded
  // into 90–180; a 120 BPM track must report 120, not 60.
  check("reports 120 BPM, not its octave", bpm !== null && Math.abs(bpm - 120) <= 6, `got ${bpm}`);
  check("always inside the musical range", bpm === null || (bpm >= 90 && bpm <= 180), `got ${bpm}`);
}
{
  const flat = new Float32Array(SR * 5).fill(0.3); // steady tone, no beat
  const bpm = estimateTempo(onsetStrength(energyEnvelope(flat, SR)));
  check("returns null for arrhythmic audio rather than guessing", bpm === null, `got ${bpm}`);
}

console.log("\nsnapping to an onset:");
{
  const env = new Array(500).fill(0.2);
  env[250] = 0.2; // quiet
  const onsets = new Array(500).fill(0);
  onsets[262] = 1; // strong hit 0.24s after our target
  const snapped = snapToOnset(onsets, 0.02, 5.0, 1.0);
  check("moves onto the nearby hit", Math.abs(snapped - 262 * 0.02) < 0.05, `got ${snapped}`);
  const none = snapToOnset(new Array(500).fill(0), 0.02, 5.0, 1.0);
  check("stays put when there is no onset", Math.abs(none - 4.0) < 1.05, `got ${none}`);
}

console.log("\nthree hooks, not one:");
{
  // Two loud choruses in known places, well apart, with a quiet bridge between.
  const samples = song([
    [20, 0.15], // intro
    [20, 0.9],  // chorus one at 0:20
    [20, 0.2],  // verse
    [20, 0.85], // chorus two at 1:00
    [15, 0.1],  // outro
  ]);
  const env = energyEnvelope(samples, SR);
  const ons = onsetStrength(env);

  const picks = findHookCandidates(env, 0.02, 15, 900, 3);
  check("returns several moments", picks.length >= 2, `got ${picks.length}`);
  check("best first", picks.every((p, i) => i === 0 || picks[i - 1].score >= p.score));

  // The point of suppression: distinct moments, not one chorus sampled thrice.
  let apart = true;
  for (let i = 0; i < picks.length; i++)
    for (let j = i + 1; j < picks.length; j++)
      if (Math.abs(picks[i].start - picks[j].start) < 15) apart = false;
  check("picks are at least a clip apart", apart, picks.map((p) => p.start.toFixed(1)).join(", "));

  const starts = picks.map((p) => p.start);
  check(
    "finds both choruses",
    starts.some((v) => v >= 18 && v <= 38) && starts.some((v) => v >= 58 && v <= 78),
    starts.map((v) => v.toFixed(1)).join(", ")
  );

  // Every pick must leave room for the clip it promises.
  const songSeconds = env.length * 0.02;
  check("every pick leaves room for the clip", picks.every((p) => p.start + 15 <= songSeconds + 0.01));

  // The headline suggestion must not disagree with the ranked list.
  const a = analyzeAudio(samples, SR, 15, 900);
  check(
    "bestStart is the top candidate",
    Math.abs(a.bestStart - a.candidates[0].start) < 0.01,
    `${a.bestStart} vs ${a.candidates[0]?.start}`
  );
  check("onsets are kept for re-ranking", Array.isArray(a.onsets) && a.onsets.length === env.length);

  // Re-ranking for a longer clip must work off the retained envelope alone.
  const longer = rankHooks(env, ons, 0.02, 30, 900, 3);
  check("re-ranks for a longer clip without re-decoding", longer.length >= 1);
  check(
    "longer picks still fit",
    longer.every((p) => p.start + 30 <= songSeconds + 0.01),
    longer.map((p) => p.start.toFixed(1)).join(", ")
  );

  // A song barely longer than the clip has one honest answer, not three.
  const tiny = energyEnvelope(song([[16, 0.5]]), SR);
  const few = findHookCandidates(tiny, 0.02, 15, 900, 3);
  check("a short song yields at least one usable pick", few.length >= 1 && few[0].start + 15 <= 16.01);
}

console.log("\nwindow search is bounded:");
{
  const env = new Array(2000).fill(0.5);
  const best = findBestWindow(env, 0.02, 15, 900);
  check("never negative", best >= 0);
  check("leaves room for the clip", best + 15 <= 2000 * 0.02 + 0.01, `got ${best}`);
}

// ---- beat grid ----
// Tempo says how often; phase says when. Getting phase wrong makes motion land
// between beats, which reads as random rather than musical.
{
  const { detectBeatGrid, onsetStrength, energyEnvelope } = await import("../lib/audio-analysis.ts");
  console.log("\nbeat grid:");

  /** Clicks at a known bpm, starting at a known offset. */
  function clicks(bpm, offsetSec, seconds) {
    const out = new Float32Array(Math.round(seconds * SR));
    const period = 60 / bpm;
    for (let t = offsetSec; t < seconds; t += period) {
      const i = Math.round(t * SR);
      for (let j = 0; j < Math.round(0.03 * SR); j++) {
        if (i + j < out.length) out[i + j] = Math.exp(-j / (SR * 0.006)) * (j % 7 < 4 ? 1 : -1);
      }
    }
    return out;
  }

  for (const [bpm, offset] of [[120, 0], [120, 0.25], [143, 0.12], [90, 0.4]]) {
    const grid = detectBeatGrid(onsetStrength(energyEnvelope(clicks(bpm, offset, 24), SR)), 0.02);
    if (!grid) {
      check(`${bpm}bpm @${offset}s detected`, false, "returned null");
      continue;
    }
    const period = 60 / bpm;
    // Phase is circular: being one whole beat out is the same grid
    const err = Math.min(
      Math.abs(grid.offset - offset),
      Math.abs(Math.abs(grid.offset - offset) - period)
    );
    check(`${bpm}bpm tempo`, Math.abs(grid.bpm - bpm) <= 2, `got ${grid.bpm}`);
    check(`${bpm}bpm phase within 60ms`, err < 0.06, `off by ${(err * 1000).toFixed(0)}ms`);
  }

  const silence = detectBeatGrid(onsetStrength(energyEnvelope(new Float32Array(SR * 10), SR)), 0.02);
  check("silence yields no grid rather than a made-up one", silence === null, JSON.stringify(silence));
}


// ---- beat hit shape ----
// This is what actually drives the motion, so it's tested directly: pixel
// measurements can't separate the pulse from the artwork's slow rotation.
{
  const { beatHitAt } = await import("../lib/audio-analysis.ts");
  console.log("");
  console.log("beat hit:");
  const grid = { bpm: 128, offset: 0 };      // a beat every 0.46875s
  const period = 60 / 128;

  check("peaks exactly on the beat", beatHitAt(0, grid) === 1);
  check("still strong 25ms after", beatHitAt(0.025, grid) > 0.6, String(beatHitAt(0.025, grid)));
  check("gone by mid-bar", beatHitAt(period * 0.5, grid) === 0, String(beatHitAt(period * 0.5, grid)));
  check("fires again on the next beat", beatHitAt(period * 4, grid) === 1);

  const down = beatHitAt(0, grid);
  const off = beatHitAt(period, grid);
  check("downbeat hits harder than the offbeat", down > off, `${down} vs ${off}`);

  // Motion must follow the PHASE, not just the tempo
  const shifted = { bpm: 128, offset: 0.2 };
  check("respects the offset", beatHitAt(0.2, shifted) === 1 && beatHitAt(0, shifted) < 1);

  check("no grid means no beat motion", beatHitAt(5, null) === 0);
  check("zero bpm is ignored rather than dividing", beatHitAt(5, { bpm: 0, offset: 0 }) === 0);
  check("survives a negative time", Number.isFinite(beatHitAt(-3, grid)));

  // The value feeds a scale multiplier, so it must stay in range
  let outOfRange = 0;
  for (let t = 0; t < 12; t += 0.017) {
    const v = beatHitAt(t, grid);
    if (!(v >= 0 && v <= 1)) outOfRange++;
  }
  check("always within 0..1", outOfRange === 0, `${outOfRange} samples outside`);
}

console.log(failures === 0 ? "\nPASS" : `\nFAIL — ${failures}`);
process.exit(failures === 0 ? 0 : 1);
