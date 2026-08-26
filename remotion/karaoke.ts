// Word-level karaoke, from line-level timing.
//
// We usually know when a LINE is sung (tapped by the artist, or aligned), not
// each word. Rather than wait for word-level transcription, words are placed
// inside their line by syllable weight: "supercalifragilistic" holds longer
// than "go". Within a 1–4 second line that estimate tracks the vocal closely,
// because the anchor points — line start and end — are human-set.
//
// Pure math, no I/O: the same code runs in the live preview and the render,
// which is what keeps "the preview matches the export" true here too.
//
// The syllable counter is duplicated from scripts/lib/align.mjs (the worker
// can't import TS, the app can't ship scripts/). Both have regression tests.

export type WordSpan = { text: string; startF: number; endF: number };

export function syllables(word: string): number {
  const w = word
    .normalize("NFC")
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^\p{L}\p{N}]/gu, "");
  if (!w) return 0;
  if (w.length <= 3) return 1;
  const groups = w
    .replace(/(?:[^laeiouy]es|ed|[^laeiouy]e)$/, "")
    .replace(/^y/, "")
    .match(/[aeiouy]{1,2}/g);
  return Math.max(1, groups ? groups.length : 1);
}

/**
 * Place a line's words across its frame window, weighted by syllables.
 * The last ~12% of the window is left as breath: a sung line ends slightly
 * before the next begins, and holding the final word through the gap reads
 * wrong.
 */
export function wordSpans(text: string, startF: number, endF: number): WordSpan[] {
  const words = text.split(/\s+/).filter(Boolean);
  if (!words.length || endF <= startF) return [];

  const weights = words.map((w) => Math.max(1, syllables(w)));
  const total = weights.reduce((a, b) => a + b, 0);
  const usable = (endF - startF) * 0.88;

  const out: WordSpan[] = [];
  let t = startF;
  for (let i = 0; i < words.length; i++) {
    const dur = (weights[i] / total) * usable;
    out.push({ text: words[i], startF: t, endF: i === words.length - 1 ? startF + usable : t + dur });
    t += dur;
  }
  return out;
}

/** Which word is being sung at this frame; -1 before the first, last after. */
export function activeWordIndex(spans: WordSpan[], frame: number): number {
  if (!spans.length) return -1;
  if (frame < spans[0].startF) return -1;
  for (let i = 0; i < spans.length; i++) {
    if (frame < spans[i].endF) return i;
  }
  return spans.length - 1;
}

/**
 * Rebase song-absolute line timings into a clip window, in seconds.
 * Browser-side twin of timingsForWindow in scripts/lib/align.mjs — the preview
 * needs it and cannot import from scripts/ (excluded from the deploy).
 */
export function windowLyrics(
  timings: { text: string; start: number; end: number }[],
  windowStart: number,
  windowDuration: number
): { text: string; start: number; end: number }[] {
  const windowEnd = windowStart + windowDuration;
  return (timings ?? [])
    .filter((l) => l.end > windowStart && l.start < windowEnd)
    .map((l) => ({
      text: l.text,
      start: Math.max(0, l.start - windowStart),
      end: Math.min(windowDuration, l.end - windowStart),
    }))
    .filter((l) => l.end > l.start);
}

/**
 * Bar-synced scenes: which visual variant is on, and how far into it we are.
 *
 * A clip that never changes reads as generated; one that shifts treatment on
 * a bar boundary reads as edited. Four bars per scene gives a change roughly
 * every 6–8 seconds at common tempos — enough movement to feel cut to the
 * music, not so much it strobes.
 */
export function sceneAt(
  songSeconds: number,
  grid: { bpm: number; offset: number } | null | undefined,
  fps: number,
  barsPerScene = 4
): { index: number; framesIn: number; variant: number } {
  if (!grid?.bpm || grid.bpm <= 0) return { index: 0, framesIn: Number.MAX_SAFE_INTEGER, variant: 0 };
  const barSeconds = (60 / grid.bpm) * 4;
  const sceneSeconds = barSeconds * barsPerScene;
  const since = songSeconds - grid.offset;
  // Before the first beat there is no scene yet; treat as scene 0, long-settled
  if (since < 0 || !Number.isFinite(since)) {
    return { index: 0, framesIn: Number.MAX_SAFE_INTEGER, variant: 0 };
  }
  const index = Math.floor(since / sceneSeconds);
  const into = since - index * sceneSeconds;
  return { index, framesIn: Math.floor(into * fps), variant: ((index % 3) + 3) % 3 };
}
