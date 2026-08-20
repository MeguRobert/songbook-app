-- Proves the old Songbook app's headline defect cannot recur.
--
-- That app enforced approval ONLY in the UI: the repository streamed every
-- unapproved song to every client and the list widget hid the rows. Anyone with
-- devtools, or the raw SDK, saw everything. These assertions are the regression
-- test for exactly that, plus the self-approval hole.
--
-- Run with:  npx supabase test db      (needs Docker running)
--
-- Impersonation is done inline rather than via helper functions on purpose:
-- once `set local role authenticated` has run, that role has no privileges on a
-- custom helper schema and cannot switch itself back. `set local role postgres`
-- before each switch restores the privilege needed to make the next one.

begin;
select plan(26);

-- ---------------------------------------------------------------------------
-- Fixtures: two ordinary users and one admin.
-- ---------------------------------------------------------------------------
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'alice@example.test', '', now(), now()),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'bob@example.test', '', now(), now()),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'admin@example.test', '', now(), now());

insert into public.user_roles (user_id, role) values
  ('33333333-3333-3333-3333-333333333333', 'admin');

-- Alice's song, submitted for review but NOT approved. originalKey and the
-- verses live inside `payload` -- there is deliberately no column for them.
insert into public.songs (id, owner_id, status, title, payload) values (
  'aaaaaaaa-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111',
  'pending',
  'Tebenned bíztunk eleitől fogva',
  '{"originalKey":"Bb","verses":[{"number":1,"lines":[{"text":"Tebenned bíztunk eleitől fogva"}]}]}'::jsonb
);

-- An approved song, so we can prove the policy is not simply denying everything.
insert into public.songs (id, owner_id, status, title, payload) values (
  'aaaaaaaa-0000-0000-0000-000000000002',
  '11111111-1111-1111-1111-111111111111',
  'approved',
  'Mint a szép híves patakra',
  '{"originalKey":"G","verses":[{"number":1,"lines":[{"text":"Mint a szép híves patakra"}]}]}'::jsonb
);

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

-- ---------------------------------------------------------------------------
-- THE CORE ASSERTION: an unapproved song is invisible to everyone else.
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.songs
   where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  0,
  'Bob CANNOT see Alice''s pending song (the old app''s defect)'
);

-- Deliberately NOT `count(*) = 1`. The hymnal seed migration loads 8 approved
-- songs, so any absolute count is brittle and would have to be re-tuned every
-- time the seed grows. Counting *unapproved rows visible to Bob* is both
-- seed-independent and a stricter statement of the actual requirement: it fails
-- if any unapproved row leaks, not merely if the total is unexpected.
select is(
  (select count(*)::int from public.songs where status <> 'approved'),
  0,
  'Bob sees ZERO unapproved rows, whatever else the table holds'
);

-- Signed-out visitor.
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select is(
  (select count(*)::int from public.songs
   where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  0,
  'A signed-out visitor CANNOT see a pending song'
);

select is(
  (select count(*)::int from public.songs where status <> 'approved'),
  0,
  'A signed-out visitor sees ZERO unapproved rows'
);

-- The positive half: prove the policy is permitting, not just denying. Scoped to
-- the approved fixture by id so the seed size is irrelevant.
select is(
  (select count(*)::int from public.songs
   where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  1,
  'A signed-out visitor CAN read an approved song (signed-out stays functional)'
);

-- ---------------------------------------------------------------------------
-- The owner and admins can see it, so the policy is not just denying all.
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.songs
   where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  1,
  'Alice CAN see her own pending song'
);

set local role postgres;
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.songs
   where id in ('aaaaaaaa-0000-0000-0000-000000000001',
                'aaaaaaaa-0000-0000-0000-000000000002')),
  2,
  'An admin sees both the pending and the approved fixture song'
);

-- ---------------------------------------------------------------------------
-- Self-approval is impossible. RLS alone cannot do this -- the trigger does.
-- P0001 is the SQLSTATE of a plpgsql RAISE EXCEPTION.
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ update public.songs set status = 'approved'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'P0001',
  null,
  'Alice CANNOT approve her own song'
);

select throws_ok(
  $$ update public.songs set status = 'rejected', rejection_reason = 'nope'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'P0001',
  null,
  'Alice cannot reject either -- decisions are admin-only in both directions'
);

select throws_ok(
  $$ update public.songs set owner_id = '22222222-2222-2222-2222-222222222222'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'P0001',
  null,
  'Ownership cannot be reassigned (no laundering a submission via another account)'
);

-- Legal owner transition still works.
select lives_ok(
  $$ update public.songs set status = 'draft'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'Alice CAN withdraw her submission back to draft'
);

-- Bob cannot edit a song he does not own. RLS gives him no row, so this is not
-- an error -- it silently affects zero rows. UPDATE must be in a CTE here.
set local role postgres;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
set local role authenticated;

with touched as (
  update public.songs set title = 'hijacked'
  where id = 'aaaaaaaa-0000-0000-0000-000000000002'
  returning 1
)
select is(
  (select count(*)::int from touched),
  0,
  'Bob''s update of a song he does not own affects zero rows'
);

-- ---------------------------------------------------------------------------
-- Admin review works, and rejection requires a reason.
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ update public.songs set status = 'approved'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'An admin CAN approve a song'
);

select is(
  (select reviewed_by from public.songs
   where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  '33333333-3333-3333-3333-333333333333'::uuid,
  'reviewed_by is stamped server-side, not supplied by the client'
);

select throws_ok(
  $$ update public.songs set status = 'rejected', rejection_reason = null
     where id = 'aaaaaaaa-0000-0000-0000-000000000002' $$,
  'P0001',
  null,
  'Rejecting without a reason is refused'
);

-- ---------------------------------------------------------------------------
-- Canonical hymnal rows: ownerless, world-readable, and untouchable by users.
-- ---------------------------------------------------------------------------
set local role postgres;

-- Number 9990 in a test-only book, NOT ('Zsoltárok', 90). The seed migration
-- already ships psalm 90 as approved canonical content, and
-- songs_approved_number_unique is a real constraint, so reusing that pair aborts
-- the whole transaction and every later assertion silently never runs.
insert into public.songs (id, owner_id, source, status, number, book, title, payload) values (
  'cccccccc-0000-0000-0000-000000000001',
  null, 'hymnal', 'approved', 9990, 'Teszt',
  'Tebenned bíztunk eleitől fogva',
  '{"number":9990,"originalKey":"Bb","verses":[{"number":1,"lines":[{"text":"Tebenned bíztunk"}]}]}'::jsonb
);

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

-- By id, not `where source = 'hymnal'`: the seed already holds 8 canonical rows.
select is(
  (select count(*)::int from public.songs
   where id = 'cccccccc-0000-0000-0000-000000000001'),
  1,
  'A signed-out visitor CAN read canonical hymnal songs'
);

-- Ownerless rows are unwritable by non-admins without any rule saying so:
-- the owner policies test owner_id = auth.uid(), and NULL = uid is NULL, not true.
set local role postgres;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
set local role authenticated;

with touched as (
  update public.songs set title = 'defaced'
  where id = 'cccccccc-0000-0000-0000-000000000001'
  returning 1
)
select is(
  (select count(*)::int from touched),
  0,
  'A signed-in user CANNOT modify a canonical hymnal song (NULL owner never matches)'
);

with removed as (
  delete from public.songs
  where id = 'cccccccc-0000-0000-0000-000000000001'
  returning 1
)
select is(
  (select count(*)::int from removed),
  0,
  'A signed-in user CANNOT delete a canonical hymnal song'
);

-- A user cannot smuggle in canonical content of their own.
select throws_ok(
  $$ insert into public.songs (owner_id, source, status, number, title, payload)
     values (null, 'hymnal', 'approved', 999, 'fake canon', '{}'::jsonb) $$,
  '42501',
  null,
  'A user CANNOT insert a canonical hymnal song (RLS insert policy forces source = user)'
);

-- Nor promote an existing submission of theirs to canonical.
--
-- Against a DRAFT row of Alice's, deliberately. Both of her earlier songs are
-- approved by this point, and an owner has no write access to an approved row
-- at all now -- so aiming this at one would affect zero rows, throw nothing,
-- and quietly stop testing source immutability while still passing.
set local role postgres;
insert into public.songs (id, owner_id, status, title, payload) values (
  'aaaaaaaa-0000-0000-0000-000000000003',
  '11111111-1111-1111-1111-111111111111',
  'draft',
  'Draft, so the owner can still write to it',
  '{"originalKey":"C","verses":[]}'::jsonb
);
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ update public.songs set source = 'hymnal'
     where id = 'aaaaaaaa-0000-0000-0000-000000000003' $$,
  'P0001',
  null,
  'A user CANNOT promote their own song to canonical hymnal content'
);

-- ---------------------------------------------------------------------------
-- An approved song is out of its owner's hands.
-- ---------------------------------------------------------------------------
-- The gap this covers: approval used to gate the *transition* into 'approved'
-- and nothing after it. A content-only UPDATE by the owner met no check in the
-- trigger and satisfied the old policy, so the owner of an approved song could
-- silently rewrite what the congregation reads -- title, hymn number, the
-- verses themselves -- with no second review. Nothing tested it.
--
-- A fresh row, so these do not depend on what earlier sections left behind.
set local role postgres;
insert into public.songs (id, owner_id, status, number, book, title, payload) values (
  'aaaaaaaa-0000-0000-0000-000000000004',
  '11111111-1111-1111-1111-111111111111',
  'approved', 9991, 'Teszt',
  'Approved, and therefore the catalogue''s',
  '{"originalKey":"D","verses":[{"number":1,"lines":[{"text":"eredeti"}]}]}'::jsonb
);
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

-- Zero rows, not an exception: the policy simply does not offer an approved row
-- to its owner, exactly as songs_delete_own_undecided already did for DELETE.
with touched as (
  update public.songs set title = 'quietly rewritten'
  where id = 'aaaaaaaa-0000-0000-0000-000000000004'
  returning 1
)
select is(
  (select count(*)::int from touched),
  0,
  'Alice CANNOT retitle her own approved song'
);

with touched as (
  update public.songs
     set number = 1, payload = '{"originalKey":"D","verses":[]}'::jsonb
  where id = 'aaaaaaaa-0000-0000-0000-000000000004'
  returning 1
)
select is(
  (select count(*)::int from touched),
  0,
  'Nor renumber it, nor replace the verses in it'
);

select is(
  (select title from public.songs
   where id = 'aaaaaaaa-0000-0000-0000-000000000004'),
  'Approved, and therefore the catalogue''s',
  'and what the congregation reads is unchanged'
);

-- The trigger is the second lock, so prove it independently of the policy.
-- `role postgres` bypasses RLS but still fires triggers, and auth.uid() still
-- reads the claim -- so this is the same signed-in non-admin arriving with the
-- policy out of the way, which is what a future edit to that policy would look
-- like.
set local role postgres;
select throws_ok(
  $$ update public.songs set title = 'past the policy'
     where id = 'aaaaaaaa-0000-0000-0000-000000000004' $$,
  'P0001',
  null,
  'and the trigger refuses it even with RLS bypassed'
);

-- Not simply denying everything: a moderator is how a typo in an approved song
-- gets fixed, and that has to keep working.
select set_config('request.jwt.claim.sub', '33333333-3333-3333-3333-333333333333', true);
select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ update public.songs set title = 'Approved, and corrected by a moderator'
     where id = 'aaaaaaaa-0000-0000-0000-000000000004' $$,
  'An admin CAN still correct an approved song'
);

select * from finish();
rollback;
