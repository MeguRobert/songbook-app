-- The role ladder is ranked, the two predicates split on rank, and every account
-- is provisioned with a role of its own.
--
-- Impersonation idiom copied from songs_rls_test.sql, including its reasoning:
-- `set local role postgres` before each switch, because once `set local role
-- authenticated` has run that role has no privilege to switch itself back.

begin;
select plan(12);

-- ---------------------------------------------------------------------------
-- Fixtures: one of each tier. The role rows are UPDATEd, not inserted, because
-- the provisioning trigger has already created them as 'member' -- which is
-- itself part of what this file proves.
-- ---------------------------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'member@example.test', '', now(), now()),
  ('a0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'mod@example.test', '', now(), now()),
  ('a0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'admin@example.test', '', now(), now());

update public.user_roles set role = 'moderator'
  where user_id = 'a0000000-0000-0000-0000-000000000002';
update public.user_roles set role = 'administrator'
  where user_id = 'a0000000-0000-0000-0000-000000000003';

-- ---------------------------------------------------------------------------
-- The ladder itself
-- ---------------------------------------------------------------------------
select is(
  (select rank from public.roles where name = 'member'), 10::smallint,
  'member sits at rank 10');

select ok(
  (select rank from public.roles where name = 'moderator')
    < (select rank from public.roles where name = 'administrator'),
  'moderator ranks below administrator');

-- ---------------------------------------------------------------------------
-- A member
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select is(public.can_moderate(), false, 'a member may not moderate');
select is(public.is_administrator(), false, 'a member is not an administrator');
select throws_ok(
  'select 1 from public.user_roles',
  '42501',
  null,
  'a member cannot read user_roles at all');

-- ---------------------------------------------------------------------------
-- A moderator
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select is(public.can_moderate(), true, 'a moderator may moderate');
select is(public.is_administrator(), false, 'a moderator is NOT an administrator');
select is(public.is_admin(), true,
  'is_admin() is an alias for can_moderate(), so the existing policies are unchanged');

-- ---------------------------------------------------------------------------
-- An administrator
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;

select is(public.is_administrator(), true, 'an administrator is an administrator');

-- ---------------------------------------------------------------------------
-- Provisioning
-- ---------------------------------------------------------------------------
set local role postgres;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values ('a0000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'fresh@example.test', '', now(), now());

select is(
  (select role from public.user_roles where user_id = 'a0000000-0000-0000-0000-000000000004'),
  'member',
  'a new account starts as a member');

select isnt_empty(
  $$select 1 from public.profiles where id = 'a0000000-0000-0000-0000-000000000004'$$,
  'a new account gets a profile row');

select is(
  (select role from public.user_roles where user_id = 'a0000000-0000-0000-0000-000000000003'),
  'administrator',
  'provisioning does not demote an account that already had a role');

select * from finish();
rollback;
