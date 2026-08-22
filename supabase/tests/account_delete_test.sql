-- Deleting an account leaves the catalogue intact and the audit trail readable.
--
-- Same principle as 20260820190000: an approved song belongs to the catalogue,
-- not to the contributor. Taking a hymn off the shelf because the person who
-- transcribed it closed their account is not a thing this app should do.
--
-- Two assertions here are subtler than they look.
--
-- `lives_ok` on the delete: ON DELETE SET NULL performs an UPDATE on songs, which
-- fires the BEFORE UPDATE ownership guard. A guard written without an exception
-- for it makes account deletion fail outright with "song owner cannot be
-- changed", which looks like a permissions bug and is not.
--
-- The moderator assertion: songs_update_admin's WITH CHECK is only is_admin(),
-- so nothing in RLS stops a moderator writing owner_id = null and stripping a
-- song of its attribution. The guard's `auth.uid() is null` condition is what
-- confines orphaning to a service-role context -- the Edge Function and the FK
-- action -- and that is why the condition is not simply "owner became null".

begin;
select plan(7);

-- Confirmed addresses, because the gate in 20260822120500 requires one of a
-- submitter and this file needs a song that was actually accepted.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'leaving@example.test', '', now(), now(), now()),
  ('c0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'staying@example.test', '', now(), now(), now()),
  ('c0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'mod@example.test', '', now(), now(), now());

update public.profiles
   set display_name = 'Departed Member', guidelines_accepted_at = now()
  where id = 'c0000000-0000-0000-0000-000000000001';
update public.user_roles set role = 'moderator'
  where user_id = 'c0000000-0000-0000-0000-000000000003';

insert into public.songs (id, owner_id, status, title, payload) values (
  'cccccccc-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000001',
  'pending',
  'Jövel Szentlélek Úristen',
  '{"originalKey":"F","verses":[]}'::jsonb);

-- ---------------------------------------------------------------------------
-- Approved by the moderator, because only a real signed-in moderator can. A
-- server-side `update ... set status = 'approved'` is refused by the transition
-- trigger, which has no escape hatch for reaching a decided state.
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'c0000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claims',
  '{"sub":"c0000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;

update public.songs set status = 'approved'
  where id = 'cccccccc-0000-0000-0000-000000000001';

-- A moderator may edit an approved song, but may not strip its attribution.
select throws_ok(
  $$update public.songs set owner_id = null
     where id = 'cccccccc-0000-0000-0000-000000000001'$$,
  'song owner cannot be changed',
  'a moderator cannot orphan a song to erase who submitted it');

-- ---------------------------------------------------------------------------
-- Back to a server-side context. Claims are cleared so auth.uid() is null,
-- which is what the Edge Function's service-role connection looks like.
-- ---------------------------------------------------------------------------
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '', true);

select lives_ok(
  $$delete from auth.users where id = 'c0000000-0000-0000-0000-000000000001'$$,
  'deleting an account succeeds despite the ownership guard');

select isnt_empty(
  $$select 1 from public.songs where id = 'cccccccc-0000-0000-0000-000000000001'$$,
  'the approved song survives its submitter');

select is(
  (select owner_id from public.songs
    where id = 'cccccccc-0000-0000-0000-000000000001'),
  null,
  'the song is orphaned rather than deleted');

select is(
  (select submitted_by_name from public.songs
    where id = 'cccccccc-0000-0000-0000-000000000001'),
  'Departed Member',
  'the frozen name is still readable after the account is gone');

-- An orphan cannot be adopted, even server-side. Without this, deleting an
-- account would be a way to launder its submissions into a different one.
select throws_ok(
  $$update public.songs
       set owner_id = 'c0000000-0000-0000-0000-000000000002'
     where id = 'cccccccc-0000-0000-0000-000000000001'$$,
  'song owner cannot be changed',
  'an orphaned song cannot be re-adopted');

select is(
  (select count(*) from public.user_roles
    where user_id = 'c0000000-0000-0000-0000-000000000001'),
  0::bigint,
  'the role row goes with the account');

select * from finish();
rollback;
