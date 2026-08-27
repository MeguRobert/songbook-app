-- The settings_changed row that nothing wrote.
--
-- WHY THIS EXISTS. admin_audit (20260822120400) has listed 'settings_changed' in
-- its check constraint since the day it was written, and grep finds no writer
-- anywhere in this repository. So an administrator could close submissions, drop
-- the daily cap to zero, or rewrite the contribution guidelines in all three
-- languages, and leave NO trace of having done it -- while the schema's own
-- constraint made the category look covered. A constraint naming an action
-- nobody emits is worse than a missing category: it reads as a guarantee.
--
-- The same gap twice over: app_settings.updated_by has existed just as long, is
-- a foreign key to auth.users, and 20260826120000's own comment records that it
-- "is genuinely untouched and stays null". The table could say who last changed
-- the project's rules and did not.
--
-- WHY A TRIGGER AND NOT THE EDGE FUNCTION. The three actions that do get audited
-- -- role_changed, user_deleted, user_invited -- are written from
-- supabase/functions/admin-users/index.ts, because listing, inviting and deleting
-- accounts are impossible without the service-role key and so had to live there
-- anyway. Settings are different: they are an ordinary UPDATE governed by
-- app_settings_write_admin, and the client writes them directly. Auditing them
-- from an Edge Function would have meant inventing an action, routing the write
-- through it, and moving the settings write out from under the RLS policy that
-- currently guards it -- more surface, for a worse guarantee. Worse, because:
--
--   * A trigger runs INSIDE the transaction that changes the row. It cannot
--     record a change that was then rolled back, and it cannot miss one that
--     committed. An Edge Function writing two rows over two connections can do
--     both, and the failure is silent in both directions.
--   * A trigger catches EVERY writer. The Flutter app, a future admin screen, a
--     curl against PostgREST with an administrator's JWT, and the owner's own
--     hand-run UPDATE in the SQL editor are all audited by the same code. The
--     Edge Function version audits exactly one caller and quietly exempts the
--     rest -- including the one an administrator would reach for at 11pm.
--
-- WHAT THIS DOES NOT CHANGE. admin_audit still has no INSERT grant to any client
-- role. The function below is `security definer`, so it writes as its owner, and
-- an administrator still cannot insert, update or delete a row in the log about
-- themselves. That property is the reason the table is worth having and nothing
-- here weakens it.

-- ---------------------------------------------------------------------------
-- Who changed it
-- ---------------------------------------------------------------------------
-- BEFORE UPDATE, because a column of the row being written can only be set
-- before it is written. Deliberately not the client's to supply, for the same
-- reason error_reports.user_id and songs.reviewed_by are not: identity is the
-- server's to state. AppSettings.toUpdate() already declines to send it and says
-- so in a comment; this is the half of that sentence that was missing.
--
-- Nulls out rather than preserves when there is no auth.uid() -- a service-role
-- job or a psql session as the owner. "Changed by nobody I can name" is the
-- truth in that case, and a stale previous administrator's id would be a lie.
create or replace function public.stamp_app_settings_actor()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  new.updated_by := auth.uid();
  return new;
end;
$$;

-- Fires before app_settings_touch_updated_at only because 's' sorts before 't',
-- and nothing depends on that: the two touch different columns.
create trigger app_settings_stamp_actor
  before update on public.app_settings
  for each row execute function public.stamp_app_settings_actor();

-- ---------------------------------------------------------------------------
-- What changed
-- ---------------------------------------------------------------------------
-- AFTER UPDATE, so the row exists before it is described. A BEFORE trigger could
-- have done both jobs in one function and would have been able to log a change a
-- later trigger then refused.
--
-- ONE ROW PER REAL CHANGE. The settings screen sends all six columns on every
-- save, so `update ... set everything` with nothing actually edited is the normal
-- shape of a no-op -- somebody opening the screen and pressing Save. Auditing
-- that would fill the log with rows that record nothing, and a log with noise in
-- it stops being read. Hence the `is distinct from` per column and the early
-- return when the set is empty.
--
-- WHAT IS RECORDED, AND WHAT IS NOT. The booleans and the cap are small and their
-- values are the whole point, so they go in as from/to. The guidelines are
-- paragraphs in three languages, and they go in as LENGTHS ONLY. That is a real
-- decision and not a size dodge: an audit trail answers "who did this, and when",
-- and version history answers "what did it say before". Putting the old text
-- here would make admin_audit a document store that also happens to be
-- append-only and unreadable in a table view -- and would duplicate, permanently
-- and unprunably, text that has a home in app_settings already.
create or replace function public.audit_app_settings_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  changed text[] := '{}';
  facts   jsonb  := '{}'::jsonb;
  actor   uuid   := auth.uid();
  name    text;
begin
  if old.submissions_open is distinct from new.submissions_open then
    changed := array_append(changed, 'submissions_open');
    facts := facts || jsonb_build_object('submissions_open',
      jsonb_build_object('from', old.submissions_open,
                         'to',   new.submissions_open));
  end if;

  if old.require_confirmed_email is distinct from new.require_confirmed_email then
    changed := array_append(changed, 'require_confirmed_email');
    facts := facts || jsonb_build_object('require_confirmed_email',
      jsonb_build_object('from', old.require_confirmed_email,
                         'to',   new.require_confirmed_email));
  end if;

  if old.daily_submission_cap is distinct from new.daily_submission_cap then
    changed := array_append(changed, 'daily_submission_cap');
    facts := facts || jsonb_build_object('daily_submission_cap',
      jsonb_build_object('from', old.daily_submission_cap,
                         'to',   new.daily_submission_cap));
  end if;

  if old.guidelines_en is distinct from new.guidelines_en then
    changed := array_append(changed, 'guidelines_en');
    facts := facts || jsonb_build_object('guidelines_en',
      jsonb_build_object('from_length', length(coalesce(old.guidelines_en, '')),
                         'to_length',   length(coalesce(new.guidelines_en, ''))));
  end if;

  if old.guidelines_hu is distinct from new.guidelines_hu then
    changed := array_append(changed, 'guidelines_hu');
    facts := facts || jsonb_build_object('guidelines_hu',
      jsonb_build_object('from_length', length(coalesce(old.guidelines_hu, '')),
                         'to_length',   length(coalesce(new.guidelines_hu, ''))));
  end if;

  if old.guidelines_ro is distinct from new.guidelines_ro then
    changed := array_append(changed, 'guidelines_ro');
    facts := facts || jsonb_build_object('guidelines_ro',
      jsonb_build_object('from_length', length(coalesce(old.guidelines_ro, '')),
                         'to_length',   length(coalesce(new.guidelines_ro, ''))));
  end if;

  -- Nothing actually moved. `array_length` of an empty array is null, not 0.
  if array_length(changed, 1) is null then
    return null;
  end if;

  -- Frozen at write time, same reasoning as admin_audit.actor_name itself: an
  -- administrator who later leaves, or who renames themselves, must not change
  -- what the log says they did. Null for a service-role or owner session, where
  -- there is no profile to read and nothing to freeze.
  select display_name into name from public.profiles where id = actor;

  -- target_user_id and target_email stay null, and the columns are nullable for
  -- exactly this: the target of a settings change is the project, not a person.
  insert into public.admin_audit
    (actor_id, actor_name, action, target_user_id, target_email, details)
  values
    (actor, name, 'settings_changed', null, null,
     facts || jsonb_build_object('changed', to_jsonb(changed)));

  -- The return value of an AFTER ROW trigger is ignored.
  return null;
end;
$$;

create trigger app_settings_audit_change
  after update on public.app_settings
  for each row execute function public.audit_app_settings_change();

-- No REVOKE on either function, and it is worth saying why rather than leaving
-- the omission to look like one. A trigger function called directly raises
-- "trigger functions can only be called as triggers" before it does anything at
-- all, so there is no privilege here worth withdrawing -- unlike
-- prune_error_reports(), which is an ordinary callable function and is revoked.
-- Trigger firing does not re-check EXECUTE either way; the check happens once,
-- at CREATE TRIGGER.
