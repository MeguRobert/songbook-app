-- A moderator's own song is published; everybody else's still waits.
--
-- Two halves, and the second is the one that matters. The first proves the
-- convenience works: a moderator or an administrator sharing a song lands it in
-- the catalogue, stamped exactly as a hand approval would stamp it, by either of
-- the two routes into 'pending'. The second proves nothing was traded for it --
-- an ordinary member is still refused 'approved' by every route there is, and a
-- moderator acting on somebody else's draft still goes through the queue.
--
-- Numbers are left NULL throughout. songs_approved_number_unique is a partial
-- index over `number is not null`, so giving these fixtures numbers would make
-- them collide with each other the moment they are approved, and the test would
-- be about that instead.
--
-- Run with:  npx supabase test db      (needs Docker)

begin;
select plan(25);

-- ---------------------------------------------------------------------------
-- Fixtures: a member, a moderator, an administrator
-- ---------------------------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('d1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'member@example.test', '', now(), now(), now()),
  ('d1000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'mod@example.test', '', now(), now(), now()),
  ('d1000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'boss@example.test', '', now(), now(), now());

-- UPDATE rather than INSERT: 20260822120100 provisions a 'member' row and a
-- profile for every new account, so an insert here collides on the key.
update public.user_roles set role = 'moderator'
  where user_id = 'd1000000-0000-0000-0000-000000000002';
update public.user_roles set role = 'administrator'
  where user_id = 'd1000000-0000-0000-0000-000000000003';

-- The member needs both, because assert_may_submit (20260822120500) refuses a
-- submission without a name to credit and an accepted set of guidelines. The
-- other two are exempt from that gate and are given a name only, which is what
-- the frozen credit is read from.
update public.profiles
   set display_name = 'A Member', guidelines_accepted_at = now()
  where id = 'd1000000-0000-0000-0000-000000000001';
update public.profiles set display_name = 'The Moderator'
  where id = 'd1000000-0000-0000-0000-000000000002';
update public.profiles set display_name = 'The Administrator'
  where id = 'd1000000-0000-0000-0000-000000000003';

-- ---------------------------------------------------------------------------
-- Route one: inserted straight as 'pending' (the Share action)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ insert into public.songs (id, owner_id, status, title, payload) values (
       'e1000000-0000-0000-0000-000000000001',
       'd1000000-0000-0000-0000-000000000002',
       'pending', 'A moderator''s own song', '{"originalKey":"G","verses":[]}'::jsonb) $$,
  'a moderator may share a song, asking for pending exactly as anybody else does');

set local role postgres;

select is(
  (select status::text from public.songs
    where id = 'e1000000-0000-0000-0000-000000000001'),
  'approved',
  'and it is published on the spot -- there is nobody left to review it');

select is(
  (select reviewed_by from public.songs
    where id = 'e1000000-0000-0000-0000-000000000001'),
  'd1000000-0000-0000-0000-000000000002'::uuid,
  'reviewed_by names the moderator, stamped server-side like any other approval');

select isnt(
  (select reviewed_at from public.songs
    where id = 'e1000000-0000-0000-0000-000000000001'),
  null::timestamptz,
  'and reviewed_at is set, so the catalogue cannot tell this from a hand approval');

select isnt(
  (select submitted_at from public.songs
    where id = 'e1000000-0000-0000-0000-000000000001'),
  null::timestamptz,
  'the row still went through pending, so submitted_at survived the promotion');

-- The reason the promotion is a second statement rather than a rewrite of
-- new.status: songs_stamp_submitted_by only stamps a row that is becoming
-- 'pending', and a row that arrived as 'approved' would have been credited to
-- nobody.
select is(
  (select submitted_by_name from public.songs
    where id = 'e1000000-0000-0000-0000-000000000001'),
  'The Moderator',
  'and the frozen credit was stamped, which a straight-to-approved row would '
  'have skipped');

-- An administrator is above a moderator on the ladder, so rank >= moderator
-- covers them; asserted rather than assumed, because it is the half of the
-- owner's sentence a rank comparison could quietly lose.
set local role postgres;
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claims',
  '{"sub":"d1000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;

insert into public.songs (id, owner_id, status, title, payload) values (
  'e1000000-0000-0000-0000-000000000002',
  'd1000000-0000-0000-0000-000000000003',
  'pending', 'An administrator''s own song', '{"originalKey":"D","verses":[]}'::jsonb);

set local role postgres;
select is(
  (select status::text from public.songs
    where id = 'e1000000-0000-0000-0000-000000000002'),
  'approved',
  'an administrator''s submission is published too');

-- ---------------------------------------------------------------------------
-- The member, on the same route
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

insert into public.songs (id, owner_id, status, title, payload) values (
  'e1000000-0000-0000-0000-000000000003',
  'd1000000-0000-0000-0000-000000000001',
  'pending', 'A member''s song', '{"originalKey":"C","verses":[]}'::jsonb);

set local role postgres;
select is(
  (select status::text from public.songs
    where id = 'e1000000-0000-0000-0000-000000000003'),
  'pending',
  'AN ORDINARY MEMBER''S SUBMISSION STILL WAITS -- the queue is unchanged for '
  'everybody the exemption does not name');

select is(
  (select reviewed_by from public.songs
    where id = 'e1000000-0000-0000-0000-000000000003'),
  null::uuid,
  'and nothing was stamped on it as though it had been reviewed');

-- ---------------------------------------------------------------------------
-- Route two: draft -> pending, the route 20260822120600 exists because of
-- ---------------------------------------------------------------------------
set local role postgres;
insert into public.songs
  (id, owner_id, status, rejection_reason, title, payload) values
  ('e1000000-0000-0000-0000-000000000004',
   'd1000000-0000-0000-0000-000000000001', 'draft', null,
   'A member''s saved draft', '{"originalKey":"C","verses":[]}'::jsonb),
  ('e1000000-0000-0000-0000-000000000005',
   'd1000000-0000-0000-0000-000000000002', 'draft', null,
   'A moderator''s saved draft', '{"originalKey":"A","verses":[]}'::jsonb),
  ('e1000000-0000-0000-0000-000000000006',
   'd1000000-0000-0000-0000-000000000002', 'rejected', 'the chords do not line up',
   'A moderator''s revised song', '{"originalKey":"E","verses":[]}'::jsonb);

select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

update public.songs set status = 'pending'
  where id = 'e1000000-0000-0000-0000-000000000004';

set local role postgres;
select is(
  (select status::text from public.songs
    where id = 'e1000000-0000-0000-0000-000000000004'),
  'pending',
  'a member submitting a saved draft still reaches the queue and stops there');

select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

update public.songs set status = 'pending'
  where id = 'e1000000-0000-0000-0000-000000000005';
update public.songs set status = 'pending'
  where id = 'e1000000-0000-0000-0000-000000000006';

set local role postgres;
select is(
  (select status::text from public.songs
    where id = 'e1000000-0000-0000-0000-000000000005'),
  'approved',
  'a moderator submitting a saved draft is published -- the second route into '
  'pending behaves as the first, which is the whole point of covering both');

select is(
  (select status::text from public.songs
    where id = 'e1000000-0000-0000-0000-000000000006'),
  'approved',
  'and so does a rejected song revised and resubmitted');

select is(
  (select rejection_reason from public.songs
    where id = 'e1000000-0000-0000-0000-000000000006'),
  null,
  'with the old rejection reason cleared, as on any other departure from rejected');

-- ---------------------------------------------------------------------------
-- The boundary: a moderator's OWN song, not anybody's song they can reach
-- ---------------------------------------------------------------------------
-- songs_update_admin lets a moderator move any row. Without the ownership half
-- of may_self_publish, a moderator submitting a member's draft on their behalf
-- would silently publish it with neither of them deciding to.
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

update public.songs set status = 'draft'
  where id = 'e1000000-0000-0000-0000-000000000004';
update public.songs set status = 'pending'
  where id = 'e1000000-0000-0000-0000-000000000004';

set local role postgres;
select is(
  (select status::text from public.songs
    where id = 'e1000000-0000-0000-0000-000000000004'),
  'pending',
  'a moderator submitting SOMEBODY ELSE''S draft does not publish it -- self-'
  'publication is what was permitted, not publication on behalf of a third party');

-- ---------------------------------------------------------------------------
-- Nothing was loosened
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"d1000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ update public.songs set status = 'approved'
      where id = 'e1000000-0000-0000-0000-000000000003' $$,
  'P0001',
  null,
  'a member still cannot UPDATE their own pending song to approved');

select throws_ok(
  $$ insert into public.songs (owner_id, status, title, payload) values (
       'd1000000-0000-0000-0000-000000000001', 'approved',
       'straight to the shelf', '{}'::jsonb) $$,
  '42501',
  null,
  'nor insert one that is already approved');

set local role postgres;
select is(
  (select status::text from public.songs
    where id = 'e1000000-0000-0000-0000-000000000003'),
  'pending',
  'and after both attempts the member''s song is exactly where it was');

-- A moderator's client does not get to ask either. It asks for 'pending' like
-- everybody's client and the server decides what that means -- which is the
-- difference between a server-side rule and a client-side one.
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ insert into public.songs (owner_id, status, title, payload) values (
       'd1000000-0000-0000-0000-000000000002', 'approved',
       'asking to be published', '{}'::jsonb) $$,
  '42501',
  null,
  'A MODERATOR''S CLIENT IS REFUSED TOO when it asks to be published outright');

-- ---------------------------------------------------------------------------
-- The audit
-- ---------------------------------------------------------------------------
set local role postgres;

select is(
  (select count(*)::int from public.admin_audit
    where details->>'song_id' = 'e1000000-0000-0000-0000-000000000001'),
  1,
  'a self-publication writes exactly one audit row -- the record matters MORE '
  'when the approval was self-granted, not less');

select is(
  (select action from public.admin_audit
    where details->>'song_id' = 'e1000000-0000-0000-0000-000000000001'),
  'song_approved',
  'recorded as an approval, because that is what it is');

select is(
  (select details->>'from' from public.admin_audit
    where details->>'song_id' = 'e1000000-0000-0000-0000-000000000001'),
  'pending',
  'from pending, because the row genuinely passed through it');

select is(
  (select details->>'self_published' from public.admin_audit
    where details->>'song_id' = 'e1000000-0000-0000-0000-000000000001'),
  'true',
  'and flagged, so "which approvals had no second pair of eyes" is one filter '
  'rather than an inference from two columns holding the same uuid');

select is(
  (select count(*)::int from public.admin_audit
    where details->>'song_id' = 'e1000000-0000-0000-0000-000000000005'),
  1,
  'the draft route is audited too -- one rule, one writer, both routes');

select is(
  (select count(*)::int from public.admin_audit
    where details->>'song_id' = 'e1000000-0000-0000-0000-000000000003'),
  0,
  'a member''s submission decides nothing and audits nothing');

-- An ordinary approval must read exactly as it did before this migration.
select set_config('request.jwt.claim.sub', 'd1000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"d1000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

update public.songs set status = 'approved'
  where id = 'e1000000-0000-0000-0000-000000000003';

set local role postgres;
select is(
  (select details->>'self_published' from public.admin_audit
    where details->>'song_id' = 'e1000000-0000-0000-0000-000000000003'),
  null,
  'while a moderator approving somebody else''s song carries no flag at all -- '
  'jsonb_strip_nulls drops the key, so an ordinary row is byte-identical to the '
  'ones written before this existed');

select * from finish();
rollback;
