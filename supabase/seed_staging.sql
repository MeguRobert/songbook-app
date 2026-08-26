-- Synthetic submissions for the STAGING project only.
--
-- Why this is not in supabase/migrations/
-- ---------------------------------------
-- Everything in migrations/ runs against production the next time somebody runs
-- `supabase db push`. This file must never do that, so it lives outside that
-- directory and is run by hand. That is the whole reason for the separation —
-- not tidiness.
--
-- What it is for
-- --------------
-- `db push` against a fresh project already gives you the eight hymnal songs and
-- the guidelines text, because 20260728120400 and ...120500 seed them. What it
-- does not give you is a single user submission, so the moderation queue, the
-- daily cap, the rejection path and frozen attribution are all invisible — which
-- is most of what there is to test. This fills that in.
--
-- How to run it
-- -------------
-- 1. Sign up on the staging site with the addresses in `test_emails` below.
--    Signing up is the point: it exercises the `on_auth_user_created` trigger
--    from 20260822120100, which is the one most likely to break.
-- 2. Paste this whole file into the staging project's SQL editor and run it.
--
-- Re-running is safe: every row has a derived id and inserts are
-- `on conflict do nothing`, so a second run changes nothing rather than
-- duplicating or fighting the update triggers.
--
-- Two guards, and why they are the right ones
-- -------------------------------------------
-- This file cannot check "am I staging?" — a Postgres session has no idea which
-- Supabase project it belongs to. So instead of a marker that could be copied
-- into the wrong place, it guards on facts that are true of a staging database
-- and false of production:
--
--   * It does nothing at all unless the test accounts exist. In production they
--     do not, so running this there is a no-op that says so.
--   * It refuses outright if it finds user submissions belonging to anyone else,
--     because that means real contributors' data is in this database and this is
--     not a scratch environment.
--
-- The second guard is the one that matters. It will start refusing on staging
-- too, once you have submitted songs there by hand from an account that is not
-- in this list — which is correct: at that point staging has state you probably
-- did not mean to seed on top of. Add the address to the list, or clear the rows
-- out deliberately.

do $$
declare
  -- EDIT THESE to the addresses you signed up with on the staging site.
  test_emails text[] := array[
    'songbook.staging.member@example.com',
    'songbook.staging.moderator@example.com'
  ];

  test_ids     uuid[];
  primary_id   uuid;
  secondary_id uuid;
  foreign_rows integer;
  inserted     integer;

  -- Numbered well clear of the hymnal so a test row is obvious on sight and can
  -- never collide with a canonical number.
  base_number  integer := 9000;
begin
  select coalesce(array_agg(id), '{}') into test_ids
    from auth.users where email = any(test_emails);

  if array_length(test_ids, 1) is null then
    raise notice
      'No accounts found for % — nothing seeded. Sign up on the staging site first (see the header of this file).',
      test_emails;
    return;
  end if;

  primary_id   := test_ids[1];
  secondary_id := coalesce(test_ids[2], test_ids[1]);

  select count(*) into foreign_rows
    from public.songs
   where source = 'user'
     and (owner_id is null or not (owner_id = any(test_ids)));

  if foreign_rows > 0 then
    raise exception
      'Refusing to seed: this database holds % user song(s) owned by somebody other than the test accounts. That means real submissions live here. See the guard note in supabase/seed_staging.sql.',
      foreign_rows;
  end if;

  -- The submission gate (20260822120500) requires a display name and an accepted
  -- set of guidelines before it will admit a `pending` row, and it is right to.
  -- Setting them here is not a workaround: it is the same state the app puts a
  -- contributor in before their first submission, so the inserts below go
  -- through the real gate rather than around it.
  insert into public.profiles as p (id, display_name, guidelines_accepted_at)
  select u.id,
         'Staging ' || split_part(u.email, '@', 1),
         now()
    from auth.users u
   where u.id = any(test_ids)
  on conflict (id) do update
     set display_name           = coalesce(p.display_name, excluded.display_name),
         guidelines_accepted_at = coalesce(p.guidelines_accepted_at, excluded.guidelines_accepted_at);

  -- Five rows, one per state worth looking at. `pending` is deliberately two, so
  -- the queue has an order to get wrong. Kept well under the daily cap of 5 per
  -- owner, which `assert_may_submit` enforces on the insert path.
  with seed (slot, owner, status, title, reason, body) as (
    values
      (1, 'primary',   'draft',    'Staging draft — never submitted',
          null,
          'A draft the contributor has not offered yet. It must be invisible to everyone but its owner.'),
      (2, 'primary',   'pending',  'Staging submission — awaiting review',
          null,
          'The ordinary case. This is what should appear in the moderation queue.'),
      (3, 'secondary', 'pending',  'Staging submission — second in the queue',
          null,
          'A second pending row from a different account, so queue ordering and attribution can be told apart.'),
      (4, 'primary',   'approved', 'Staging song — approved',
          null,
          'An approved user submission. It should read as a normal catalogue entry alongside the hymnal.'),
      (5, 'primary',   'rejected', 'Staging submission — rejected',
          'Test rejection: this row exists so the rejection reason has somewhere to show.',
          'A rejected row. Its owner should see the reason; nobody else should see the row.')
  )
  -- `submitted_at`, `reviewed_at`/`reviewed_by` and `submitted_by_name` are set
  -- here for the rows that need them, rather than left to the triggers.
  --
  -- The triggers cannot supply them, and it is worth knowing why: both
  -- `stamp_submitted_by` and the status trigger act on the *transition into*
  -- pending or into approved/rejected, and these rows are inserted already in
  -- their final state. So a row inserted straight as `approved` keeps whatever
  -- the insert supplies — which is nothing, unless it is spelled out. Left
  -- alone, the queue would show an approved song with no submitter and no
  -- review date, which is exactly the kind of thing you would open a bug about.
  --
  -- Timestamps are staggered by slot so the queue has a genuine oldest-first
  -- order to get right.
  insert into public.songs (
    id, owner_id, source, status, rejection_reason,
    number, title, book, tags,
    submitted_at, reviewed_at, reviewed_by, submitted_by_name,
    payload
  )
  select
    md5('staging-seed:' || s.slot)::uuid,
    case s.owner when 'primary' then primary_id else secondary_id end,
    'user',
    s.status::public.song_status,
    s.reason,
    base_number + s.slot,
    s.title,
    'Staging',
    array['staging', 'test']::text[],
    case when s.status <> 'draft'
         then now() - (s.slot * 6 || ' hours')::interval end,
    case when s.status in ('approved', 'rejected')
         then now() - (s.slot || ' hours')::interval end,
    case when s.status in ('approved', 'rejected')
         then secondary_id end,
    case when s.status <> 'draft'
         then (select display_name from public.profiles
                where id = case s.owner when 'primary' then primary_id else secondary_id end) end,
    jsonb_build_object(
      'number',        base_number + s.slot,
      'title',         s.title,
      'book',          'Staging',
      'originalKey',   'G',
      'timeSignature', '4/4',
      'tags',          jsonb_build_array('staging', 'test'),
      'verses',        jsonb_build_array(
        jsonb_build_object(
          'number',      1,
          'hasNotation', false,
          'plainText',   s.body
        )
      )
    )
    from seed s
  on conflict (id) do nothing;

  get diagnostics inserted = row_count;

  raise notice
    'Seeded % row(s) across % test account(s). Re-running is a no-op.',
    inserted, array_length(test_ids, 1);
end $$;

-- Promote yourself, once, after signing up.
--
-- Kept as a comment rather than run above on purpose: which staging account is
-- the administrator is your decision, and a seed script that silently hands out
-- rank 90 is a habit worth not forming even in a scratch environment.
--
--   update public.user_roles
--      set role = 'administrator'
--    where user_id = (select id from auth.users
--                      where email = 'songbook.staging.moderator@example.com');
--
-- `user_roles` has no INSERT or UPDATE policy at all, by design, so this only
-- works from the SQL editor or a service-role context — never from the app. The
-- row itself already exists: `on_auth_user_created` provisions every new account
-- as `member`.
