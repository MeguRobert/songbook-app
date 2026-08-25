-- Every account gets a profile and a member role, on creation and in arrears.
--
-- WHY. A Member has to be a record, not the absence of one. Three things depend
-- on that: the admin user list is only complete if every account has a role row
-- to read, `role_rank` stops needing a "no row means member" special case, and a
-- future tier can sit BELOW moderator without the absence of a row being
-- ambiguous between them.
--
-- `on conflict do nothing` on both inserts is what makes the backfill safe to run
-- over a database that already has an administrator in it: the existing row wins.
-- Getting this wrong would demote the only administrator to member and lock the
-- project owner out of the panel this migration exists to enable.

create or replace function public.provision_new_account()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id) values (new.id)
    on conflict (id) do nothing;

  insert into public.user_roles (user_id, role) values (new.id, 'member')
    on conflict (user_id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.provision_new_account();

-- Backfill. Both statements are idempotent, so ordering between them is free.
insert into public.profiles (id)
  select id from auth.users
  on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
  select id, 'member' from auth.users
  on conflict (user_id) do nothing;
