-- Proves that one person's favourites and setlists are theirs alone.
--
-- This is the assertion the whole feature rests on. Everything else about
-- cross-device sync is a merge algorithm that can be argued about; "Bob can read
-- Alice's setlists" is not a design question, it is a breach -- and it is the
-- exact shape of the old Songbook app's headline defect, which streamed rows to
-- clients and filtered them in the UI (see songs_rls_test.sql).
--
-- Run with:  npx supabase test db      (needs Docker running)
--
-- Impersonation is done inline rather than via helper functions on purpose:
-- once `set local role authenticated` has run, that role has no privileges on a
-- custom helper schema and cannot switch itself back. `set local role postgres`
-- before each switch restores the privilege needed to make the next one.

begin;
select plan(25);

-- ---------------------------------------------------------------------------
-- Fixtures: two ordinary users. No admin, deliberately.
-- ---------------------------------------------------------------------------
-- There is no admin in this file because there is no admin in the policies.
-- public.songs gives moderators a bypass because reviewing a shared catalogue
-- requires seeing unapproved rows; nothing about moderating a hymnal requires
-- reading what someone has favourited, so a moderator here is an ordinary user
-- and testing one would only re-test an ordinary user.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'alice@example.test', '', now(), now(), now()),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'bob@example.test', '', now(), now(), now());

-- Alice: one live favourite and one TOMBSTONE. The tombstone is in the fixtures
-- rather than as an afterthought because it is a row like any other and must be
-- protected like one -- "which songs Bob has stopped liking" is no more his
-- business to publish than which he likes.
insert into public.user_favorites (user_id, song_id, changed_at, sort_order, removed) values
  ('11111111-1111-1111-1111-111111111111', 'hymnal:151', now() - interval '1 day', 0, false),
  ('11111111-1111-1111-1111-111111111111', 'hymnal:7',   now() - interval '2 hours', 1, true);

insert into public.user_setlists (user_id, id, name, song_ids, changed_at) values
  ('11111111-1111-1111-1111-111111111111', 'sl_alice_1', 'Vasárnap délelőtt',
   array['hymnal:151', 'hymnal:90', 'user:l9f3a2c4b1'], now() - interval '1 day');

-- Bob: one of each, so every "Bob sees zero of Alice's" assertion below is
-- proving a filter and not an empty table.
insert into public.user_favorites (user_id, song_id, changed_at, sort_order, removed) values
  ('22222222-2222-2222-2222-222222222222', 'hymnal:900', now(), 0, false);

insert into public.user_setlists (user_id, id, name, song_ids, changed_at) values
  ('22222222-2222-2222-2222-222222222222', 'sl_bob_1', 'Esti', array['hymnal:900'], now());

-- ---------------------------------------------------------------------------
-- Harness sanity check. If auth.uid() came back null for an "authenticated"
-- user, every visibility assertion below would pass vacuously.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

select is(
  auth.uid(),
  '11111111-1111-1111-1111-111111111111'::uuid,
  'harness: auth.uid() reflects the impersonated user (guards against vacuous passes)'
);

-- The positive half first, so a policy that denies everything cannot pass this
-- file by accident.
select is(
  (select count(*)::int from public.user_favorites where song_id = 'hymnal:151'),
  1,
  'Alice CAN read her own favourite'
);

-- A tombstone must be readable by its owner or the merge cannot see the removal
-- and every un-favourite is undone by the next sync.
select is(
  (select count(*)::int from public.user_favorites where removed),
  1,
  'Alice CAN read her own tombstone (removal has to survive the round trip)'
);

select is(
  (select count(*)::int from public.user_favorites),
  2,
  'and she sees exactly her own two rows, not Bob''s'
);

-- ---------------------------------------------------------------------------
-- THE CORE ASSERTION: another account's rows do not exist as far as you are
-- concerned.
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.user_favorites
   where song_id in ('hymnal:151', 'hymnal:7')),
  0,
  'Bob CANNOT see Alice''s favourites, live or tombstoned'
);

-- Stated as a total rather than by id as well: this fails if ANY row of anyone
-- else's leaks, not merely the two the fixtures name.
select is(
  (select count(*)::int from public.user_favorites),
  1,
  'Bob sees exactly one favourite -- his own -- whatever else the table holds'
);

-- RLS gives Bob no row to update, so this is not an error: it silently affects
-- zero rows. UPDATE must be in a CTE to be counted.
with touched as (
  update public.user_favorites set sort_order = 99
  where song_id = 'hymnal:151'
  returning 1
)
select is(
  (select count(*)::int from touched),
  0,
  'Bob''s update of Alice''s favourite affects zero rows'
);

with removed as (
  delete from public.user_favorites where song_id = 'hymnal:151' returning 1
)
select is(
  (select count(*)::int from removed),
  0,
  'Bob''s delete of Alice''s favourite affects zero rows'
);

-- The insert side is the one that DOES throw, because with check has a row to
-- refuse. Without this policy Bob could write into Alice's account and the
-- select policy would then hide the evidence from him.
select throws_ok(
  $$ insert into public.user_favorites (user_id, song_id)
     values ('11111111-1111-1111-1111-111111111111', 'hymnal:42') $$,
  '42501',
  null,
  'Bob CANNOT write a favourite onto Alice''s account'
);

select lives_ok(
  $$ insert into public.user_favorites (user_id, song_id)
     values ('22222222-2222-2222-2222-222222222222', 'hymnal:42') $$,
  'Bob CAN write a favourite onto his own'
);

-- ---------------------------------------------------------------------------
-- The same four questions for setlists, which carry rather more than a bit.
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from public.user_setlists where id = 'sl_alice_1'),
  0,
  'Bob CANNOT see Alice''s setlist'
);

select is(
  (select count(*)::int from public.user_setlists),
  1,
  'Bob sees exactly one setlist -- his own'
);

with touched as (
  update public.user_setlists set name = 'hijacked' where id = 'sl_alice_1' returning 1
)
select is(
  (select count(*)::int from touched),
  0,
  'Bob''s rename of Alice''s setlist affects zero rows'
);

with removed as (
  delete from public.user_setlists where id = 'sl_alice_1' returning 1
)
select is(
  (select count(*)::int from removed),
  0,
  'Bob''s delete of Alice''s setlist affects zero rows'
);

select throws_ok(
  $$ insert into public.user_setlists (user_id, id, name)
     values ('11111111-1111-1111-1111-111111111111', 'sl_planted', 'planted') $$,
  '42501',
  null,
  'Bob CANNOT plant a setlist on Alice''s account'
);

-- ---------------------------------------------------------------------------
-- A signed-out visitor has no business here at all.
-- ---------------------------------------------------------------------------
-- Not "sees zero rows" -- a permission error. Nothing is granted to anon on
-- these tables, because a signed-out person's favourites live on their device.
-- 42501 rather than "200 []" is also what makes a deployment verifiable, which
-- is the whole argument of 20260728120200.
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select throws_ok(
  $$ select count(*) from public.user_favorites $$,
  '42501',
  null,
  'A signed-out visitor is refused outright on favourites (no grant, not an empty result)'
);

select throws_ok(
  $$ select count(*) from public.user_setlists $$,
  '42501',
  null,
  'and on setlists'
);

-- ---------------------------------------------------------------------------
-- The ordered list survives the round trip, and the timestamp rules hold.
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

-- The order IS the setlist. A text[] that came back sorted, deduplicated or
-- reordered would be a different service.
select is(
  (select song_ids from public.user_setlists where id = 'sl_alice_1'),
  array['hymnal:151', 'hymnal:90', 'user:l9f3a2c4b1'],
  'a setlist''s song ids come back in the order they were sung, user songs included'
);

-- A clock set to the future would otherwise win every merge on every device for
-- as long as it is wrong, with nothing the user could do about it.
insert into public.user_favorites (user_id, song_id, changed_at)
values ('11111111-1111-1111-1111-111111111111', 'hymnal:2030', now() + interval '4 years');

select ok(
  (select changed_at from public.user_favorites where song_id = 'hymnal:2030') <= now(),
  'a changed_at from the future is clamped to now (a wrong clock cannot win forever)'
);

-- The clamp is forward-only, and that direction matters: a change made offline
-- on Tuesday and pushed on Friday must still be dated Tuesday, or the merge
-- becomes "last device to reach the server wins" and offline editing is
-- silently reordered.
insert into public.user_favorites (user_id, song_id, changed_at)
values ('11111111-1111-1111-1111-111111111111', 'hymnal:1848', timestamptz '2026-08-01 10:00:00+00');

select is(
  (select changed_at from public.user_favorites where song_id = 'hymnal:1848'),
  timestamptz '2026-08-01 10:00:00+00',
  'an older changed_at is preserved, so a push from an offline device keeps its event time'
);

-- updated_at answers "when did this device last actually reach us", which is a
-- different question from changed_at and must not be answerable by the client.
insert into public.user_favorites (user_id, song_id, updated_at)
values ('11111111-1111-1111-1111-111111111111', 'hymnal:1568', timestamptz '2020-01-01 00:00:00+00');

select ok(
  (select updated_at from public.user_favorites where song_id = 'hymnal:1568')
    > now() - interval '1 minute',
  'updated_at is stamped server-side, ignoring what the client sent'
);

-- ---------------------------------------------------------------------------
-- Two people may like the same song.
-- ---------------------------------------------------------------------------
-- Sounds obvious; it is the primary key being (user_id, song_id) rather than
-- song_id. Get that wrong and Alice's insert collides with a row she cannot see,
-- so the app reports a duplicate-key failure for a song she has never
-- favourited. Bob already inserted hymnal:42 above; Alice does the same here.
select lives_ok(
  $$ insert into public.user_favorites (user_id, song_id)
     values ('11111111-1111-1111-1111-111111111111', 'hymnal:42') $$,
  'Alice can favourite a song Bob has already favourited'
);

set local role postgres;
select is(
  (select count(*)::int from public.user_favorites where song_id = 'hymnal:42'),
  2,
  'and both rows exist: the key is (user_id, song_id), not song_id'
);

-- ---------------------------------------------------------------------------
-- Deleting the account takes the data with it.
-- ---------------------------------------------------------------------------
-- The contrast with public.songs is deliberate: an approved song outlives its
-- submitter because it belongs to the catalogue (20260822120300). A favourite
-- belongs to nobody but the person who made it, so it goes when they do.
--
-- Last, because it destroys the fixtures above.
delete from auth.users where id = '11111111-1111-1111-1111-111111111111';

select is(
  (select count(*)::int from public.user_favorites
   where user_id = '11111111-1111-1111-1111-111111111111'),
  0,
  'deleting the account removes its favourites'
);

select is(
  (select count(*)::int from public.user_setlists
   where user_id = '11111111-1111-1111-1111-111111111111'),
  0,
  'and its setlists'
);

select * from finish();
rollback;
