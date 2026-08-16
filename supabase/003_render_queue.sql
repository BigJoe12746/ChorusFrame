-- ChorusFrame — self-serve render queue
-- Run in the Supabase SQL Editor AFTER 002_auth.sql. Safe to re-run.
--
-- Division of responsibility:
--   render_jobs.status   owns the RENDER lifecycle (queued/rendering/done/failed)
--   submissions.status   owns the DELIVERY lifecycle (queued/in_progress/clip_ready/delivered)
-- The worker never writes render state into submissions; mirroring the two
-- produced states that could disagree.

create table if not exists public.render_jobs (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.submissions(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  formats text[] not null default array['vertical'],
  clip_start_seconds numeric not null default 0,
  duration_seconds numeric not null default 15,
  -- queued | rendering | done | failed
  status text not null default 'queued',
  attempts int not null default 0,
  max_attempts int not null default 3,
  error text,
  clip_urls jsonb,
  worker_id text,
  heartbeat_at timestamptz,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);

create index if not exists render_jobs_queue_idx
  on public.render_jobs (status, created_at)
  where status = 'queued';
create index if not exists render_jobs_user_idx on public.render_jobs (user_id);
create index if not exists render_jobs_submission_idx on public.render_jobs (submission_id);

-- At most one live job per song, enforced by the database rather than by a
-- read-then-insert in the API (two tabs could both pass that check).
create unique index if not exists render_jobs_one_active_idx
  on public.render_jobs (submission_id)
  where status in ('queued', 'rendering');

alter table public.render_jobs enable row level security;

-- Artists read their own jobs; all writes go through the service-role key.
drop policy if exists "own render jobs read" on public.render_jobs;
create policy "own render jobs read" on public.render_jobs
  for select using (auth.uid() = user_id);

/*
 * Enqueue a render, checking ownership and quota in the SAME transaction as
 * the insert. Doing the count in the API and inserting afterwards let several
 * concurrent requests all read "4 used" and all insert.
 *
 * Returns one row: (job_id, outcome) where outcome is
 *   'created' | 'already_queued' | 'not_found' | 'quota' | 'abuse'
 */
create or replace function public.enqueue_render_job(
  p_user uuid,
  p_submission uuid,
  p_formats text[],
  p_start numeric,
  p_duration numeric,
  p_daily_limit int default 5,
  p_abuse_limit int default 25
)
returns table (job_id uuid, outcome text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_existing uuid;
  v_billable int;
  v_total int;
  v_new uuid;
begin
  select user_id into v_owner from public.submissions where id = p_submission;
  if v_owner is null or v_owner is distinct from p_user then
    return query select null::uuid, 'not_found'::text;
    return;
  end if;

  select id into v_existing
    from public.render_jobs
   where submission_id = p_submission
     and status in ('queued', 'rendering')
   limit 1;
  if v_existing is not null then
    return query select v_existing, 'already_queued'::text;
    return;
  end if;

  -- Failed jobs are excluded on purpose: the marketing page promises that a
  -- render which produced nothing never costs the artist anything.
  select count(*) into v_billable
    from public.render_jobs
   where user_id = p_user
     and status <> 'failed'
     and created_at >= now() - interval '24 hours';
  if v_billable >= p_daily_limit then
    return query select null::uuid, 'quota'::text;
    return;
  end if;

  -- Independent ceiling counting EVERY job including failures, so a caller
  -- who deliberately fails renders cannot burn compute forever. Set well
  -- above the credit limit, so honest use never reaches it.
  select count(*) into v_total
    from public.render_jobs
   where user_id = p_user
     and created_at >= now() - interval '24 hours';
  if v_total >= p_abuse_limit then
    return query select null::uuid, 'abuse'::text;
    return;
  end if;

  insert into public.render_jobs (submission_id, user_id, formats, clip_start_seconds, duration_seconds)
  values (p_submission, p_user, p_formats, p_start, p_duration)
  returning id into v_new;

  return query select v_new, 'created'::text;
exception
  -- Lost the race on the one-active-job index: return the winner instead.
  when unique_violation then
    select id into v_existing
      from public.render_jobs
     where submission_id = p_submission
       and status in ('queued', 'rendering')
     limit 1;
    return query select v_existing, 'already_queued'::text;
end;
$$;

/*
 * Atomically hand exactly one queued job to a worker.
 *
 * FOR UPDATE SKIP LOCKED is what makes this safe with several workers: each
 * transaction locks a different row instead of all of them fighting over the
 * oldest job. Also requeues jobs whose worker stopped heartbeating.
 */
create or replace function public.claim_render_job(
  p_worker text,
  p_stale_seconds int default 900
)
returns setof public.render_jobs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  -- Reclaim abandoned work. attempts was already incremented when the dead
  -- worker claimed it, so a job that keeps killing workers eventually
  -- exhausts max_attempts instead of looping forever.
  update public.render_jobs
     set status = 'queued',
         worker_id = null,
         error = coalesce(error, 'worker stopped responding; requeued')
   where status = 'rendering'
     and heartbeat_at is not null
     and heartbeat_at < now() - make_interval(secs => p_stale_seconds);

  -- Give up on jobs that burned through their retries.
  update public.render_jobs
     set status = 'failed',
         finished_at = now(),
         error = coalesce(error, 'exceeded retry limit')
   where status = 'queued'
     and attempts >= max_attempts;

  select id into v_id
    from public.render_jobs
   where status = 'queued'
     and attempts < max_attempts
   order by created_at
   for update skip locked
   limit 1;

  if v_id is null then
    return;
  end if;

  return query
  update public.render_jobs
     set status = 'rendering',
         worker_id = p_worker,
         attempts = attempts + 1,
         started_at = coalesce(started_at, now()),
         heartbeat_at = now(),
         error = null
   where id = v_id
  returning *;
end;
$$;

-- Only the service role (API routes and workers) may call these.
revoke all on function public.claim_render_job(text, int) from public, anon, authenticated;
revoke all on function public.enqueue_render_job(uuid, uuid, text[], numeric, numeric, int, int)
  from public, anon, authenticated;
