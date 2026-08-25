-- An approved song outlives the account that submitted it.
--
-- Same principle as 20260820190000: an approved song belongs to the catalogue,
-- not to the contributor. Deleting a member must not take hymns off the shelf.
-- So the account goes, the song stays, and the frozen submitted_by_name from
-- 20260822120200 is what keeps it attributable afterwards.
--
-- THREE COUPLED CHANGES. Each one alone leaves the feature broken:
--   1. the foreign key, or the songs are cascaded away with the account
--   2. the shape constraint, or the resulting orphan violates it
--   3. the trigger guard, which has two separate problems with nulls
--
-- Change 2 also REMOVES a protection by accident, and change 3 has to put it
-- back: today `source = 'user' and owner_id is not null` is the only thing
-- stopping a moderator writing owner_id = null and stripping a song of its
-- attribution, because songs_update_admin's WITH CHECK is merely is_admin().
-- Relaxing the constraint without tightening the guard would open that.

-- ---------------------------------------------------------------------------
-- 1. The foreign key
-- ---------------------------------------------------------------------------
alter table public.songs drop constraint songs_owner_id_fkey;

alter table public.songs add constraint songs_owner_id_fkey
  foreign key (owner_id) references auth.users (id) on delete set null;

-- ---------------------------------------------------------------------------
-- 2. The shape constraint
-- ---------------------------------------------------------------------------
-- A user song may now be ownerless, but only if it was once owned -- which is
-- exactly what a non-null submitted_by_name attests, since that column is
-- stamped only on submission and is frozen thereafter. So the constraint stays
-- meaningful: an ownerless, nameless user song is still nonsense, and still
-- refused.
alter table public.songs drop constraint songs_source_shape;

alter table public.songs add constraint songs_source_shape check (
  (source = 'hymnal' and owner_id is null and number is not null and status = 'approved')
  or
  (source = 'user' and (owner_id is not null or submitted_by_name is not null))
);

-- ---------------------------------------------------------------------------
-- 3. The trigger guard
-- ---------------------------------------------------------------------------
-- Repeated in full because `create or replace function` takes a whole body, not
-- a patch. Unchanged from 20260820190000 except the ownership guard at the top.
create or replace function public.enforce_song_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  acting_admin boolean := public.is_admin();
begin
  -- Ownership is immutable, with exactly one permitted exception.
  --
  -- `<>` used to be enough. It is not, now that owner_id can be null: NULL <>
  -- anything is NULL, which is not true, so the guard would silently stop firing
  -- on precisely the cases this migration introduces. IS DISTINCT FROM fixes
  -- that half.
  --
  -- The other half: ON DELETE SET NULL performs an UPDATE on this table, so the
  -- FK action trips the guard and account deletion fails outright. The exception
  -- below is the exact shape that action produces -- owner going to null, with no
  -- signed-in caller -- which follows the `auth.uid() is not null` convention
  -- already established in 20260820190000 for server-side work.
  --
  -- Scoping it to `auth.uid() is null` rather than to "owner became null" is
  -- deliberate and is the protection restored from the shape constraint above:
  -- orphaning is confined to a service-role context, so the admin-users Edge
  -- Function may do it and a signed-in moderator may not. Adoption -- null going
  -- to a uuid -- is refused in every context, or deleting an account would be a
  -- way to launder its submissions into a different one.
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
