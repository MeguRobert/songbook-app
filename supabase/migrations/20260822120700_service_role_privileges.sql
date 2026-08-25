-- Grant the admin-users Edge Function exactly what it needs, and nothing else.
--
-- WHY THIS EXISTS. `service_role` had NO privilege on ANY table in `public` --
-- verified locally, all six tables, select/insert/update all false. The function
-- therefore answered 403 to a genuine administrator, because its own
-- `is_administrator()` call succeeded and every subsequent read failed.
--
-- The trap is that `bypassrls` is not "bypass grants". service_role skips
-- row-level security and still needs a table-level GRANT like any other role.
-- Nothing in this project used service_role before now, so the gap was invisible.
--
-- AND IT WOULD PROBABLY HAVE WORKED IN THE CLOUD. A provisioned Supabase project
-- carries permissive ALTER DEFAULT PRIVILEGES, which is precisely the local/cloud
-- drift that 20260728120200 was written to eliminate -- see its comment on anon
-- reading user_roles as "HTTP 200 []" in the cloud and a permission error
-- locally. Relying on that here would mean the function works in production,
-- fails on every developer's machine, and nobody can tell whether a 403 is a bug
-- or an environment. So: granted explicitly, in the same style as that file.
--
-- Scope discipline. Only what index.ts actually does:
--   user_roles   select, insert, update   read a role; upsert on set_role/invite
--   admin_audit  select, insert           write entries; read them back
--   profiles     select                   display names for the user list
--   songs        select                   the approved/pending/rejected tally
--   roles        select                   validate a role name
-- Deliberately absent: DELETE anywhere (a role row goes with its account via the
-- auth.users cascade), and any privilege at all on app_settings -- the settings
-- screen writes that as the signed-in administrator, through RLS, which is the
-- weaker credential and therefore the right one.

revoke all on public.user_roles  from service_role;
revoke all on public.admin_audit from service_role;
revoke all on public.profiles    from service_role;
revoke all on public.songs       from service_role;
revoke all on public.roles       from service_role;

grant select, insert, update on public.user_roles  to service_role;
grant select, insert         on public.admin_audit to service_role;
grant select                 on public.profiles    to service_role;
grant select                 on public.songs       to service_role;
grant select                 on public.roles       to service_role;

-- admin_audit's id is `generated always as identity`, which is backed by a
-- sequence. INSERT on the table is not enough on its own for some client paths,
-- and granting usage is cheaper than debugging it later.
grant usage, select on all sequences in schema public to service_role;

-- The function calls these as the CALLER, not as service_role, so they are
-- already granted to authenticated. Granted here too so that a future
-- service-role maintenance job can ask the same questions.
grant execute on function public.is_administrator() to service_role;
grant execute on function public.can_moderate()     to service_role;
grant execute on function public.role_rank(uuid)    to service_role;
