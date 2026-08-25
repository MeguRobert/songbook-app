-- The other way a song becomes 'pending', gated the same.
--
-- 20260822120500 gated the INSERT. A song can also arrive at 'pending' by an
-- owner submitting a draft they saved earlier -- draft -> pending, and from
-- rejected -> pending after a revision. Without this, every rule in
-- assert_may_submit is bypassed by saving first and submitting second, which is
-- the ordinary path through the Add-song screen rather than an exotic one.
--
-- Repeated in full because `create or replace function` takes a whole body, not
-- a patch. Unchanged from 20260822120300 except the four lines calling the gate.

create or replace function public.enforce_song_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  acting_admin boolean := public.is_admin();
begin
  -- Ownership is immutable, with one exception for the UPDATE that
  -- ON DELETE SET NULL performs. See 20260822120300 for the full reasoning.
  if new.owner_id is distinct from old.owner_id then
    if not (new.owner_id is null and auth.uid() is null) then
      raise exception 'song owner cannot be changed';
    end if;
  end if;

  if old.status = 'approved' and auth.uid() is not null and not acting_admin then
    raise exception 'only an admin may change an approved song';
  end if;

  if new.status <> old.status then
    if new.status in ('approved', 'rejected') and not acting_admin then
      raise exception
        'only an admin may set status to % (attempted by %)', new.status, auth.uid();
    end if;

    if not acting_admin then
      if not (
        (old.status = 'draft'    and new.status = 'pending') or
        (old.status = 'pending'  and new.status = 'draft')   or
        (old.status = 'rejected' and new.status in ('draft', 'pending'))
      ) then
        raise exception 'illegal status transition % -> %', old.status, new.status;
      end if;
    end if;

    if new.status = 'pending' then
      -- THE ADDITION. Placed before the submitted_at stamp so a refused
      -- submission leaves no trace of having been attempted, and after the
      -- transition whitelist so an illegal transition is reported as such rather
      -- than as a gate failure.
      if new.source = 'user' then
        perform public.assert_may_submit(new.owner_id);
      end if;

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
