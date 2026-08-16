-- ChorusFrame stage-gate MVP schema
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query)

-- There was a `waitlist` table here. It was removed once the product could
-- actually serve people: artists sign up and render for themselves, so there
-- is nothing to wait for. Existing projects may still have the table; it is
-- unused and safe to drop.

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  artist_name text,
  song_title text not null,
  lyrics text,
  song_path text not null,
  artwork_path text,
  status text not null default 'queued', -- queued | in_progress | clip_ready | delivered
  sample_clip_url text,
  created_at timestamptz not null default now()
);

-- Locked down: only the service-role key (used by the API routes) can write.
-- Read policies for signed-in artists are added in 002_auth.sql.
alter table public.submissions enable row level security;

-- Private storage bucket for uploaded songs/artwork
insert into storage.buckets (id, name, public)
values ('submissions', 'submissions', false)
on conflict (id) do nothing;
