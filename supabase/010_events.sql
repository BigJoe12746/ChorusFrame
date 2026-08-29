-- Product analytics: one append-only table, first-party, no third-party scripts.
--
-- The scorecard in the business plan asks six questions — time to first
-- export, signup→export activation, week-4 retention, free→paid conversion,
-- export success rate, and where people fall out of the funnel. None of them
-- could be answered before this table existed.
--
-- Deliberately thin on personal data: an event has a name, an optional user,
-- an optional anonymous id (a random browser value, not a fingerprint), a
-- route PATTERN (never a resolved id), and a small JSON payload. No IP, no
-- user-agent, no third-party beacon — the privacy policy says behaviour data
-- stays ours, and a table we own is the only way that stays true.

create table if not exists public.events (
  id bigserial primary key,
  name text not null,
  -- Null for anonymous visitors; set once someone signs in.
  user_id uuid references auth.users(id) on delete set null,
  -- Random per-browser id so a signed-out visit can be joined to the signup
  -- it becomes. Never derived from IP, user-agent or anything identifying.
  anon_id text,
  path text,
  props jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists events_name_time_idx on public.events (name, created_at desc);
create index if not exists events_user_idx on public.events (user_id, created_at desc);
create index if not exists events_anon_idx on public.events (anon_id, created_at desc);

-- One upgrade per subscription, however many times Stripe redelivers the
-- webhook. Without this a retry inflates the conversion rate.
create unique index if not exists events_upgrade_once_idx
  on public.events ((props ->> 'subscriptionId'))
  where name = 'upgrade_completed' and props ? 'subscriptionId';

-- Nobody reads or writes this from the browser. Every insert goes through a
-- server route with the service-role key, and every read is an admin report.
alter table public.events enable row level security;
revoke all on table public.events from public, anon, authenticated;

comment on table public.events is
  'Append-only product analytics. Service-role only; no PII beyond an optional user id and a random anon id.';

/*
 * The funnel, computed in SQL rather than by pulling rows into the app.
 *
 * Two deliberate sourcing choices:
 *
 *   Render outcomes come from render_jobs, not from events. That table is
 *   the render lifecycle's own record — it cannot double-count a retry, it
 *   cannot mistake a reclaimed job for a failure, and it already holds every
 *   render ever run, including ones that predate this migration.
 *
 *   Rates are true cohort rates: the numerator is restricted to people who
 *   signed up inside the same window. Dividing this month's uploads by this
 *   month's signups would climb past 100% the moment returning artists
 *   outnumber new ones.
 *
 * Undefined rates return NULL, never 0 — "no finished renders yet" and "every
 * render failed" must not render as the same number.
 */
create or replace function public.funnel_metrics(p_days int default 30)
returns table (metric text, value numeric, detail text)
language sql
security definer
set search_path = public
as $$
  with span as (
    select now() - make_interval(days => least(3650, greatest(1, coalesce(p_days, 30)))) as since
  ),
  ev as (
    select e.* from public.events e, span where e.created_at >= span.since
  ),
  jobs as (
    select j.* from public.render_jobs j, span where j.created_at >= span.since
  ),
  -- Everyone who signed up inside the window: the cohort the rates measure.
  cohort as (
    select distinct user_id from ev where name = 'signup' and user_id is not null
  ),
  visitors as (
    select count(distinct coalesce(anon_id, user_id::text)) n
      from ev where name = 'page_view' and coalesce(anon_id, user_id::text) is not null
  ),
  signups as (select count(*) n from ev where name = 'signup'),
  uploads as (
    select count(distinct coalesce(user_id::text, anon_id)) n
      from ev
     where name = 'upload_complete'
       and coalesce(user_id::text, anon_id) is not null
  ),
  -- Cohort numerators
  cohort_uploaded as (
    select count(distinct e.user_id) n
      from ev e join cohort c on c.user_id = e.user_id
     where e.name = 'upload_complete'
  ),
  cohort_exported as (
    select count(distinct j.user_id) n
      from jobs j join cohort c on c.user_id = j.user_id
     where j.status = 'done'
  ),
  cohort_upgraded as (
    select count(distinct e.user_id) n
      from ev e join cohort c on c.user_id = e.user_id
     where e.name = 'upgrade_completed'
  ),
  -- Render truth, from the render lifecycle's own table
  renders as (select count(*) n from jobs),
  render_done as (select count(*) n from jobs where status = 'done'),
  render_failed as (select count(*) n from jobs where status = 'failed'),
  upgrades as (select count(*) n from ev where name = 'upgrade_completed'),
  cancels as (select count(*) n from ev where name = 'subscription_canceled'),
  /*
   * Time from an artist's FIRST EVER upload to their first finished render.
   * Both sides look at all of history, not just the window, or an artist
   * who uploaded last month and rendered today would measure as instant.
   * Only artists whose first upload falls inside the window are reported,
   * so the number tracks the experience new artists are having now.
   */
  first_clip as (
    select percentile_disc(0.5) within group (order by mins) med, count(*) n
      from (
        select u.user_id,
               extract(epoch from (min(j.finished_at) - u.first_upload)) / 60 as mins
          from (
            select user_id, min(created_at) first_upload
              from public.events
             where name = 'upload_complete' and user_id is not null
             group by user_id
          ) u
          join span on true
          join public.render_jobs j
            on j.user_id = u.user_id
           and j.status = 'done'
           and j.finished_at >= u.first_upload
         where u.first_upload >= span.since
         group by u.user_id, u.first_upload
      ) t
  ),
  /*
   * Week-4 retention: of the artists who first uploaded 28–56 days ago (old
   * enough to have had a fourth week), how many did anything in week four?
   */
  retention as (
    select
      count(*) filter (where returned) r,
      count(*) n
      from (
        select u.user_id,
               exists (
                 select 1 from public.events e2
                  where e2.user_id = u.user_id
                    and e2.name in ('upload_complete', 'render_started')
                    and e2.created_at between u.first_upload + interval '21 days'
                                          and u.first_upload + interval '28 days'
               ) returned
          from (
            select user_id, min(created_at) first_upload
              from public.events
             where name = 'upload_complete' and user_id is not null
             group by user_id
          ) u
         where u.first_upload <= now() - interval '28 days'
           and u.first_upload >= now() - interval '56 days'
      ) t
  )
  select 'visitors', visitors.n, 'distinct browsers that viewed a page' from visitors
  union all select 'signups', signups.n, 'accounts created' from signups
  union all select 'uploads', uploads.n, 'artists who completed an upload' from uploads
  union all select 'renders_started', renders.n, 'render jobs enqueued' from renders
  union all select 'renders_done', render_done.n, 'renders that produced clips' from render_done
  union all select 'renders_failed', render_failed.n, 'renders that failed (never charged)' from render_failed
  union all select 'upgrades', upgrades.n, 'checkouts completed' from upgrades
  union all select 'cancellations', cancels.n, 'subscriptions cancelled' from cancels
  union all
    select 'activation_rate',
           case when signups.n = 0 then null
                else round(100.0 * cohort_exported.n / signups.n, 1) end,
           'percent of new signups that finished an export'
      from signups, cohort_exported
  union all
    select 'upload_rate',
           case when signups.n = 0 then null
                else round(100.0 * cohort_uploaded.n / signups.n, 1) end,
           'percent of new signups that uploaded a song'
      from signups, cohort_uploaded
  union all
    select 'export_success_rate',
           case when (render_done.n + render_failed.n) = 0 then null
                else round(100.0 * render_done.n / (render_done.n + render_failed.n), 1) end,
           'percent of finished renders that succeeded'
      from render_done, render_failed
  union all
    select 'conversion_rate',
           case when signups.n = 0 then null
                else round(100.0 * cohort_upgraded.n / signups.n, 1) end,
           'percent of new signups that upgraded'
      from signups, cohort_upgraded
  union all
    select 'week4_retention',
           case when retention.n = 0 then null
                else round(100.0 * retention.r / retention.n, 1) end,
           coalesce(retention.n, 0) || ' artists old enough to measure'
      from retention
  union all
    select 'median_minutes_to_first_clip',
           round(first_clip.med, 1),
           coalesce(first_clip.n, 0) || ' artists measured'
      from first_clip;
$$;

revoke all on function public.funnel_metrics(int) from public, anon, authenticated;

/*
 * Retention: usage events are kept for 13 months, which is long enough to
 * compare a release to the same month last year and no longer. The privacy
 * policy states this; run it from a scheduled job or by hand.
 */
create or replace function public.prune_events()
returns bigint
language sql
security definer
set search_path = public
as $$
  with gone as (
    delete from public.events
     where created_at < now() - interval '13 months'
     returning 1
  )
  select count(*) from gone;
$$;

revoke all on function public.prune_events() from public, anon, authenticated;
