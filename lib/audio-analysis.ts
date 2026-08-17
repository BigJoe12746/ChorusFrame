// Finding the strongest moment in a song.
//
// The picker already decodes the artist's audio to draw a waveform, so the
// samples are right there. This turns them into a suggested clip window, which
// matters because the default was 0:00 — the intro of most tracks, and the one
// section nobody would post.
//
// Deliberately no DOM and no Web Audio types, so it can be tested in Node
// (npm run test:audio).

export type Analysis = {
  /** Loudness per frame, normalised 0..1. */
  envelope: number[];
  /** Seconds covered by one envelope frame. */
  frameSeconds: number;
  /** Estimated tempo, or null when nothing convincing was found. */
  tempo: number | null;
  /** Tempo plus the phase needed to animate on the beat rather than near it. */
  beatGrid: { bpm: number; offset: number } | null;
  /** Suggested clip start, in seconds. */
  bestStart: number;
};

const HOP_SECONDS = 0.02; // 50 frames a second

/** RMS loudness per frame. */
export function energyEnvelope(samples: ArrayLike<number>, sampleRate: number): number[] {
  const hop = Math.max(1, Math.round(sampleRate * HOP_SECONDS));
  const frames = Math.floor(samples.length / hop);
  const out: number[] = new Array(frames);
  for (let f = 0; f < frames; f++) {
    let sum = 0;
    const start = f * hop;
    // Stride the window: full precision buys nothing at this resolution and
    // a 5-minute track is millions of samples.
    for (let i = 0; i < hop; i += 4) {
      const v = samples[start + i] ?? 0;
      sum += v * v;
    }
    out[f] = Math.sqrt(sum / Math.ceil(hop / 4));
  }
  const max = Math.max(...out, 1e-9);
  return out.map((v) => v / max);
}

/** Half-wave rectified difference — where the music gets suddenly louder. */
export function onsetStrength(envelope: number[]): number[] {
  const out = new Array(envelope.length).fill(0);
  for (let i = 1; i < envelope.length; i++) {
    out[i] = Math.max(0, envelope[i] - envelope[i - 1]);
  }
  return out;
}

/**
 * Tempo by autocorrelating the onset envelope over musically plausible lags
 * (60–180 BPM). Returns null when no lag stands out, rather than inventing a
 * number for something arrhythmic.
 */
export function estimateTempo(onsets: number[], frameSeconds = HOP_SECONDS): number | null {
  if (onsets.length < 200) return null;
  const minLag = Math.round(60 / 180 / frameSeconds); // 180 BPM
  const maxLag = Math.round(60 / 60 / frameSeconds); // 60 BPM
  let bestLag = -1;
  let best = 0;
  let total = 0;
  let count = 0;

  for (let lag = minLag; lag <= maxLag && lag < onsets.length; lag++) {
    let sum = 0;
    for (let i = 0; i + lag < onsets.length; i++) sum += onsets[i] * onsets[i + lag];
    const score = sum / (onsets.length - lag);
    total += score;
    count++;
    if (score > best) {
      best = score;
      bestLag = lag;
    }
  }
  if (bestLag < 0 || count === 0) return null;
  // Require the winner to stand clearly above the average lag, or we're just
  // reading noise.
  if (best < (total / count) * 1.25) return null;

  // Autocorrelation happily locks onto half or double the real tempo — a
  // 128 BPM track reads as 64. Fold into the 90–180 range where nearly all
  // popular music sits, so the number shown to an artist is the one they'd
  // recognise.
  let bpm = 60 / (bestLag * frameSeconds);
  while (bpm < 90) bpm *= 2;
  while (bpm > 180) bpm /= 2;
  return Math.round(bpm);
}

/**
 * Where the beats actually fall.
 *
 * Tempo alone isn't enough to animate to: 143 BPM tells you how often a beat
 * happens, not when the first one lands. Without the phase, motion lands
 * between beats and reads as random.
 *
 * Phase is found by trying every offset within one beat period and keeping the
 * one where the most onset energy piles up on the grid.
 */
export function detectBeatGrid(
  onsets: number[],
  frameSeconds = HOP_SECONDS,
  bpm?: number | null
): { bpm: number; offset: number } | null {
  const tempo = bpm ?? estimateTempo(onsets, frameSeconds);
  if (!tempo) return null;

  const periodFrames = 60 / tempo / frameSeconds;
  if (!Number.isFinite(periodFrames) || periodFrames < 2) return null;

  let bestOffset = 0;
  let bestScore = -1;
  const steps = Math.max(1, Math.round(periodFrames));
  for (let s = 0; s < steps; s++) {
    const offset = (s / steps) * periodFrames;
    let score = 0;
    for (let f = offset; f < onsets.length; f += periodFrames) {
      // Sample either side of the exact index; a beat rarely lands dead on a
      // 20ms frame boundary.
      const i = Math.round(f);
      score += (onsets[i] ?? 0) + 0.5 * ((onsets[i - 1] ?? 0) + (onsets[i + 1] ?? 0));
    }
    if (score > bestScore) {
      bestScore = score;
      bestOffset = offset;
    }
  }
  return {
    bpm: tempo,
    offset: Math.round(bestOffset * frameSeconds * 1000) / 1000,
  };
}

/**
 * How hard the visuals should hit at a given moment in the song.
 *
 * Returns 1 at the instant of a beat and decays to 0 well before the next one,
 * so the shape is a kick rather than a sine wave. Downbeats (every fourth
 * beat) hit harder, which is what makes motion feel arranged instead of merely
 * periodic.
 *
 * Lives here rather than inside the composition so it can be tested without
 * rendering a frame — pixel measurements can't separate the pulse from the
 * artwork's slow rotation.
 */
export function beatHitAt(
  songSeconds: number,
  grid: { bpm: number; offset: number } | null | undefined,
  { decayFraction = 0.4, offbeatStrength = 0.6 } = {}
): number {
  if (!grid?.bpm || grid.bpm <= 0) return 0;
  const period = 60 / grid.bpm;
  const since = songSeconds - grid.offset;
  if (!Number.isFinite(since)) return 0;
  const phase = ((since % period) + period) % period;
  const beatIndex = Math.floor(since / period);
  const isDownbeat = ((beatIndex % 4) + 4) % 4 === 0;
  const decay = Math.max(0, 1 - phase / (period * decayFraction));
  return Math.pow(decay, 2.2) * (isDownbeat ? 1 : offbeatStrength);
}

/**
 * Score every candidate window and return the loudest sustained one.
 *
 * Loudness alone is a decent proxy for "the chorus": it's where the full
 * arrangement and the vocal are. Openings are penalised because an intro that
 * happens to be loud still isn't the hook.
 */
export function findBestWindow(
  envelope: number[],
  frameSeconds: number,
  clipDuration: number,
  maxStart: number
): number {
  const windowFrames = Math.max(1, Math.round(clipDuration / frameSeconds));
  const songSeconds = envelope.length * frameSeconds;
  const limit = Math.max(0, Math.min(maxStart, songSeconds - clipDuration));
  if (limit <= 0 || envelope.length <= windowFrames) return 0;

  // Rolling mean, so this stays linear on long tracks
  let sum = 0;
  for (let i = 0; i < windowFrames; i++) sum += envelope[i];

  let bestScore = -Infinity;
  let bestFrame = 0;
  const stepFrames = Math.max(1, Math.round(0.25 / frameSeconds));
  const limitFrame = Math.round(limit / frameSeconds);

  for (let f = 0; f <= limitFrame; f++) {
    if (f > 0) {
      sum += envelope[f + windowFrames - 1] ?? 0;
      sum -= envelope[f - 1];
    }
    if (f % stepFrames !== 0) continue;

    const seconds = f * frameSeconds;
    let score = sum / windowFrames;
    // Intros are rarely the hook; taper the penalty over the first 20s.
    if (seconds < 20) score *= 0.75 + 0.25 * (seconds / 20);
    if (score > bestScore) {
      bestScore = score;
      bestFrame = f;
    }
  }
  return bestFrame * frameSeconds;
}

/**
 * Nudge a start onto the nearest strong onset so the clip opens on a hit
 * rather than halfway through a bar.
 */
export function snapToOnset(
  onsets: number[],
  frameSeconds: number,
  startSeconds: number,
  windowSeconds = 1.0
): number {
  const centre = Math.round(startSeconds / frameSeconds);
  const radius = Math.round(windowSeconds / frameSeconds);
  let best = centre;
  let bestVal = -1;
  for (let f = Math.max(0, centre - radius); f <= Math.min(onsets.length - 1, centre + radius); f++) {
    if (onsets[f] > bestVal) {
      bestVal = onsets[f];
      best = f;
    }
  }
  return Math.max(0, Math.round(best * frameSeconds * 10) / 10);
}

/** Everything the picker needs, from raw samples. */
export function analyzeAudio(
  samples: ArrayLike<number>,
  sampleRate: number,
  clipDuration: number,
  maxStart: number
): Analysis {
  const envelope = energyEnvelope(samples, sampleRate);
  const onsets = onsetStrength(envelope);
  const rough = findBestWindow(envelope, HOP_SECONDS, clipDuration, maxStart);
  const snapped = snapToOnset(onsets, HOP_SECONDS, rough);
  const songSeconds = envelope.length * HOP_SECONDS;
  const limit = Math.max(0, Math.min(maxStart, songSeconds - clipDuration));
  const tempo = estimateTempo(onsets);
  return {
    envelope,
    frameSeconds: HOP_SECONDS,
    tempo,
    beatGrid: detectBeatGrid(onsets, HOP_SECONDS, tempo),
    bestStart: Math.min(limit, snapped),
  };
}
