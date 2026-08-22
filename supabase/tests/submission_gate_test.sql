-- Submitting is gated in the database, not merely in the UI.
--
-- Each refusal is raised as a bare snake_case token, which is what the Dart layer
-- maps to a localised message. The assertions match on those tokens, so a change
-- of wording here is a change the app has to notice.
--
-- The last assertion is the important one: it submits by UPDATING a draft rather
-- than by inserting, which is the ordinary path through the Add-song screen. A
-- gate that only covers the insert is bypassed by saving first.

begin;
select plan(9);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('e0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'ok@example.test', '', now(), now(), now()),
  ('e0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'unconfirmed@example.test', '', null, now(), now());

update public.profiles set display_name = 'Ready', guidelines_accepted_at = now()
  where id = 'e0000000-0000-0000-0000-000000000001';
update public.profiles set display_name = 'Not Verified', guidelines_accepted_at = now()
  where id = 'e0000000-0000-0000-0000-000000000002';

-- ---------------------------------------------------------------------------
-- Baseline
-- ---------------------------------------------------------------------------
select is((select count(*) from public.app_settings), 1::bigint,
  'there is exactly one settings row');

select isnt(
  (select guidelines_hu from public.app_settings where id = 1), '',
  'the guidelines are seeded in Hungarian, so the acceptance tick means something on day one');

select lives_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000001', 'pending', 'A valid submission',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'a confirmed member who accepted the guidelines may submit');

-- ---------------------------------------------------------------------------
-- Each stop, one at a time
-- ---------------------------------------------------------------------------
select throws_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000002', 'pending', 'Unverified',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'email_not_confirmed', 'an unconfirmed address cannot submit');

update public.profiles set guidelines_accepted_at = null
  where id = 'e0000000-0000-0000-0000-000000000001';
select throws_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000001', 'pending', 'No guidelines',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'guidelines_not_accepted', 'the guidelines must be accepted first');
update public.profiles set guidelines_accepted_at = now()
  where id = 'e0000000-0000-0000-0000-000000000001';

update public.profiles set display_name = null
  where id = 'e0000000-0000-0000-0000-000000000001';
select throws_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000001', 'pending', 'Anonymous',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'display_name_required',
   'a submission with no name to credit is refused, so no email is ever published');
update public.profiles set display_name = 'Ready'
  where id = 'e0000000-0000-0000-0000-000000000001';

update public.app_settings set submissions_open = false where id = 1;
select throws_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000001', 'pending', 'Door shut',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'submissions_closed', 'the master switch closes the door');
update public.app_settings set submissions_open = true where id = 1;

-- ---------------------------------------------------------------------------
-- A draft is never gated: saving privately is not submitting
-- ---------------------------------------------------------------------------
select lives_ok($$
  insert into public.songs (id, owner_id, status, title, payload)
  values ('eeeeeeee-0000-0000-0000-000000000001',
          'e0000000-0000-0000-0000-000000000001', 'draft', 'Private draft',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'a draft is not gated');

-- ---------------------------------------------------------------------------
-- The cap, reached by submitting a draft rather than by inserting
-- ---------------------------------------------------------------------------
-- One pending submission already exists from the baseline above, so a cap of 1
-- is already met. Submitting the draft is the path a gate on INSERT alone would
-- have missed entirely.
update public.app_settings set daily_submission_cap = 1 where id = 1;

select set_config('request.jwt.claim.sub', 'e0000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"e0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select throws_ok($$
  update public.songs set status = 'pending'
   where id = 'eeeeeeee-0000-0000-0000-000000000001'
$$, 'daily_limit_reached',
   'submitting a saved draft is gated identically to inserting one');

set local role postgres;
select * from finish();
rollback;
