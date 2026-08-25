-- The audit log is administrator-read and, from any client, unwritable.
--
-- The last assertion is the one with teeth: an administrator can READ the log and
-- still cannot write it. Only the Edge Function's service-role connection can, so
-- the person the log is about has no way to edit what it says about them.

begin;
select plan(5);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'member@example.test', '', now(), now()),
  ('d0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'boss@example.test', '', now(), now());

update public.user_roles set role = 'administrator'
  where user_id = 'd0000000-0000-0000-0000-000000000002';

insert into public.admin_audit
  (actor_id, actor_name, action, target_user_id, target_email, details)
values
  ('d0000000-0000-0000-0000-000000000002', 'The Boss', 'role_changed',
   'd0000000-0000-0000-0000-000000000001', 'member@example.test',
   '{"from":"member","to":"moderator"}'::jsonb);

-- An unknown action is not recordable, so a typo cannot invent a category.
select throws_ok(
  $$insert into public.admin_audit (action) values ('did_something')$$,
  '23514',
  null,
  'only the four known actions may be recorded');

-- ---------------------------------------------------------------------------
-- A member
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'd0000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"d0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select is_empty(
  'select 1 from public.admin_audit',
  'a member sees no audit entries');

select throws_ok(
  $$insert into public.admin_audit (action) values ('role_changed')$$,
  '42501',
  null,
  'a member cannot write an audit entry');

-- ---------------------------------------------------------------------------
-- An administrator: reads it, and still cannot write it
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', 'd0000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"d0000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*) from public.admin_audit), 1::bigint,
  'an administrator reads the audit log');

select throws_ok(
  $$insert into public.admin_audit (action) values ('role_changed')$$,
  '42501',
  null,
  'not even an administrator writes it from a client -- only the Edge Function does');

set local role postgres;
select * from finish();
rollback;
