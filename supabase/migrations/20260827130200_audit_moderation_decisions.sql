-- Approving and rejecting a song becomes accountable.
--
-- WHY THIS EXISTS. admin_audit permits four actions -- role_changed,
-- user_deleted, user_invited, settings_changed -- and a moderation decision is
-- none of them. For a moderation system that is the obvious gap: the queue asks
-- somebody to make a judgement about another person's contribution, and until
-- now the judgement left no permanent record of who made it.
--
-- THE ROW-LEVEL RECORD IS NOT ENOUGH, and the reasons are not theoretical:
--
--   * songs.reviewed_by and songs.reviewed_at hold the LAST decision only. A
--     song rejected on Tuesday, resubmitted, and approved on Friday remembers
--     Friday. The rejection -- the decision somebody might actually want to ask
--     about -- is overwritten by the approval that followed it.
--   * songs.rejection_reason is deleted outright on the next transition. The
--     trigger in 20260822120300 sets it to null whenever status leaves
--     'rejected', so the sentence a contributor was given is gone the moment
--     they act on it. "Why was my song rejected?" is currently unanswerable
--     from the database a week later.
--   * The whole record vanishes with the song. A deleted song takes its own
--     history with it, which is exactly the case admin_audit's target_user_id
--     was deliberately left un-keyed for.
--
-- SO THE CONSTRAINT GAINS TWO VALUES -- and both arrive with their writer, in
-- this migration, which is the discipline 20260827130000 spells out. The reverse
-- of what happened to settings_changed, which sat in the constraint for five
-- days with nothing emitting it.

alter table public.admin_audit
  drop constraint admin_audit_action_check;

alter table public.admin_audit
  add constraint admin_audit_action_check check (action in (
    'role_changed',
    'user_deleted',
    'user_invited',
    'settings_changed',
    'song_approved',
    'song_rejected'
  ));

-- ---------------------------------------------------------------------------
-- The writer
-- ---------------------------------------------------------------------------
-- AFTER UPDATE on songs, and a trigger rather than the Edge Function for the
-- same reasons 20260827130100 gives at length: approving a song is an ordinary
-- RLS-governed UPDATE the client makes directly, the trigger runs inside that
-- transaction so it cannot record a decision that rolled back, and it audits
-- every caller rather than one.
--
-- It reads OLD, deliberately. songs_enforce_status_transition is a BEFORE
-- trigger that has already nulled rejection_reason if the status left
-- 'rejected', so the outgoing reason is only legible from the old row.
--
-- WHAT GOES IN, and the one place this departs from the rule that audit rows
-- hold no prose:
--
--   * The song's id, number and title, because a row that cannot say WHICH song
--     was rejected is not a record of anything. The title is the song's own
--     name, which for an approved song is public catalogue data anyway.
--   * from/to statuses, so a re-approval reads differently from a first one.
--   * THE REJECTION REASON, capped. 20260827130100 records the guidelines as
--     lengths and this records the sentence in full, and the difference is real
--     rather than convenient: the guidelines are the OBJECT of a change and
--     still live in app_settings afterwards, while the rejection reason IS the
--     decision and is destroyed by the next transition. Recording its length
--     would preserve nothing anybody could ever act on.
--
-- WHAT DOES NOT GO IN: payload. Not a line of it. The lyrics and chords of a
-- song are the contribution itself, they are already in songs, and copying them
-- into an append-only table nobody prunes is how an audit log becomes a second,
-- worse copy of the catalogue.

create or replace function public.audit_song_review()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor uuid := auth.uid();
  name  text;
begin
  -- Only a decision, and only when it is new. An UPDATE that touches an
  -- approved song's words is an edit, not an approval, and 20260820190000
  -- already restricts who may make one.
  if new.status = old.status then
    return null;
  end if;
  if new.status not in ('approved', 'rejected') then
    return null;
  end if;

  select display_name into name from public.profiles where id = actor;

  -- target_user_id is the contributor, which is what these columns are for.
  --
  -- target_email is left NULL on purpose, unlike the user_deleted row. That row
  -- needs a frozen address because the account it names is about to stop
  -- existing; here the contributor's account is still there to join to, so
  -- copying their address into a permanent table would be exposure that buys
  -- nothing. The frozen submitted_by_name is carried instead -- it is already
  -- the name the catalogue credits publicly.
  insert into public.admin_audit
    (actor_id, actor_name, action, target_user_id, target_email, details)
  values (
    actor,
    name,
    case new.status when 'approved' then 'song_approved' else 'song_rejected' end,
    old.owner_id,
    null,
    jsonb_strip_nulls(jsonb_build_object(
      'song_id',   new.id,
      'number',    new.number,
      'title',     left(new.title, 200),
      'from',      old.status,
      'to',        new.status,
      'submitted_by_name', new.submitted_by_name,
      -- From OLD: the BEFORE trigger has already cleared it on the new row when
      -- the status left 'rejected'.
      'reason', case
                  when new.status = 'rejected'
                    then left(btrim(coalesce(new.rejection_reason, '')), 500)
                  else null
                end
    ))
  );

  return null;
end;
$$;

create trigger songs_audit_review
  after update on public.songs
  for each row execute function public.audit_song_review();

-- ---------------------------------------------------------------------------
-- The insert path, and why it is not audited here
-- ---------------------------------------------------------------------------
-- A song cannot be INSERTed straight into 'approved' by a client:
-- songs_enforce_insert (20260728120100) refuses any insert whose status is not
-- 'draft' or 'pending' for a non-admin, and the canonical hymnal in
-- 20260728120300 is seeded by the migration itself, as the owner, with no
-- auth.uid() to attribute anything to. So there is no client path that produces
-- an approved song without passing through the UPDATE above.
--
-- An administrator inserting a pre-approved row by hand in the SQL editor would
-- not be audited. That is left alone rather than covered: it is the owner acting
-- as the owner on their own database, which is outside what any in-database log
-- can meaningfully constrain, and an AFTER INSERT trigger would have to
-- distinguish it from the seed migration to avoid auditing 200 hymnal rows.
