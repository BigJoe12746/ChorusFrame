// How the visualizer turns FFT magnitudes into bar heights.

/**
 * Map FFT magnitudes to per-bar levels the eye can actually see move.
 *
 * Two failure modes bracket this problem. A linear bin slice dies on real
 * music: nearly all the energy sits below ~1kHz, so bars past the first third
 * idle at zero and the visualizer reads as frozen. Overcorrecting with hot
 * gain and a hard clamp fails the same way inverted: loud passages pin the
 * bass half at exactly 1.0, frame after frame — frozen at max instead.
 *
 * So: log-spaced bands (each bar covers a constant ratio of frequencies, like
 * a studio analyzer), sampled at three interpolated points so neighbouring
 * bars never clone a single bin and move in lockstep; a gain ramp that rises
 * toward treble, calibrated so a loud master lands near — not on — full
 * scale; and a soft knee instead of a clamp, so loudness compresses rather
 * than flatlines.
 *
 * Levels come back in 0..1 with the loudness curve applied, ready to use as
 * heights. Calibrated against 128-bin visualizeAudio spectra.
 */
export function barLevels(freq: readonly number[], count: number): number[] {
  if (freq.length < 8 || count <= 0) return new Array(Math.max(0, count)).fill(0);
  const lo = 1; // skip the DC bin
  const hi = Math.floor(freq.length * 0.75); // the very top is hiss
  const interp = (c: number) => {
    const j = Math.min(freq.length - 2, Math.max(0, Math.floor(c)));
    const f = Math.min(1, Math.max(0, c - j));
    return freq[j] * (1 - f) + freq[j + 1] * f;
  };
  const out: number[] = [];
  for (let i = 0; i < count; i++) {
    const t = i / Math.max(1, count - 1);
    const mag =
      (interp(lo * Math.pow(hi / lo, (i + 0.25) / count)) +
        interp(lo * Math.pow(hi / lo, (i + 0.5) / count)) +
        interp(lo * Math.pow(hi / lo, (i + 0.75) / count))) /
      3;
    // Treble carries far less energy than bass; the ramp keeps the right half
    // of the visualizer playing without driving the bass into the ceiling.
    const gain = 1.8 + 12 * Math.pow(t, 1.4);
    const drive = Math.pow(Math.max(0, mag * gain), 0.75);
    out.push(drive < 0.85 ? drive : 0.85 + 0.15 * Math.tanh((drive - 0.85) / 0.4));
  }
  return out;
}
