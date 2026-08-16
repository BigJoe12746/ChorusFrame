-- ChorusFrame — self-serve render queue
-- Run in the Supabase SQL Editor AFTER 002_auth.sql. Safe to re-run.

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

alter table public.render_jobs enable row level security;

-- Artists read their own jobs; all writes go through the service-role key.
drop policy if exists "own render jobs read" on public.render_jobs;
create policy "own render jobs read" on public.render_jobs
  for select using (auth.uid() = user_id);

/*
 * Atomically hand exactly one queued job to a worker.
 *
 * FOR UPDATE SKIP LOCKED is what makes this safe to run from several workers
 * at once: each transaction locks a different row instead of all of them
 * fighting over the oldest job.
 *
 * Also requeues jobs whose worker died mid-render — a job is considered
 * abandoned when its heartbeat goes stale.
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
  -- Reclaim abandoned work first. attempts was already incremented when the
  -- dead worker claimed it, so a job that keeps killing workers eventually
  -- exhausts max_attempts instead of looping forever.
  update public.render_jobs
     set status = 'queued',
         worker_id = null,
         error = coalesce(error, 'worker stopped responding; requeued')
   where status = 'rendering'
     and heartbeat_at is not null
     and heartbeat_at < now() - make_interval(secs => p_stale_seconds);

  -- Give up on jobs that burned through their retries while being reclaimed
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

-- Only the service role (workers) may claim jobs.
revoke all on function public.claim_render_job(text, int) from public, anon, authenticated;
