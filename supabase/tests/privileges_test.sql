-- The privilege matrix, pinned so it cannot drift back.
--
-- 20260728120200 exists because privileges granted additively were assumed to be
-- absent elsewhere and were not -- the cloud's default privileges made anon a
-- reader of user_roles. These assertions state the intended matrix outright, for
-- every client role, so either environment disagreeing with it fails a test
-- rather than being discovered in production.

begin;
select plan(16);

-- ---------------------------------------------------------------------------
-- anon and authenticated: no access to the roles or audit tables
-- ---------------------------------------------------------------------------
select ok(not has_table_privilege('anon', 'public.user_roles', 'select'),
  'anon cannot read user_roles');
select ok(not has_table_privilege('authenticated', 'public.user_roles', 'select'),
  'authenticated cannot read user_roles either -- is_admin() is the only route');
select ok(not has_table_privilege('anon', 'public.admin_audit', 'select'),
  'anon cannot read the audit log');
select ok(not has_table_privilege('authenticated', 'public.admin_audit', 'insert'),
  'no client may write the audit log');

-- ---------------------------------------------------------------------------
-- The public surface
-- ---------------------------------------------------------------------------
select ok(has_table_privilege('anon', 'public.app_settings', 'select'),
  'anon may read app_settings -- the guidelines must be readable before sign-in');
select ok(not has_table_privilege('anon', 'public.app_settings', 'update'),
  'anon may not write app_settings');
select ok(has_table_privilege('authenticated', 'public.app_settings', 'update'),
  'authenticated may attempt an update; the policy decides whether it lands');
select ok(has_table_privilege('anon', 'public.roles', 'select'),
  'the role ladder is public knowledge');
select ok(not has_table_privilege('anon', 'public.roles', 'insert'),
  'but the ladder is not client-editable');

-- ---------------------------------------------------------------------------
-- service_role: exactly what the admin-users Edge Function needs
-- ---------------------------------------------------------------------------
-- bypassrls is not "bypass grants". Without these the function answers 403 to a
-- genuine administrator, because is_administrator() succeeds and every read
-- after it fails.
select ok(has_table_privilege('service_role', 'public.user_roles', 'update'),
  'service_role may change a role');
select ok(has_table_privilege('service_role', 'public.admin_audit', 'insert'),
  'service_role may write the audit log');
select ok(has_table_privilege('service_role', 'public.profiles', 'select'),
  'service_role may read display names for the user list');
select ok(has_table_privilege('service_role', 'public.songs', 'select'),
  'service_role may read songs for the per-user tally');

select ok(not has_table_privilege('service_role', 'public.songs', 'delete'),
  'service_role may NOT delete songs -- nothing in the function does that');
select ok(not has_table_privilege('service_role', 'public.app_settings', 'update'),
  'service_role may NOT write settings -- that goes through RLS as the administrator');
select ok(not has_table_privilege('service_role', 'public.user_roles', 'delete'),
  'service_role may NOT delete role rows -- the auth.users cascade does that');

select * from finish();
rollback;
