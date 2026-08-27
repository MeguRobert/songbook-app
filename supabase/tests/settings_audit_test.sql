-- Changing the project's rules leaves a trace, and the person who changed them
-- cannot edit it.
--
-- The assertions that carry the design:
--
--   * An administrator's edit writes exactly one settings_changed row, naming
--     what moved and what it moved from.
--   * Pressing Save with nothing edited writes NOTHING. The settings screen
--     sends all six columns every time, so a no-op update is the normal shape of
--     an administrator opening the screen and closing it -- and a log with that
--     in it stops being read.
--   * The guidelines are recorded as lengths, never as text. An audit trail says
--     who did it; version history says what it said.
--   * The administrator who wrote the row still cannot touch it, which is the
--     property that makes the log worth keeping at all.
--   * A member's attempt is refused by RLS and audits nothing -- a refused change
--     is not a change.
--
-- Run with:  npx supabase test db      (needs Docker running)

begin;
select plan(12);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('a1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'member@example.test', '', now(), now(), now()),
  ('a1000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'boss@example.test', '', now(), now(), now());

update public.user_roles set role = 'administrator'
  where user_id = 'a1000000-0000-0000-0000-000000000002';

update public.profiles set display_name = 'The Boss'
  where id = 'a1000000-0000-0000-0000-000000000002';

-- The seed row from 20260822120500 is what an administrator actually edits, so
-- nothing is inserted here. Whatever the audit log already holds is cleared, so
-- the counts below are about this test and not about the seed.
delete from public.admin_audit;

-- ---------------------------------------------------------------------------
-- An administrator closes the door and shortens the queue
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"a1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

-- All six columns, which is what AppSettings.toUpdate() sends: the screen has no
-- idea which of them the administrator actually touched.
select lives_ok(
  $$ update public.app_settings set
       submissions_open        = false,
       require_confirmed_email = true,
       daily_submission_cap    = 2,
       guidelines_en           = guidelines_en,
       guidelines_hu           = guidelines_hu || ' Írd le figyelmesen.',
       guidelines_ro           = guidelines_ro
     where id = 1 $$,
  'an administrator may change the settings');

set local role postgres;

select is(
  (select count(*)::int from public.admin_audit where action = 'settings_changed'),
  1,
  'and exactly one settings_changed row was written -- the action that until now '
  'was in the constraint with no writer anywhere');

select is(
  (select actor_name from public.admin_audit where action = 'settings_changed'),
  'The Boss',
  'frozen under the name they had at the time, not joined at read time');

select is(
  (select actor_id from public.admin_audit where action = 'settings_changed'),
  'a1000000-0000-0000-0000-000000000002'::uuid,
  'attributed to the caller, from auth.uid() rather than from anything sent');

-- Three of six columns were sent unchanged and must not appear.
select is(
  (select details->'changed' from public.admin_audit where action = 'settings_changed'),
  '["submissions_open", "daily_submission_cap", "guidelines_hu"]'::jsonb,
  'naming only what actually moved, out of the six the screen always sends');

select is(
  (select details->'daily_submission_cap'->>'from' from public.admin_audit
    where action = 'settings_changed'),
  '5',
  'with the value it had before, which is the thing nobody could otherwise recover');

select is(
  (select details->'submissions_open'->>'to' from public.admin_audit
    where action = 'settings_changed'),
  'false',
  'and the value it has now');

-- The guidelines went in as two lengths and no text. A substring would be worse
-- than nothing: it would look like the text and not be it.
select ok(
  (select (details->'guidelines_hu'->>'to_length')::int
        > (details->'guidelines_hu'->>'from_length')::int
     and not (details::text like '%figyelmesen%')
     from public.admin_audit where action = 'settings_changed'),
  'the guidelines are recorded as lengths, and their text is nowhere in the row');

select is(
  (select updated_by from public.app_settings where id = 1),
  'a1000000-0000-0000-0000-000000000002'::uuid,
  'and app_settings.updated_by, null since the column was created, now says who');

-- ---------------------------------------------------------------------------
-- Pressing Save with nothing edited
-- ---------------------------------------------------------------------------
delete from public.admin_audit;
set local role authenticated;

select lives_ok(
  $$ update public.app_settings set
       submissions_open        = submissions_open,
       require_confirmed_email = require_confirmed_email,
       daily_submission_cap    = daily_submission_cap,
       guidelines_en           = guidelines_en,
       guidelines_hu           = guidelines_hu,
       guidelines_ro           = guidelines_ro
     where id = 1 $$,
  'a save with nothing edited is allowed');

set local role postgres;

select is_empty(
  $$ select id from public.admin_audit $$,
  'and audits nothing at all -- the log holds changes, not visits');

-- ---------------------------------------------------------------------------
-- A member
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

-- Refused by app_settings_write_admin as zero rows affected rather than as an
-- error -- which is a separate known bug on the Dart side, and is exactly why
-- the audit row must come from the database and not from the client that
-- believes it succeeded.
update public.app_settings set daily_submission_cap = 99 where id = 1;

set local role postgres;

select is_empty(
  $$ select id from public.admin_audit $$,
  'a refused change is not a change, and leaves no row claiming it happened');

select * from finish();
rollback;
