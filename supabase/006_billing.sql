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
  'Plan id matching lib/plans.ts: free | creator | creator_ai | teams';

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
