-- ChorusFrame — artist accounts
-- Run in the Supabase SQL Editor AFTER schema.sql.
-- Safe to re-run.

-- 1. Link uploads to accounts.
--    Nullable on purpose: anonymous "free sample clip" uploads still work,
--    and those rows stay service-role-only (auth.uid() = null is never true).
alter table public.submissions
  add column if not exists user_id uuid references auth.users(id) on delete set null;

create index if not exists submissions_user_id_idx on public.submissions(user_id);

-- 2. One profile row per signed-in artist. Brand kits will hang off this later.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  artist_name text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- 3. Create the profile automatically on signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, artist_name)
  values (new.id, new.raw_user_meta_data ->> 'artist_name')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. Row-level security: an artist sees only their own rows.
--    All writes go through the service-role key in the API routes, so read
--    policies are all that's needed here.
drop policy if exists "own profile read" on public.profiles;
create policy "own profile read" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "own profile update" on public.profiles;
create policy "own profile update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "own submissions read" on public.submissions;
create policy "own submissions read" on public.submissions
  for select using (auth.uid() = user_id);

-- Backfill: attach past anonymous uploads to an account that shares the email.
-- Run manually if you want early testers to see their concierge submissions:
--
--   update public.submissions s
--      set user_id = u.id
--     from auth.users u
--    where s.user_id is null and lower(s.email) = lower(u.email);
