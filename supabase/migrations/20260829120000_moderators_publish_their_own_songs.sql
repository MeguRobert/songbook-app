-- A moderator's own song is published, not queued.
--
-- WHY. The queue exists so that somebody who is not the contributor looks at a
-- song before the congregation sings from it. When the contributor IS that
-- somebody, the queue holds a decision with nobody left to make it, and the only
-- thing it adds is a second trip to /admin/queue to press Approve on a row they
-- wrote themselves.
--
-- This is the same reasoning 20260822120500 already applied one layer down.
-- assert_may_submit exempts can_moderate() from the daily cap, the
-- submissions-closed switch and the guidelines tick, on the grounds that "a
-- moderator entering a song is already a reviewed act". That sentence decides
-- this migration too; all that was left was the status the act lands in.
--
-- WHICH HELPER, and it matters here because the names do not mean what they
-- look like. 20260822120000 made is_admin() an alias of can_moderate(), so
-- is_admin() reads as "administrator" and means "moderator and above", while
-- is_administrator() is the one that means administrator. The owner asked for
-- "administrator or moderator" -- rank >= 50 -- so this calls can_moderate() BY
-- NAME rather than through the alias. Behaviourally identical to is_admin();
-- the difference is that a reader of the next migration does not have to go and
-- check. The alias itself is left exactly where it is, for the reason
-- 20260822120000 gives: rewriting the six policies and two triggers that call it
-- is a change with no behaviour in it and a large RLS surface to re-audit.

-- ---------------------------------------------------------------------------
-- The rule, in one place
-- ---------------------------------------------------------------------------
-- Two things, and both are load-bearing:
--
--   * can_moderate(), which is about the ACTOR -- whoever is behind auth.uid()
--     in this statement.
--   * owner = auth.uid(), which ties it to their OWN song.
--
-- The second is not decoration. songs_update_admin lets a moderator move any
-- row, including a draft belonging to somebody else, so without it a moderator
-- who submitted a member's draft on their behalf would silently publish that
-- member's song without either of them deciding to. Self-publication is the
-- thing being permitted; publishing on behalf of a third party is not, and it
-- still goes through the queue like everything else.
create or replace function public.may_self_publish(owner uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select owner is not null
     and owner = auth.uid()
     and public.can_moderate();
$$;

-- ---------------------------------------------------------------------------
-- The mechanism: promote AFTER the row has become 'pending', not instead of it
-- ---------------------------------------------------------------------------
-- The obvious implementation is to rewrite new.status to 'approved' inside
-- enforce_song_status_transition, and it is wrong in two ways that a test would
-- have caught late:
--
--   1. songs_stamp_submitted_by (20260822120200) fires after that trigger and
--      stamps the frozen credit only `if new.status = 'pending'`. A row that
--      arrived as 'approved' would take the `elsif` branch instead and copy
--      OLD.submitted_by_name -- null, for a draft. The catalogue would credit
--      nobody, and songs_source_shape would be one step from refusing the row.
--   2. songs_audit_review (20260827130200) is an AFTER UPDATE trigger keyed on
--      the status changing to 'approved'. On the INSERT route there is no
--      UPDATE at all, so an auto-published song would never be audited -- the
--      exact "two copies of the gate, one of them missing" shape that
--      20260822120600 was written to fix.
--
-- So the row genuinely passes through 'pending' inside the transaction, and is
-- then moved on by a second statement. Everything already keyed to "became
-- pending" -- the gate, submitted_at, the frozen name -- fires once and
-- unchanged, and everything keyed to "became approved" -- reviewed_at,
-- reviewed_by, the audit row -- fires once and unchanged. Requirement stated
-- positively: the catalogue cannot tell an auto-published song from one a
-- moderator approved by hand, because the same code did both.
--
-- Recursion is not a risk: the promoting UPDATE sets status to 'approved', and
-- both triggers below are gated on the row becoming 'pending'.
create or replace function public.publish_own_submission()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.may_self_publish(new.owner_id) then
    return null;
  end if;

  -- security definer, so this runs as the function owner and is not filtered by
  -- RLS. songs_update_admin would permit it anyway for anybody who satisfies
  -- may_self_publish; not depending on that is the point, since the reason this
  -- may proceed should be the rule above rather than a policy elsewhere that
  -- happens to overlap with it.
  update public.songs
     set status = 'approved'
   where id = new.id;

  return null;
end;
$$;

-- Two triggers rather than one, because a WHEN clause cannot read tg_op and OLD
-- does not exist for an INSERT. The condition is copied verbatim from
-- songs_stamp_submitted_by's own `new.status = 'pending' and (tg_op = 'INSERT'
-- or old.status is distinct from 'pending')`, deliberately: "the transition INTO
-- pending" now has two definitions in this schema and they had better be the
-- same one.
--
-- Both routes matter and neither implies the other. A song reaches 'pending' by
-- being inserted there (the Share action) or by an owner submitting a draft they
-- saved earlier, including a rejected song revised and resubmitted.
-- 20260822120600 exists because the second route bypassed the first's gate;
-- this migration is not going to repeat that.
--
-- Named to sort after songs_audit_review, which is not an accident but is not
-- required either: on the draft -> pending statement the audit trigger sees a
-- status that is neither 'approved' nor 'rejected' and writes nothing, and the
-- audit row for the publication comes from the nested UPDATE below.
create trigger songs_publish_own_on_insert
  after insert on public.songs
  for each row
  when (new.status = 'pending')
  execute function public.publish_own_submission();

create trigger songs_publish_own_on_update
  after update on public.songs
  for each row
  when (new.status = 'pending' and old.status is distinct from 'pending')
  execute function public.publish_own_submission();

-- ---------------------------------------------------------------------------
-- Nothing is loosened, and this is where somebody will look to check
-- ---------------------------------------------------------------------------
-- songs_insert_own still refuses any insert whose status is not 'draft' or
-- 'pending', or that arrives carrying reviewed_by/reviewed_at. That is
-- unchanged and deliberately so: a client NEVER asks to be published, not even a
-- moderator's client. It asks for 'pending', exactly as before, and the server
-- decides what that means for the account behind the request. A moderator who
-- hand-writes status = 'approved' into the insert is refused by RLS with 42501
-- like anybody else.
--
-- enforce_song_status_transition is likewise untouched. A member reaching
-- 'approved' by any route still raises 'only an admin may set status to
-- approved', because may_self_publish is a strictly narrower condition than the
-- one that trigger already enforces -- everyone it admits could already have
-- approved the song by hand a moment later.

-- ---------------------------------------------------------------------------
-- The audit row, and why it gains a flag rather than an action
-- ---------------------------------------------------------------------------
-- Self-publication is a privileged action that is now self-granted, which makes
-- the permanent record more important rather than less: it is the one approval
-- with nobody's second opinion in it. 20260827130200's trigger already catches
-- it -- the promotion is an ordinary pending -> approved UPDATE -- so what is
-- missing is only that the row says so out loud.
--
-- It is inferable without this, from actor_id = target_user_id. That is exactly
-- the argument against leaving it inferable: "which approvals had no second pair
-- of eyes" is a question somebody will ask of this table one day, and answering
-- it should not require knowing that two columns holding the same uuid means
-- something.
--
-- A FLAG AND NOT A NEW ACTION VALUE. 'song_self_published' was the alternative
-- and it is worse: every existing reader of admin_audit that means "this song
-- was approved" would silently stop seeing a third of the approvals, and the
-- constraint would grow a value describing WHO rather than WHAT, which none of
-- the other six do. As a flag, 'song_approved' keeps meaning what it has always
-- meant and the subset is one `details->>'self_published'` away.
--
-- Repeated in full because `create or replace function` takes a whole body, not
-- a patch. Unchanged from 20260827130200 except the one jsonb key.
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
  if new.status = old.status then
    return null;
  end if;
  if new.status not in ('approved', 'rejected') then
    return null;
  end if;

  select display_name into name from public.profiles where id = actor;

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
      'reason', case
                  when new.status = 'rejected'
                    then left(btrim(coalesce(new.rejection_reason, '')), 500)
                  else null
                end,
      -- Null rather than false when it does not apply, so jsonb_strip_nulls
      -- drops the key entirely and an ordinary approval reads exactly as it did
      -- before this migration. Present-and-true is the whole signal.
      --
      -- Written from the actor and the owner rather than from a flag passed down
      -- by publish_own_submission, so it is also true of the other way this
      -- happens: a moderator opening the queue and approving a row that turns
      -- out to be their own. That is the same act with more steps, and a log
      -- that recorded only the automatic half would be misleading in the more
      -- suspicious direction.
      'self_published', case
                          when new.status = 'approved'
                               and actor is not null
                               and actor = old.owner_id
                            then true
                          else null
                        end
    ))
  );

  return null;
end;
$$;
