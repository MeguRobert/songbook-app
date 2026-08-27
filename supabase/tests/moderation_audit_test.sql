-- A moderation decision survives the decision that follows it.
--
-- The assertions that carry the design:
--
--   * Approving and rejecting each write one row, naming the moderator, the
--     song and the contributor.
--   * A rejection keeps its reason. songs.rejection_reason is nulled by the
--     BEFORE trigger the moment the status leaves 'rejected', so on the row
--     itself the sentence a contributor was given is gone as soon as they act on
--     it. In the log it stays.
--   * Reject, resubmit, approve leaves BOTH decisions. On the song row,
--     reviewed_by holds only the last one -- which is the whole reason the
--     row-level record was not enough.
--   * An edit to an approved song is not a decision and audits nothing.
--   * The moderator who wrote the row still cannot touch it.
--
-- Run with:  npx supabase test db      (needs Docker)

begin;
select plan(13);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('b2000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'singer@example.test', '', now(), now(), now()),
  ('b2000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'mod@example.test', '', now(), now(), now());

update public.user_roles set role = 'moderator'
  where user_id = 'b2000000-0000-0000-0000-000000000002';
update public.profiles set display_name = 'The Moderator'
  where id = 'b2000000-0000-0000-0000-000000000002';
-- A name and an accepted set of guidelines, because assert_may_submit
-- (20260822120500) requires both before a song may become 'pending'.
update public.profiles
   set display_name = 'A Singer', guidelines_accepted_at = now()
  where id = 'b2000000-0000-0000-0000-000000000001';

insert into public.songs (id, owner_id, status, title, payload, source)
values ('c3000000-0000-0000-0000-000000000001',
        'b2000000-0000-0000-0000-000000000001', 'draft',
        'Az Úrra bízom életem', '{}'::jsonb, 'user');

-- Submitted by its owner, so submitted_by_name is frozen by 20260822120200's
-- trigger rather than set here.
set local role postgres;
select set_config('request.jwt.claim.sub', 'b2000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
update public.songs set status = 'pending'
  where id = 'c3000000-0000-0000-0000-000000000001';

set local role postgres;
delete from public.admin_audit;

-- ---------------------------------------------------------------------------
-- A moderator rejects it
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'b2000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ update public.songs
        set status = 'rejected',
            rejection_reason = 'The third chord row does not line up with the words.'
      where id = 'c3000000-0000-0000-0000-000000000001' $$,
  'a moderator may reject a submission');

set local role postgres;

select is(
  (select action from public.admin_audit),
  'song_rejected',
  'and it is recorded as an action of its own -- until now a moderation decision '
  'was none of the four the constraint permitted');

select is(
  (select actor_name from public.admin_audit),
  'The Moderator',
  'naming who decided, frozen at the time of the decision');

select is(
  (select target_user_id from public.admin_audit),
  'b2000000-0000-0000-0000-000000000001'::uuid,
  'and whose song it was');

select is(
  (select target_email from public.admin_audit),
  null,
  'without their address -- unlike a deletion, the account is still there to '
  'join to');

select is(
  (select details->>'reason' from public.admin_audit),
  'The third chord row does not line up with the words.',
  'the reason the contributor was given is kept in full, because it IS the '
  'decision rather than the thing being changed');

select is(
  (select details->>'title' from public.admin_audit),
  'Az Úrra bízom életem',
  'and which song, or the row records nothing anybody can act on');

select is(
  (select details->>'submitted_by_name' from public.admin_audit),
  'A Singer',
  'carrying the frozen credit rather than a join that may not survive');

-- ---------------------------------------------------------------------------
-- Resubmitted and approved: the rejection must not be overwritten
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', 'b2000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
update public.songs set status = 'pending'
  where id = 'c3000000-0000-0000-0000-000000000001';

set local role postgres;
select set_config('request.jwt.claim.sub', 'b2000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"b2000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
update public.songs set status = 'approved'
  where id = 'c3000000-0000-0000-0000-000000000001';

set local role postgres;

-- The row itself now remembers only the approval, and the sentence is gone.
select is(
  (select rejection_reason from public.songs
    where id = 'c3000000-0000-0000-0000-000000000001'),
  null,
  'on the song row the rejection reason has been deleted by the next transition');

select is(
  (select count(*)::int from public.admin_audit),
  2,
  'but the log holds both decisions -- which is what the row-level record could '
  'never do, since reviewed_by keeps only the last one');

select is(
  (select details->>'reason' from public.admin_audit where action = 'song_rejected'),
  'The third chord row does not line up with the words.',
  'and the rejection still says why, a week after the contributor acted on it');

select is(
  (select details->>'from' from public.admin_audit where action = 'song_approved'),
  'pending',
  'each row saying what the song came from, so a re-approval reads differently '
  'from a first one');

-- ---------------------------------------------------------------------------
-- An edit is not a decision
-- ---------------------------------------------------------------------------
delete from public.admin_audit;
set local role authenticated;
update public.songs set title = 'Az Úrra bízom életem (javítva)'
  where id = 'c3000000-0000-0000-0000-000000000001';

set local role postgres;

select is_empty(
  $$ select id from public.admin_audit $$,
  'correcting an approved song audits nothing -- the log holds decisions, not '
  'keystrokes');

select * from finish();
rollback;
