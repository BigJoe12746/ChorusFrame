-- ChorusFrame — apply the outstanding migrations in one go.
-- Paste this whole file into the Supabase SQL Editor and press Run.
--
-- Contains 006 (billing), 007 (brand kit) and 008 (beat grid).
-- Every statement is idempotent, so running it twice is harmless, and
-- nothing here touches existing rows or data.


-- ============================================================
-- 006_billing.sql
-- ============================================================
-- ChorusFrame — billing foundations
-- Run in the Supabase SQL Editor AFTER 005_vibe.sql. Safe to re-run.
--
-- Plan LIMITS live in lib/plans.ts, not here: one source of truth, read by the
-- pricing page, the API that enforces them and the dashboard that reports
-- them. This migration stores only which plan an artist is on and what they
-- have used.

alter table public.profiles
  add column if not exists plan text not null default 'free',
  -- active | trialing | past_due | canceled
  add column if not exists plan_status text not null default 'active',
  add column if not exists plan_period_end timestamptz,
  add column if not exists stripe_customer_id text,
  add column if not exists stripe_subscription_id text,
  -- Founding-year customers keep their price at renewal; the plan promises the
  -- first 1,000 paying customers that rate.
  add column if not exists founding_member boolean not null default false,
  add column if not exists ai_credits int not null default 0;

create unique index if not exists profiles_stripe_customer_idx
  on public.profiles (stripe_customer_id)
  where stripe_customer_id is not null;

comment on column public.profiles.plan is
  'Plan id matching lib/plans.ts: free | pro';

/*
 * Exports an artist has STARTED this calendar month.
 *
 * Failed jobs are excluded, because "failed renders never consume credits" is
 * a promise on the marketing page — a render that produced nothing must not
 * cost an artist an export. Counting in SQL keeps that rule in one place
 * rather than trusting each caller to remember the filter.
 */
create or replace function public.exports_used_this_month(p_user uuid)
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int
    from public.render_jobs
   where user_id = p_user
     and status <> 'failed'
     and created_at >= date_trunc('month', now());
$$;

revoke all on function public.exports_used_this_month(uuid) from public, anon;
grant execute on function public.exports_used_this_month(uuid) to authenticated;

/*
 * How many founding-year seats are left. Used to decide whether to still show
 * the founding price, and to stop selling it past 1,000.
 */
create or replace function public.founding_seats_taken()
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int from public.profiles where founding_member;
$$;

revoke all on function public.founding_seats_taken() from public, anon;
grant execute on function public.founding_seats_taken() to authenticated;

-- Artists may read their own billing state; only the service role writes it.
drop policy if exists "own profile read" on public.profiles;
create policy "own profile read" on public.profiles
  for select using (auth.uid() = id);

-- ============================================================
-- 007_brand_kit.sql
-- ============================================================
-- ChorusFrame — artist brand kit
-- Run in the Supabase SQL Editor AFTER 006_billing.sql. Safe to re-run.
--
-- "Artist identity memory: saved fonts, colours, cover treatments and approved
-- visual language" is listed in the business plan as defensible
-- differentiation. This is the first piece of it: a kit belongs to the artist,
-- not to a song, so their fifth release looks like their first.

alter table public.profiles
  -- Hex colours, validated in the API before they reach a style attribute
  add column if not exists brand_primary text,
  add column if not exists brand_secondary text,
  -- sans | serif | mono — families that exist in the worker image, so a kit
  -- never silently falls back to a different face on the render host
  add column if not exists brand_font text,
  add column if not exists default_vibe text;

comment on column public.profiles.brand_primary is
  'Accent colour (#rrggbb). Overrides both the vibe palette and cover-art extraction.';

-- ============================================================
-- 008_beat_grid.sql
-- ============================================================
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
