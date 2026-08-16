-- ChorusFrame — visual direction per song
-- Run in the Supabase SQL Editor AFTER 004_lyric_timing.sql. Safe to re-run.

alter table public.submissions
  add column if not exists vibe text;

alter table public.render_jobs
  add column if not exists vibe text;

comment on column public.submissions.vibe is
  'Visual direction id (see remotion/vibes.ts): hyperpop | anime | dreamy | cinematic | reggae | minimal';

-- Carry the chosen vibe through the queue so a job renders what the artist
-- picked at the time, even if they change it before the worker gets to it.
create or replace function public.enqueue_render_job(
  p_user uuid,
  p_submission uuid,
  p_formats text[],
  p_start numeric,
  p_duration numeric,
  p_daily_limit int default 5,
  p_abuse_limit int default 25,
  p_vibe text default null
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

  select count(*) into v_total
    from public.render_jobs
   where user_id = p_user
     and created_at >= now() - interval '24 hours';
  if v_total >= p_abuse_limit then
    return query select null::uuid, 'abuse'::text;
    return;
  end if;

  -- Remember the choice on the song so the dashboard shows it next time
  if p_vibe is not null then
    update public.submissions set vibe = p_vibe where id = p_submission;
  end if;

  insert into public.render_jobs
    (submission_id, user_id, formats, clip_start_seconds, duration_seconds, vibe)
  values (p_submission, p_user, p_formats, p_start, p_duration, p_vibe)
  returning id into v_new;

  return query select v_new, 'created'::text;
exception
  when unique_violation then
    select id into v_existing
      from public.render_jobs
     where submission_id = p_submission
       and status in ('queued', 'rendering')
     limit 1;
    return query select v_existing, 'already_queued'::text;
end;
$$;

revoke all on function public.enqueue_render_job(uuid, uuid, text[], numeric, numeric, int, int, text)
  from public, anon, authenticated;

-- The 7-argument version is superseded; drop it so callers can't hit the old
-- signature and silently lose the vibe.
drop function if exists public.enqueue_render_job(uuid, uuid, text[], numeric, numeric, int, int);
