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
  onsetStrength,
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

console.log("\nwindow search is bounded:");
{
  const env = new Array(2000).fill(0.5);
  const best = findBestWindow(env, 0.02, 15, 900);
  check("never negative", best >= 0);
  check("leaves room for the clip", best + 15 <= 2000 * 0.02 + 0.01, `got ${best}`);
}

console.log(failures === 0 ? "\nPASS — hook detection behaves" : `\nFAIL — ${failures} problem(s)`);
process.exit(failures === 0 ? 0 : 1);
