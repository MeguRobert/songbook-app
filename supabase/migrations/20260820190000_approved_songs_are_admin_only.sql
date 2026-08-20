-- An approved song belongs to the catalogue, not to the account that submitted it.
--
-- The hole this closes: songs_update_own let an owner UPDATE their own row with
-- no condition on status, and enforce_song_status_transition() kept its
-- approved-row guard *inside* `if new.status <> old.status`. A content-only
-- UPDATE -- new title, new number, new payload -- therefore satisfied the
-- policy, met none of the checks in the trigger, and republished to the whole
-- congregation with no review. Approval gated the transition into 'approved'
-- and then stopped gating anything at all.
--
-- The DELETE policy already had this right: songs_delete_own_undecided permits
-- 'draft' and 'pending' only, because "once approved it is part of the shared
-- catalogue". UPDATE now mirrors it. That asymmetry is why this is a fix and
-- not a change of mind -- the intent was already written down, one policy over.
--
-- Consequence, and it is deliberate: an owner who spots a typo in an approved
-- song asks a moderator. The alternative -- demote to 'pending' on any edit and
-- re-review -- would unpublish the song, because public read is
-- `status = 'approved'`. Taking a hymn off the shelf on the Saturday before it
-- is sung, in order to fix a typo, is worse than the typo.

-- ---------------------------------------------------------------------------
-- The policy
-- ---------------------------------------------------------------------------
drop policy songs_update_own on public.songs;

create policy songs_update_own on public.songs
  for update
  to authenticated
  using (
    owner_id = auth.uid()
    and status in ('draft', 'pending', 'rejected')
  )
  with check (
    owner_id = auth.uid()
    and status in ('draft', 'pending', 'rejected')
  );

-- ---------------------------------------------------------------------------
-- The trigger, with the approved-row guard hoisted out of the status branch
-- ---------------------------------------------------------------------------
-- Unchanged from 20260728120100 except for that hoist. Repeated in full because
-- migrations are append-only and `create or replace function` takes a whole
-- body, not a patch.
create or replace function public.enforce_song_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  acting_admin boolean := public.is_admin();
begin
  -- Ownership is immutable. Re-parenting a song would let someone launder a
  -- submission through another account.
  if new.owner_id <> old.owner_id then
    raise exception 'song owner cannot be changed';
  end if;

  -- THE HOIST. This check used to live inside the status-change branch below,
  -- where a content-only UPDATE never reached it.
  --
  -- `auth.uid() is not null` scopes it to a real signed-in caller, so
  -- server-side repair of approved content -- a later migration, a service_role
  -- job -- is still possible. The policy above is what stops an ordinary user
  -- from ever arriving here; this is the second lock, for the day somebody
  -- edits that policy.
  if old.status = 'approved' and auth.uid() is not null and not acting_admin then
    raise exception 'only an admin may change an approved song';
  end if;

  if new.status <> old.status then
    -- Only admins may reach a decided state, or leave one.
    if new.status in ('approved', 'rejected') and not acting_admin then
      raise exception
        'only an admin may set status to % (attempted by %)', new.status, auth.uid();
    end if;

    -- Owner-side transitions, whitelisted.
    if not acting_admin then
      if not (
        (old.status = 'draft'    and new.status = 'pending') or
        (old.status = 'pending'  and new.status = 'draft')   or
        (old.status = 'rejected' and new.status in ('draft', 'pending'))
      ) then
        raise exception 'illegal status transition % -> %', old.status, new.status;
      end if;
    end if;

    -- Bookkeeping, set server-side so a client cannot forge it.
    if new.status = 'pending' then
      new.submitted_at := now();
    end if;

    if new.status in ('approved', 'rejected') then
      new.reviewed_at := now();
      new.reviewed_by := auth.uid();
    else
      new.reviewed_at := null;
      new.reviewed_by := null;
    end if;
  end if;

  if new.status = 'rejected' then
    if new.rejection_reason is null or length(btrim(new.rejection_reason)) = 0 then
      raise exception 'a rejected song requires a rejection_reason';
    end if;
  else
    new.rejection_reason := null;
  end if;

  return new;
end;
$$;
