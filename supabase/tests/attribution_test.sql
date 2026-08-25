-- The submitter's name is stamped at submission and frozen afterwards.
--
-- The point of these four assertions is that neither of the two parties who
-- could want to rewrite attribution can do it: not the contributor by renaming
-- their account, and not a client by sending the column back with a new value.

begin;
select plan(4);

-- Confirmed and guidelines-accepted, because the gate in 20260822120500 requires
-- both of a submitter. This file is about what happens to the NAME once a
-- submission is accepted, not about whether it is.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('b0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'clara@example.test', '', now(), now(), now());

update public.profiles
   set display_name = 'Clara K.', guidelines_accepted_at = now()
  where id = 'b0000000-0000-0000-0000-000000000001';

insert into public.songs (id, owner_id, status, title, payload) values (
  'bbbbbbbb-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'pending',
  'Erős vár a mi Istenünk',
  '{"originalKey":"C","verses":[]}'::jsonb);

select is(
  (select submitted_by_name from public.songs
    where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'Clara K.',
  'the display name is stamped when the song is submitted');

-- Renaming yourself does not rewrite history.
update public.profiles set display_name = 'Someone Else'
  where id = 'b0000000-0000-0000-0000-000000000001';

select is(
  (select submitted_by_name from public.songs
    where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'Clara K.',
  'renaming the account does not rewrite the stamped name');

-- Nor does sending a different value back on the song itself.
update public.songs set submitted_by_name = 'Definitely Not Clara'
  where id = 'bbbbbbbb-0000-0000-0000-000000000001';

select is(
  (select submitted_by_name from public.songs
    where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'Clara K.',
  'the stamped name cannot be overwritten by an update');

-- A draft has nothing to attribute yet.
insert into public.songs (id, owner_id, status, title, payload) values (
  'bbbbbbbb-0000-0000-0000-000000000002',
  'b0000000-0000-0000-0000-000000000001',
  'draft',
  'Still working on it',
  '{"originalKey":"C","verses":[]}'::jsonb);

select is(
  (select submitted_by_name from public.songs
    where id = 'bbbbbbbb-0000-0000-0000-000000000002'),
  null,
  'a draft carries no submitter name');

select * from finish();
rollback;
