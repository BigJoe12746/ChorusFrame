-- VerseFrame stage-gate MVP schema
-- Run this in the Supabase SQL Editor (Dashboard → SQL Editor → New query)

create table if not exists public.waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  artist_name text,
  genre text,
  created_at timestamptz not null default now()
);

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

-- Lock both tables down: only the service-role key (used by the API routes)
-- can read/write. No anon access needed for the stage-gate app.
alter table public.waitlist enable row level security;
alter table public.submissions enable row level security;

-- Private storage bucket for uploaded songs/artwork
insert into storage.buckets (id, name, public)
values ('submissions', 'submissions', false)
on conflict (id) do nothing;
