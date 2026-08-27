-- error_reports carries two kinds of row, and neither can pretend to be the
-- other.
--
-- The assertions that carry the design:
--
--   * A client built before 20260827130000 -- which on a PWA means every phone
--     with a cached bundle, for days after a deploy -- still writes a valid row,
--     and it is recorded as a crash.
--   * An event the schema has never heard of does not raise. This endpoint is
--     reachable by anon and is written from inside error handlers; an exception
--     here is one the client can only swallow, so the guard degrades instead.
--   * `details` holds measurements and is emptied wholesale when it is not
--     something small and object-shaped. Half a JSON document is not a smaller
--     JSON document.
--   * The privileges did not move. anon still cannot read back what it wrote,
--     whichever event it wrote.
--
-- Run with:  npx supabase test db      (needs Docker running)
--
-- Impersonation is inline for the reason songs_rls_test.sql gives: once
-- `set local role authenticated` has run, that role cannot switch itself back,
-- so `set local role postgres` precedes every change of identity.

begin;
select plan(14);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('f0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'member@example.test', '', now(), now(), now()),
  ('f0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'boss@example.test', '', now(), now(), now());

update public.user_roles set role = 'administrator'
  where user_id = 'f0000000-0000-0000-0000-000000000002';

-- ---------------------------------------------------------------------------
-- The shape of the table
-- ---------------------------------------------------------------------------
select has_column('public', 'error_reports', 'event',
  'error_reports has an event discriminator');
select has_column('public', 'error_reports', 'details',
  'error_reports has somewhere to put the measurements');
select col_not_null('public', 'error_reports', 'event',
  'every row says which kind it is');

-- ---------------------------------------------------------------------------
-- A signed-out visitor files both kinds
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

-- No `event` column at all: exactly what a cached bundle from before this
-- migration posts. It must still land, and it must land as a crash.
select lives_ok(
  $$ insert into public.error_reports (message, fingerprint, build_number)
     values ('Null check operator used on a null value', 'a1b2c3', '143') $$,
  'a client that has never heard of `event` still files a valid row');

-- The photo-import row this whole stream exists to write. Numbers only: no
-- image, no words read off the page, no lyrics.
select lives_ok(
  $$ insert into public.error_reports
       (event, message, fingerprint, build_number, route, details)
     values ('photo_import', 'photo import: ok', 'b2c3d4', '143', '/import',
             '{"outcome":"ok","ms":2140,"width":2048,"height":1532,
                "bytesPerPixel":0.0912,"words":41,"columns":1,
                "notices":["photoLowResolution"]}'::jsonb) $$,
  'a photo-import measurement can be filed by a signed-out visitor too');

-- Reading is the part that did not change, and the part worth re-asserting: a
-- write-only endpoint is a much less interesting target. Denied rather than
-- empty, which is the distinction 20260728120200 exists because of -- 'HTTP 200
-- []' and 'denied' look identical from a client and mean very different things.
select throws_ok(
  'select id from public.error_reports',
  '42501',
  null,
  'and still cannot read a single row of either kind back -- denied, not empty');

set local role postgres;

select is(
  (select event from public.error_reports where fingerprint = 'a1b2c3'),
  'crash',
  'the pre-migration row defaulted to crash rather than to null');

select is(
  (select details->>'outcome' from public.error_reports where fingerprint = 'b2c3d4'),
  'ok',
  'the measurements survived the trigger intact');

-- ---------------------------------------------------------------------------
-- The guard degrades instead of raising
-- ---------------------------------------------------------------------------
set local role anon;

select lives_ok(
  $$ insert into public.error_reports (event, message, fingerprint)
     values ('something_invented', 'from a future build', 'c3d4e5') $$,
  'an unknown event does NOT raise at a caller that is inside an error handler');

select lives_ok(
  $$ insert into public.error_reports (message, fingerprint, details)
     values ('a stack of numbers', 'd4e5f6',
             to_jsonb(repeat('x', 4000))) $$,
  'details that are neither small nor an object do not raise either');

set local role postgres;

select is(
  (select event from public.error_reports where fingerprint = 'c3d4e5'),
  'crash',
  'the unknown event was recorded as what it certainly is: something wrong');

select is(
  (select details from public.error_reports where fingerprint = 'd4e5f6'),
  '{}'::jsonb,
  'oversized details were emptied wholesale, not truncated into nonsense');

-- The constraint is still declared, and it cannot be demonstrated by inserting:
-- a BEFORE trigger runs before constraints are checked, so the coalesce above has
-- already made every insert legal. It stands as the backstop for any path that
-- does not go through this trigger.
select col_has_check('public', 'error_reports', 'event',
  'and the check constraint stands behind the trigger, not instead of it');

-- ---------------------------------------------------------------------------
-- A moderator reads them
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'f0000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"f0000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

-- One place to look, which is the entire argument for the discriminator over a
-- second table: the same query, filtered.
select is(
  (select count(*)::int from public.error_reports where event = 'photo_import'),
  1,
  'an administrator can read the imports apart from the crashes in one table');

select * from finish();
rollback;
