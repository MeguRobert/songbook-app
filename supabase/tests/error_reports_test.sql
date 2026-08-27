-- Anyone may report a crash; almost nobody may read one.
--
-- Two assertions carry the whole design. The first is that a SIGNED-OUT caller
-- can insert -- if that ever stops working the reporting is worthless, because a
-- signed-out visitor is exactly who a first-time congregation member is. The
-- second is that the same caller, and every ordinary signed-in one, gets a
-- permission error rather than an empty list when they try to read the table
-- back. "HTTP 200 []" and "denied" look identical from a client and mean very
-- different things -- 20260728120200 exists because of precisely that confusion.
--
-- Run with:  npx supabase test db      (needs Docker running)
--
-- Impersonation is inline for the reason songs_rls_test.sql gives: once
-- `set local role authenticated` has run, that role cannot switch itself back,
-- so `set local role postgres` precedes every change of identity.

begin;
select plan(19);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('e0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'member@example.test', '', now(), now(), now()),
  ('e0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'moderator@example.test', '', now(), now(), now());

update public.user_roles set role = 'administrator'
  where user_id = 'e0000000-0000-0000-0000-000000000002';

-- ---------------------------------------------------------------------------
-- A signed-out visitor: may file, may not read
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

-- user_id is supplied on purpose, and is expected to be ignored.
select lives_ok(
  $$ insert into public.error_reports (message, stack, route, locale, platform,
                                       app_version, build_number, fingerprint,
                                       occurrences, user_id)
     values ('Null check operator used on a null value',
             '#0 SongView.build (package:songbook_app/…:42)',
             '/song/91', 'hu', 'web/android 412x915 dpr2.6',
             '1.1.0', '143', 'a1b2c3', 3,
             'e0000000-0000-0000-0000-000000000001') $$,
  'a SIGNED-OUT visitor CAN file a crash report');

set local role postgres;

select is(
  (select count(*)::int from public.error_reports),
  1,
  'and the report was actually stored');

select ok(
  (select user_id from public.error_reports) is null,
  'an anonymous report carries no user, whatever the client sent');

set local role anon;

-- Not is_empty: anon has no SELECT grant at all, so this is a hard permission
-- error rather than a policy filtering rows away. That distinction is the point
-- -- a write-only endpoint cannot be probed for what it holds.
select throws_ok(
  'select 1 from public.error_reports',
  '42501',
  null,
  'a signed-out visitor CANNOT read reports -- denied, not merely empty');

-- ---------------------------------------------------------------------------
-- An ordinary signed-in member: same as anyone else
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', 'e0000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"e0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

-- Claiming the moderator's id, which the trigger is expected to overwrite.
insert into public.error_reports (message, route, user_id)
values ('RangeError (index): Invalid value',
        '/setlists',
        'e0000000-0000-0000-0000-000000000002');

-- Here the grant exists and the policy is what withholds the rows, so this is
-- the empty case rather than the denied one.
select is_empty(
  'select 1 from public.error_reports',
  'a member has the privilege to read but no policy grants any row');

select throws_ok(
  $$ update public.error_reports set message = 'nothing to see here' $$,
  '42501',
  null,
  'a member cannot rewrite a report');

select throws_ok(
  'delete from public.error_reports',
  '42501',
  null,
  'a member cannot delete a report');

set local role postgres;

select is(
  (select user_id from public.error_reports where route = '/setlists'),
  'e0000000-0000-0000-0000-000000000001'::uuid,
  'user_id is stamped from the session, not taken from the payload');

-- ---------------------------------------------------------------------------
-- A moderator: reads them, and still cannot edit them
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'e0000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"e0000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.error_reports),
  2,
  'a moderator reads every report -- this is the whole point of the table');

select throws_ok(
  $$ update public.error_reports set message = 'nothing to see here' $$,
  '42501',
  null,
  'not even a moderator may edit one -- a log its subject can edit is not a log');

-- ---------------------------------------------------------------------------
-- Oversized input is truncated, never refused
-- ---------------------------------------------------------------------------
-- A rejected insert is a crash the owner never hears about, which is the exact
-- failure this table was built to end. So the caps clamp rather than throw.
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select lives_ok(
  $$ insert into public.error_reports (message, stack)
     values ('LONG ' || repeat('x', 900), repeat('y', 5000)) $$,
  'an oversized report is accepted rather than refused');

-- A blank summary would fail the not-null check on its own; the trigger
-- substitutes a placeholder so the row survives.
insert into public.error_reports (message) values ('   ');

set local role postgres;

select is(
  (select length(message)::int from public.error_reports where message like 'LONG %'),
  500,
  'the message is clamped to the schema cap');

select is(
  (select length(stack)::int from public.error_reports where message like 'LONG %'),
  4000,
  'and so is the stack');

select is(
  (select message from public.error_reports where message = 'unspecified error'),
  'unspecified error',
  'a blank summary becomes a placeholder instead of failing the insert');

-- ---------------------------------------------------------------------------
-- The abuse guards
-- ---------------------------------------------------------------------------
-- PostgREST turns a posted JSON array into ONE multi-row INSERT, which is how a
-- rate limit counted per row gets walked straight past.
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select throws_ok(
  $$ insert into public.error_reports (message)
     values ('bulk one'), ('bulk two') $$,
  'P0001',
  null,
  'a bulk insert is refused outright -- one report per statement');

select throws_ok(
  'select public.prune_error_reports()',
  '42501',
  null,
  'no client role may run the pruner');

set local role postgres;

-- created_at is set by the trigger, so ageing a row has to be done behind it.
update public.error_reports set created_at = now() - interval '45 days'
  where message like 'LONG %' or message = 'unspecified error';

select is(
  public.prune_error_reports(),
  2,
  'the pruner removes reports past the retention window');

-- ---------------------------------------------------------------------------
-- The hourly ceiling
-- ---------------------------------------------------------------------------
-- Cleared first so the count is about this loop and nothing earlier.
delete from public.error_reports;

set local role anon;

-- A loop rather than one multi-row INSERT, because that is what 65 separate
-- HTTP requests look like -- the shape the ceiling is actually there to stop.
select lives_ok(
  $$ do $flood$
     begin
       for i in 1..65 loop
         insert into public.error_reports (message) values ('flood ' || i);
       end loop;
     end
     $flood$; $$,
  'the surplus past the ceiling is dropped silently, not raised at the caller');

set local role postgres;

select is(
  (select count(*)::int from public.error_reports),
  60,
  'and exactly the ceiling landed -- 65 attempts, 60 rows');

select * from finish();
rollback;
