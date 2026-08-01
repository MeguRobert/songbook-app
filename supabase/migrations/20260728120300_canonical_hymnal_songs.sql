-- Make the catalogue able to hold the bundled hymnal, not just user submissions.
--
-- The original songs table assumed every row was somebody's submission:
-- owner_id was NOT NULL and referenced auth.users. The 8 songs in
-- songbook_app/assets/data/songs.json have no owner and never will -- they are
-- canonical hymnal content. Seeding them was therefore impossible.
--
-- This also brings the table in line with the app's identity model. SongId is
-- `source:ref` (see songbook_app/lib/data/models/song_id.dart): 'hymnal:151' for
-- bundled songs, 'user:<token>' for local ones. `source` is added here so a row
-- can be turned back into the right SongId, and `ref` needs no column:
--   source = 'hymnal'  ->  ref is number::text
--   source = 'user'    ->  ref is id::text (the uuid)

create type public.song_source as enum ('hymnal', 'user');

-- Default 'user': every row that existed before this migration was a submission.
alter table public.songs
  add column source public.song_source not null default 'user';

-- Canonical songs have no owner.
alter table public.songs
  alter column owner_id drop not null;

-- The two shapes are mutually exclusive and each has its own invariants.
alter table public.songs add constraint songs_source_shape check (
  (source = 'hymnal' and owner_id is null and number is not null and status = 'approved')
  or
  (source = 'user' and owner_id is not null)
);

-- ---------------------------------------------------------------------------
-- Policy consequences
-- ---------------------------------------------------------------------------
-- SELECT needs no change: hymnal rows are 'approved', so the existing
-- "status = 'approved' or owner_id = auth.uid() or is_admin()" already exposes
-- them to everyone including anon.
--
-- The owner-scoped write policies also need no change, and pleasingly so: they
-- test `owner_id = auth.uid()`, and for a hymnal row owner_id is NULL, so the
-- comparison evaluates to NULL rather than true. A NULL is not a pass, so
-- ownerless canonical rows are automatically unwritable by any non-admin. That
-- falls out of SQL's three-valued logic rather than needing a rule.
--
-- INSERT does need tightening: without this, a signed-in user could insert a row
-- claiming source = 'hymnal'. The shape constraint would force owner_id to be
-- null, which the existing policy's `owner_id = auth.uid()` would then reject --
-- but relying on two constraints colliding is not a control, it is a coincidence.
-- Say it explicitly.
drop policy songs_insert_own on public.songs;

create policy songs_insert_own on public.songs
  for insert
  to authenticated
  with check (
    source = 'user'
    and owner_id = auth.uid()
    and status in ('draft', 'pending')
    and reviewed_by is null
    and reviewed_at is null
  );

-- ---------------------------------------------------------------------------
-- Source is immutable for non-admins
-- ---------------------------------------------------------------------------
-- Otherwise a contributor could promote their own submission to canonical
-- hymnal content, which is a back door to the same place self-approval led.
create or replace function public.enforce_song_source_immutable()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.source <> old.source and not public.is_admin() then
    raise exception 'only an admin may change a song''s source';
  end if;
  return new;
end;
$$;

create trigger songs_enforce_source_immutable
  before update on public.songs
  for each row execute function public.enforce_song_source_immutable();

-- Canonical rows are looked up by hymnal number constantly (setlists,
-- favourites, the router), so index that path directly.
create index songs_hymnal_number_idx
  on public.songs (number)
  where source = 'hymnal';
