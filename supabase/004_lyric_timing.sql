-- ChorusFrame — lyric timing
-- Run in the Supabase SQL Editor AFTER 003_render_queue.sql. Safe to re-run.
--
-- Timing is computed once per song and cached here, because transcription
-- costs money and time. Re-rendering a different clip window reuses it.

alter table public.submissions
  add column if not exists lyrics_timing jsonb,
  -- whisper | deepgram | estimated  (estimated = syllable-weighted, no model)
  add column if not exists timing_source text,
  add column if not exists timing_updated_at timestamptz;

comment on column public.submissions.lyrics_timing is
  'Aligned lyric lines: [{text, start, end}] in seconds from the start of the song.';
