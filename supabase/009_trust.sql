-- Trust and rights: an auditable upload affirmation, and a takedown switch.
--
-- rights_confirmed_at: when the uploader affirmed they hold the rights. The
-- API refuses submissions without the affirmation; this records it, which is
-- what makes the copyright policy's "everyone who uploads confirms they hold
-- the rights" statement auditable rather than aspirational.
--
-- removed_at / removed_reason: the takedown switch. A set removed_at hides
-- the public share page. The clip files themselves stay in the public bucket
-- until scripts/takedown.mjs removes them — run it for a real takedown, since
-- anyone who already had the direct file URL can otherwise keep fetching it.

alter table public.submissions
  add column if not exists rights_confirmed_at timestamptz,
  add column if not exists removed_at timestamptz,
  add column if not exists removed_reason text;

-- Lock profiles down to reads. 002_auth.sql created an "own profile update"
-- policy, but every legitimate write goes through service-role API routes —
-- and with that policy plus Supabase's default column grants, any signed-in
-- user could set their own plan to 'pro' from the browser console. Row-level
-- security is row-level; the only safe shape here is no client updates at all.
drop policy if exists "own profile update" on public.profiles;
revoke update on table public.profiles from authenticated, anon;

comment on column public.submissions.rights_confirmed_at is
  'When the uploader affirmed rights ownership. Enforced by the API since Aug 2026; null on older rows.';
comment on column public.submissions.removed_at is
  'Takedown switch: set = the public share page for this song is disabled.';
