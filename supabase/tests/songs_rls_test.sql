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
select plan(20);

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

select is(
  (select count(*)::int from public.songs),
  1,
  'Bob sees exactly the one approved song, not the whole table'
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
  (select count(*)::int from public.songs),
  1,
  'A signed-out visitor CAN read the approved catalogue (signed-out stays functional)'
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
  (select count(*)::int from public.songs),
  2,
  'An admin sees both the pending and the approved song'
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

insert into public.songs (id, owner_id, source, status, number, book, title, payload) values (
  'cccccccc-0000-0000-0000-000000000001',
  null, 'hymnal', 'approved', 90, 'Zsoltárok',
  'Tebenned bíztunk eleitől fogva',
  '{"number":90,"originalKey":"Bb","verses":[{"number":1,"lines":[{"text":"Tebenned bíztunk"}]}]}'::jsonb
);

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

select is(
  (select count(*)::int from public.songs where source = 'hymnal'),
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
set local role postgres;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$ update public.songs set source = 'hymnal'
     where id = 'aaaaaaaa-0000-0000-0000-000000000002' $$,
  'P0001',
  null,
  'A user CANNOT promote their own song to canonical hymnal content'
);

select * from finish();
rollback;
