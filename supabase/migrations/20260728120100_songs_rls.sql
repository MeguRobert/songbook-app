-- Row-level security for public.songs, plus the status state machine.
--
-- READ THIS FIRST -- why there are two mechanisms and not one:
--
-- RLS decides which ROWS a statement may touch. It cannot express "the owner
-- may edit their song but may not set status = 'approved'", because a policy
-- has no way to compare OLD to NEW: an UPDATE policy's `using` clause sees the
-- existing row and `with check` sees the proposed row, but neither sees both.
-- So a policy can say "owner may update own row" and it can say "the result
-- must still be owned by them", and it still cannot stop them writing
-- status = 'approved' into it.
--
-- Therefore: RLS for visibility and ownership, a BEFORE UPDATE trigger for
-- legal state transitions. Neither is sufficient alone, and the trigger is the
-- half that actually prevents self-approval -- the specific failure the old
-- Songbook app shipped.

alter table public.songs enable row level security;

-- ---------------------------------------------------------------------------
-- GRANTs -- the other half of access control, and easy to forget
-- ---------------------------------------------------------------------------
-- RLS and GRANT are independent layers, and BOTH are required:
--   GRANT without RLS  -> the role can read every row. This is the leak.
--   RLS without GRANT  -> "permission denied for table songs", nothing works.
-- A table created in a migration gets no grants implicitly, so they are here.
--
-- Note what is deliberately absent: user_roles gets NO grant of any kind. That
-- is stronger than its zero-policy RLS -- anon and authenticated cannot even
-- attempt to read it. Admin status is reachable only through is_admin(), which
-- is security definer and therefore reads the table as its owner.

grant select                         on public.songs    to anon, authenticated;
grant insert, update, delete         on public.songs    to authenticated;

grant select                         on public.profiles to anon, authenticated;
grant insert, update                 on public.profiles to authenticated;

grant execute on function public.is_admin() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- SELECT
-- ---------------------------------------------------------------------------
-- Approved songs are readable by everyone, including signed-out visitors --
-- "signed-out must stay fully functional" is a hard requirement, and a public
-- hymnal has nothing to hide in its approved catalogue. Unapproved rows are
-- visible only to their owner and to admins.
--
-- Note the contrast with Firestore, which drove the platform choice: this
-- FILTERS. `select * from songs` returns only permitted rows, so forgetting a
-- client-side status filter under-fetches instead of erroring, and cannot leak.
create policy songs_select on public.songs
  for select
  using (
    status = 'approved'
    or owner_id = auth.uid()
    or public.is_admin()
  );

-- ---------------------------------------------------------------------------
-- INSERT
-- ---------------------------------------------------------------------------
-- You may only create rows you own, and only in a pre-review state. This stops
-- the crudest self-approval: inserting a row that is already 'approved'.
create policy songs_insert_own on public.songs
  for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and status in ('draft', 'pending')
    and reviewed_by is null
    and reviewed_at is null
  );

-- ---------------------------------------------------------------------------
-- UPDATE
-- ---------------------------------------------------------------------------
-- Owner: may edit their own row, and the row must still be theirs afterwards.
-- Which status transitions are legal is the trigger's job, not this policy's.
create policy songs_update_own on public.songs
  for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Admin: may update any row (this is how review happens).
create policy songs_update_admin on public.songs
  for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- DELETE
-- ---------------------------------------------------------------------------
-- Owners may withdraw a submission before it is decided. Once approved it is
-- part of the shared catalogue and only an admin may remove it.
create policy songs_delete_own_undecided on public.songs
  for delete
  to authenticated
  using (owner_id = auth.uid() and status in ('draft', 'pending'));

create policy songs_delete_admin on public.songs
  for delete
  to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- The state machine
-- ---------------------------------------------------------------------------
-- Legal transitions:
--   draft     -> pending                 (owner submits)
--   pending   -> draft                   (owner withdraws to keep editing)
--   pending   -> approved | rejected     (ADMIN ONLY)
--   rejected  -> draft | pending         (owner revises and resubmits)
--   approved  -> anything                (ADMIN ONLY)
--
-- rejection_reason is required for a rejection and cleared on any other state,
-- so a stale reason can never linger on an approved song.

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

  if new.status <> old.status then
    -- Only admins may reach a decided state, or leave one.
    if new.status in ('approved', 'rejected') and not acting_admin then
      raise exception
        'only an admin may set status to % (attempted by %)', new.status, auth.uid();
    end if;

    if old.status = 'approved' and not acting_admin then
      raise exception 'only an admin may change an approved song';
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

create trigger songs_enforce_status_transition
  before update on public.songs
  for each row execute function public.enforce_song_status_transition();

-- Insert-side counterpart: stamp submitted_at when a song is created already
-- pending, and apply the same rejection_reason rule.
create or replace function public.enforce_song_insert()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'pending' then
    new.submitted_at := coalesce(new.submitted_at, now());
  end if;
  if new.status <> 'rejected' then
    new.rejection_reason := null;
  end if;
  return new;
end;
$$;

create trigger songs_enforce_insert
  before insert on public.songs
  for each row execute function public.enforce_song_insert();
