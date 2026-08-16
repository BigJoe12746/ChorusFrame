// Produce (and cache) lyric timing for a submission.
//
// Transcription costs money and minutes, so timing is computed once per song
// and stored on the row. Re-rendering a different clip window — or another
// format — reuses it.

import { alignLyrics } from "./align.mjs";
import { getTranscriber } from "./transcribe.mjs";

/**
 * Ensure the submission has lyric timing, computing it if absent.
 *
 * @returns {Promise<{timings: Array<{text,start,end}>, source: string}>}
 */
export async function ensureLyricTiming({
  supabase,
  sub,
  audioUrl,
  env,
  audioDuration = Infinity,
  force = false,
  log = console.log,
}) {
  if (!sub.lyrics?.trim()) return { timings: [], source: "none" };

  // Reuse cached timing unless the lyrics changed under it
  if (!force && Array.isArray(sub.lyrics_timing) && sub.lyrics_timing.length) {
    return { timings: sub.lyrics_timing, source: sub.timing_source ?? "cached" };
  }

  const transcriber = getTranscriber(env);
  let words = [];
  let source = "estimated";

  if (transcriber) {
    try {
      log(`transcribing with ${transcriber.name}…`);
      const result = await transcriber.transcribe(audioUrl);
      words = result.words ?? [];
      if (words.length) {
        source = transcriber.name;
        log(`heard ${words.length} words`);
      } else {
        log("transcriber returned no words — falling back to estimated timing");
      }
    } catch (e) {
      // Never fail a render because transcription failed: an estimated clip
      // is far better than no clip.
      log(`transcription failed (${e.message}) — falling back to estimated timing`);
    }
  } else {
    log("no transcription provider configured — using estimated timing");
  }

  const timings = alignLyrics(sub.lyrics, words, audioDuration);

  // Words coming back is not the same as those words being usable. Whisper
  // emits "♪" over sung passages, and a transcript can also fail to match a
  // single official word — in both cases alignLyrics falls back internally and
  // flags its output. Trusting words.length here would cache a fabricated
  // spread as real "whisper" timing and poison the row permanently.
  if (timings.some((l) => l.estimated)) source = "estimated";

  // Only cache REAL timing. An estimate is derived from the clip window rather
  // than the song, so persisting it would be meaningless — and leaving the
  // column empty means every song upgrades itself the moment a transcription
  // key is configured, with no backfill needed.
  if (source !== "estimated") {
    const { error } = await supabase
      .from("submissions")
      .update({
        lyrics_timing: timings,
        timing_source: source,
        timing_updated_at: new Date().toISOString(),
      })
      .eq("id", sub.id);
    if (error) log(`could not cache timing: ${error.message}`);
  }

  return { timings, source };
}
