-- Pin the exact privilege matrix, instead of relying on what is absent.
--
-- WHY THIS EXISTS. The first two migrations granted privileges additively and
-- assumed that anything not granted was therefore unreachable. That assumption
-- held locally and NOT in the cloud:
--
--   local  (supabase CLI stack):  has_table_privilege('anon','user_roles','select') = false
--   cloud  (provisioned project): the same check is TRUE -- a fresh cloud project
--                                 carries ALTER DEFAULT PRIVILEGES for schema
--                                 public, so every new table there is granted to
--                                 anon/authenticated automatically.
--
-- Observable symptom: GET /rest/v1/user_roles as anon returned "HTTP 200 []" on
-- the cloud project rather than a permission error. Nothing leaked -- RLS is
-- enabled on user_roles with ZERO policies, and that denies every row on its own
-- -- but the table was one layer less protected than intended, and "200 []" is
-- indistinguishable from "empty table", which makes the deployment unverifiable.
--
-- So: revoke everything, then grant back precisely. After this migration, an
-- anon read of user_roles returns a permission error, which is a decisive signal
-- rather than an ambiguous empty array.

-- ---------------------------------------------------------------------------
-- user_roles: no client access at all, in either environment.
-- ---------------------------------------------------------------------------
-- Admin status is reachable ONLY through public.is_admin(), which is
-- security definer and therefore reads this table as its owner regardless of
-- the caller having no privileges on it.
revoke all on public.user_roles from anon, authenticated;

-- ---------------------------------------------------------------------------
-- songs: read for everyone, write only for signed-in users.
-- ---------------------------------------------------------------------------
-- Row-level rules still apply on top of these; this is only the coarse
-- SQL-privilege layer. Revoking first means a stray default privilege (for
-- example anon INSERT) cannot survive.
revoke all on public.songs from anon, authenticated;
grant select                 on public.songs to anon, authenticated;
grant insert, update, delete on public.songs to authenticated;

-- ---------------------------------------------------------------------------
-- profiles: world-readable display names, self-service writes.
-- ---------------------------------------------------------------------------
revoke all on public.profiles from anon, authenticated;
grant select         on public.profiles to anon, authenticated;
grant insert, update on public.profiles to authenticated;

-- Deliberately NOT granted anywhere above: DELETE on profiles (deleting a
-- profile is an account operation, and the row is removed by the auth.users
-- cascade), and any privilege whatsoever on user_roles.

-- ---------------------------------------------------------------------------
-- Stop the same drift happening to the NEXT table someone adds.
-- ---------------------------------------------------------------------------
-- Without this, a future `create table public.whatever (...)` inherits the
-- cloud's permissive default privileges and is readable by anon the moment it
-- exists -- before anyone remembers to write a policy for it. Changing the
-- default to no-grant means a new table is unreachable until its access is
-- declared on purpose.
alter default privileges in schema public revoke all on tables from anon, authenticated;
