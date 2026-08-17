-- ChorusFrame — beat grid
-- Run in the Supabase SQL Editor AFTER 007_brand_kit.sql. Safe to re-run.
--
-- Detected in the browser, which already decodes the audio to draw the
-- waveform, and stored so the worker never needs an MP3 decoder. Same division
-- of labour as lyric timing.

alter table public.submissions
  add column if not exists bpm numeric,
  -- Seconds from the start of the song to the first beat. Tempo alone is not
  -- enough to animate to: without the phase, motion lands between beats.
  add column if not exists beat_offset numeric;

comment on column public.submissions.beat_offset is
  'Seconds to the first beat. With bpm this gives the grid every Nth beat sits on.';
