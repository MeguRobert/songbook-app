-- Roles become a ranked lookup table, and Moderator stops meaning Administrator.
--
-- WHY THIS EXISTS. `user_roles.role` was `check (role in ('admin','moderator'))`
-- and `is_admin()` returned true for both, so the two roles had identical powers
-- everywhere they were used -- a moderator could do anything an administrator
-- could. Splitting them needs a comparison, and a comparison needs an order.
--
-- WHY A TABLE AND NOT AN ENUM. A tier has to be addable later without touching a
-- single policy. With ranks, `role_rank(uid) >= 50` keeps meaning "may moderate"
-- no matter how many tiers exist below it, so a future ('contributor', 30) is one
-- INSERT. A `check` constraint or a Postgres enum would each require a migration
-- plus a re-read of every policy that named a role, which is exactly the audit
-- this design is trying not to owe.

create table public.roles (
  name text primary key,
  rank smallint not null unique check (rank > 0)
);

-- Gaps between ranks are intentional: a tier can be inserted between two
-- existing ones without renumbering anything.
insert into public.roles (name, rank) values
  ('member', 10),
  ('moderator', 50),
  ('administrator', 90);

-- The ladder is public knowledge -- it is in this file, in a public repo. WHO
-- holds which role is not, and that stays in user_roles, which is granted
-- nothing to anyone. Reading this table lets the admin UI populate a role picker
-- without hardcoding the list in Dart.
alter table public.roles enable row level security;

create policy roles_read_all on public.roles
  for select using (true);

revoke all on public.roles from anon, authenticated;
grant select on public.roles to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Migrate user_roles onto the table
-- ---------------------------------------------------------------------------
-- The check constraint is dropped by discovered name rather than by the assumed
-- default, so this does not break if it was ever named by hand.
do $$
declare
  target_constraint text;
begin
  select conname into target_constraint
  from pg_constraint
  where conrelid = 'public.user_roles'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%role%';

  if target_constraint is not null then
    execute format('alter table public.user_roles drop constraint %I', target_constraint);
  end if;
end $$;

update public.user_roles set role = 'administrator' where role = 'admin';

alter table public.user_roles
  add constraint user_roles_role_fkey
  foreign key (role) references public.roles (name);

-- ---------------------------------------------------------------------------
-- The predicates
-- ---------------------------------------------------------------------------
-- All `security definer`, because user_roles grants nothing to any client role
-- and these have to read it as the function owner. All `stable`, so Postgres may
-- call them once per statement rather than once per row inside a policy.

create or replace function public.role_rank(uid uuid)
returns smallint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select r.rank
       from public.user_roles ur
       join public.roles r on r.name = ur.role
      where ur.user_id = uid),
    0)::smallint;
$$;

create or replace function public.can_moderate()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.role_rank(auth.uid())
       >= (select rank from public.roles where name = 'moderator');
$$;

create or replace function public.is_administrator()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.role_rank(auth.uid())
       >= (select rank from public.roles where name = 'administrator');
$$;

-- is_admin() becomes an alias, and that is the point.
--
-- Six policies and two triggers call it: songs_select, songs_update_admin,
-- songs_delete_admin, the hymnal policies in ..120300,
-- enforce_song_status_transition and enforce_song_source_immutable. Rewriting
-- all of them to name can_moderate() would reopen the RLS surface that ..120200
-- and ..190000 were written to close, for no behavioural gain -- "may moderate"
-- is exactly what every one of those call sites already meant. The regression
-- test for this decision is that supabase/tests/songs_rls_test.sql needs no edit.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.can_moderate();
$$;

grant execute on function public.role_rank(uuid)    to anon, authenticated;
grant execute on function public.can_moderate()     to anon, authenticated;
grant execute on function public.is_administrator() to anon, authenticated;
