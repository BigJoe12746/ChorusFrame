// Lyric alignment.
//
// The artist pastes the OFFICIAL lyrics; a transcriber returns what it *heard*
// with word-level timestamps. Those two disagree constantly — music is hard to
// transcribe, and singers stretch, repeat, and swallow words. So we don't show
// the transcript: we align it to the official words and borrow its timings.
//
// Nothing here talks to a network or a database, which keeps the interesting
// part testable on its own (npm run test:align).

/** Strip punctuation/case so "Runnin'," and "running" can match. */
export function normalizeWord(word) {
  return word
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^\p{L}\p{N}]/gu, "");
}

/**
 * Rough English syllable count. Used to share time out between lines when we
 * have no transcript — a six-syllable line should hold the screen longer than
 * a two-syllable one, which is the main thing even distribution gets wrong.
 */
export function syllables(word) {
  const w = normalizeWord(word);
  if (!w) return 0;
  if (w.length <= 3) return 1;
  const groups = w
    .replace(/(?:[^laeiouy]es|ed|[^laeiouy]e)$/, "")
    .replace(/^y/, "")
    .match(/[aeiouy]{1,2}/g);
  return Math.max(1, groups ? groups.length : 1);
}

/** Levenshtein similarity in 0..1, so near-misses still align. */
export function similarity(a, b) {
  if (a === b) return 1;
  if (!a || !b) return 0;
  const m = a.length;
  const n = b.length;
  let prev = Array.from({ length: n + 1 }, (_, j) => j);
  const cur = new Array(n + 1);
  for (let i = 1; i <= m; i++) {
    cur[0] = i;
    for (let j = 1; j <= n; j++) {
      cur[j] = Math.min(
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)
      );
    }
    prev = cur.slice();
  }
  return 1 - prev[n] / Math.max(m, n);
}

const GAP = -0.55; // cost of skipping a word on either side
const MATCH_FLOOR = 0.6; // below this, two words aren't the same word

/**
 * Needleman-Wunsch global alignment over word sequences.
 * Returns, for each official word, the index of the transcript word it maps to
 * (or null when the transcriber missed it entirely).
 */
export function alignWords(officialWords, transcriptWords) {
  const m = officialWords.length;
  const n = transcriptWords.length;
  const mapping = new Array(m).fill(null);
  if (!m || !n) return mapping;

  const score = (i, j) => {
    const sim = similarity(officialWords[i], transcriptWords[j]);
    return sim >= MATCH_FLOOR ? sim : -1 + sim; // penalize non-matches
  };

  // DP table (m+1) x (n+1)
  const dp = Array.from({ length: m + 1 }, () => new Float64Array(n + 1));
  for (let i = 1; i <= m; i++) dp[i][0] = i * GAP;
  for (let j = 1; j <= n; j++) dp[0][j] = j * GAP;
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] = Math.max(
        dp[i - 1][j - 1] + score(i - 1, j - 1),
        dp[i - 1][j] + GAP,
        dp[i][j - 1] + GAP
      );
    }
  }

  // Traceback
  let i = m;
  let j = n;
  while (i > 0 && j > 0) {
    const diag = dp[i - 1][j - 1] + score(i - 1, j - 1);
    if (dp[i][j] === diag) {
      if (similarity(officialWords[i - 1], transcriptWords[j - 1]) >= MATCH_FLOOR) {
        mapping[i - 1] = j - 1;
      }
      i--;
      j--;
    } else if (dp[i][j] === dp[i - 1][j] + GAP) {
      i--;
    } else {
      j--;
    }
  }
  return mapping;
}

/** Split raw pasted lyrics into display lines, re-wrapping very long ones. */
export function splitLines(lyrics, maxChars = 90) {
  const wrap = (line) => {
    const out = [];
    let cur = "";
    for (const w of line.split(/\s+/)) {
      const next = cur ? `${cur} ${w}` : w;
      if (next.length > maxChars) {
        if (cur) out.push(cur);
        cur = w;
      } else cur = next;
    }
    if (cur) out.push(cur);
    return out;
  };
  return (lyrics ?? "")
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean)
    .flatMap(wrap);
}

/**
 * Share a window out between lines by syllable count. Used when there is no
 * transcript — still far better than giving every line an equal slice.
 */
export function estimateTimings(lines, windowStart, windowEnd) {
  const weights = lines.map((l) =>
    Math.max(1, l.split(/\s+/).reduce((sum, w) => sum + syllables(w), 0))
  );
  const total = weights.reduce((a, b) => a + b, 0);
  const span = Math.max(0, windowEnd - windowStart);
  let t = windowStart;
  return lines.map((text, i) => {
    const dur = (weights[i] / total) * span;
    const line = { text, start: t, end: t + dur };
    t += dur;
    return line;
  });
}

/**
 * Align official lyrics to a word-timed transcript.
 *
 * @param lyrics      raw pasted lyrics
 * @param words       [{ word, start, end }] from the transcriber
 * @param audioEnd    song duration, used to clamp the last line
 * @returns [{ text, start, end }] in seconds, monotonically increasing
 */
export function alignLyrics(lyrics, words, audioEnd = Infinity) {
  const lines = splitLines(lyrics);
  if (!lines.length) return [];

  const transcript = (words ?? [])
    .map((w) => ({ ...w, norm: normalizeWord(w.word ?? w.text ?? "") }))
    .filter((w) => w.norm && Number.isFinite(w.start));
  if (!transcript.length) {
    return estimateTimings(lines, 0, Math.min(audioEnd, 180)).map((l) => ({
      ...l,
      estimated: true,
    }));
  }

  // Flatten to words, remembering which line each came from
  const flat = [];
  lines.forEach((text, lineIndex) => {
    for (const raw of text.split(/\s+/)) {
      const norm = normalizeWord(raw);
      if (norm) flat.push({ norm, lineIndex });
    }
  });

  const mapping = alignWords(
    flat.map((f) => f.norm),
    transcript.map((t) => t.norm)
  );

  // Timestamp every official word: matched words take the transcript's time,
  // unmatched ones are interpolated between their nearest matched neighbours.
  const times = flat.map((_, k) =>
    mapping[k] === null
      ? null
      : { start: transcript[mapping[k]].start, end: transcript[mapping[k]].end ?? transcript[mapping[k]].start }
  );

  const firstKnown = times.findIndex(Boolean);
  if (firstKnown === -1) {
    return estimateTimings(lines, 0, Math.min(audioEnd, 180)).map((l) => ({
      ...l,
      estimated: true,
    }));
  }
  const lastKnown = times.length - 1 - [...times].reverse().findIndex(Boolean);

  for (let k = 0; k < times.length; k++) {
    if (times[k]) continue;
    let prev = k - 1;
    while (prev >= 0 && !times[prev]) prev--;
    let next = k + 1;
    while (next < times.length && !times[next]) next++;

    if (prev < 0) {
      // Leading unmatched words: back-fill from the first known time
      times[k] = { start: times[firstKnown].start, end: times[firstKnown].start };
    } else if (next >= times.length) {
      times[k] = { start: times[lastKnown].end, end: times[lastKnown].end };
    } else {
      const a = times[prev].end;
      const b = times[next].start;
      const step = (b - a) / (next - prev);
      const t = a + step * (k - prev);
      times[k] = { start: t, end: t + step };
    }
  }

  // Collapse words back into lines
  const out = lines.map((text) => ({ text, start: null, end: null }));
  flat.forEach((f, k) => {
    const line = out[f.lineIndex];
    if (line.start === null || times[k].start < line.start) line.start = times[k].start;
    if (line.end === null || times[k].end > line.end) line.end = times[k].end;
  });

  // Enforce sanity: monotonic, non-zero length, inside the song
  let prevEnd = 0;
  for (const line of out) {
    if (line.start === null) line.start = prevEnd;
    if (line.end === null || line.end <= line.start) line.end = line.start + 1.2;
    if (line.start < prevEnd) line.start = prevEnd;
    if (line.end <= line.start) line.end = line.start + 0.4;
    if (Number.isFinite(audioEnd)) {
      line.start = Math.min(line.start, audioEnd);
      line.end = Math.min(line.end, audioEnd);
    }
    prevEnd = line.end;
  }
  return out;
}

/** Keep only the lines that fall inside a clip window, rebased to it. */
export function timingsForWindow(timings, windowStart, windowDuration) {
  const windowEnd = windowStart + windowDuration;
  return timings
    .filter((l) => l.end > windowStart && l.start < windowEnd)
    .map((l) => ({
      text: l.text,
      start: Math.max(0, l.start - windowStart),
      end: Math.min(windowDuration, l.end - windowStart),
    }))
    .filter((l) => l.end > l.start);
}
