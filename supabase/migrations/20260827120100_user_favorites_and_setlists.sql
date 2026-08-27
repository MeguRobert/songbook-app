-- A person's favourites and setlists, so they follow the account between devices.
--
-- Design record: docs/plans/2026-08-27-cross-device-sync-design.md. The two
-- things to know before reading:
--
--   * The DEVICE is the source of truth, not this. Songbook works signed-out and
--     offline as a hard requirement, so SharedPreferences is the floor and these
--     tables are the shared copy layered over it -- exactly the relationship the
--     bundled hymnal has with public.songs.
--   * A DELETION IS A ROW. `removed = true` with a timestamp, not an absent row.
--     Absence is indistinguishable from "this device has not heard of it yet", so
--     a merge that reads absence as removal cannot un-favourite anything, and a
--     merge that reads it as ignorance re-favourites everything you removed.
--     Rows are hard-deleted only by the auth.users cascade, with the account.
--
-- GRANT AND RLS ARE INDEPENDENT LAYERS AND BOTH ARE REQUIRED -- the point
-- 20260728120100 makes at length, and the reason the grants below are explicit:
--   GRANT without RLS  -> the role reads everyone's favourites. This is the leak.
--   RLS without GRANT  -> "permission denied for table user_favorites".
-- Since 20260728120200 changed the schema's default privileges, a new table here
-- is granted nothing implicitly, in the cloud as well as locally. That is what
-- makes forgetting this section fail loudly instead of quietly.

-- ---------------------------------------------------------------------------
-- user_favorites
-- ---------------------------------------------------------------------------
-- song_id is TEXT and deliberately not a foreign key to public.songs. What a
-- favourite names is a SongId -- `hymnal:151` -- which is the app's identity for
-- a song and not a row id in that table: the bundled hymnal exists in the asset
-- whether or not the server carries a copy. A foreign key here would make
-- favouriting song 151 depend on the catalogue having been seeded.
--
-- The client sends only `hymnal:` ids. A `user:` id names a song that lives on
-- one device only, so the row would be invisible everywhere else and would
-- resurrect on the device that deleted the song. That rule is the client's to
-- keep; nothing here enforces it, because a future device-to-device story for
-- user songs would make it wrong.
create table public.user_favorites (
  user_id    uuid not null references auth.users (id) on delete cascade,
  song_id    text not null check (length(btrim(song_id)) > 0),

  -- The merge timestamp, and the only column the client's merge reads. It is
  -- EVENT time -- when the person tapped the heart -- not write time, because a
  -- change made offline on Tuesday and pushed on Friday should not beat one made
  -- on Thursday. Clamped forward-only by the trigger below.
  changed_at timestamptz not null default now(),

  sort_order integer not null default 0,
  removed    boolean not null default false,

  -- Server clock, maintained here and never read by the merge. For answering
  -- "when did this device last actually reach us", which changed_at cannot.
  updated_at timestamptz not null default now(),

  primary key (user_id, song_id)
);

-- ---------------------------------------------------------------------------
-- user_setlists
-- ---------------------------------------------------------------------------
-- One row per setlist, and the whole setlist in it. This is what makes the merge
-- last-write-wins over the record: name and order travel together, so no sync
-- can produce a list with one device's name and the other's songs, which is a
-- list neither device ever had.
--
-- id is the client's own `sl_<microseconds>_<random>` and is unique per user
-- rather than globally, so two accounts cannot collide and one account's two
-- devices cannot either.
--
-- song_ids carries `user:` ids verbatim, unlike favourites: dropping members out
-- of an ordered list corrupts the list, and a device that cannot resolve an id
-- already skips it when rendering.
create table public.user_setlists (
  user_id    uuid not null references auth.users (id) on delete cascade,
  id         text not null check (length(btrim(id)) > 0),

  -- Not constrained to be non-empty: a tombstone for a setlist created on
  -- another device may carry no name at all, and refusing it would mean a
  -- deletion that cannot be recorded.
  name       text not null default '',
  song_ids   text[] not null default '{}',

  created_at timestamptz not null default now(),
  changed_at timestamptz not null default now(),
  removed    boolean not null default false,
  updated_at timestamptz not null default now(),

  primary key (user_id, id)
);

-- ---------------------------------------------------------------------------
-- Timestamps
-- ---------------------------------------------------------------------------
-- Two jobs in one trigger:
--
--   updated_at := now()                    server clock, as touch_updated_at does
--   changed_at := least(changed_at, now()) clamp a client clock set to the future
--
-- The clamp is forward-only on purpose. A client that believes it is 2030 would
-- otherwise win every merge against every other device for the next four years,
-- and nothing the user does could correct it. A client that is merely slow still
-- loses arguments it should win -- that is the residual cost of using event time,
-- recorded in the design record rather than hidden here.
create or replace function public.stamp_user_data_row()
returns trigger
language plpgsql
as $$
begin
  new.changed_at := least(coalesce(new.changed_at, now()), now());
  new.updated_at := now();
  return new;
end;
$$;

create trigger user_favorites_stamp
  before insert or update on public.user_favorites
  for each row execute function public.stamp_user_data_row();

create trigger user_setlists_stamp
  before insert or update on public.user_setlists
  for each row execute function public.stamp_user_data_row();

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------
-- NOTHING to anon, and that is not an oversight: there is no such thing as a
-- signed-out person's row here. Their favourites live on their device, which is
-- how signed-out use stays fully functional without an account existing at all.
--
-- NOTHING to service_role either. No Edge Function reads these, and the
-- admin-users function's scope discipline (20260822120700) is the standard to
-- keep: grant what a caller actually does, when it starts doing it.
revoke all on public.user_favorites from anon, authenticated;
revoke all on public.user_setlists  from anon, authenticated;

grant select, insert, update, delete on public.user_favorites to authenticated;
grant select, insert, update, delete on public.user_setlists  to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
-- Your rows and no one else's, in all four directions.
--
-- NOTE WHAT IS ABSENT: is_admin(). public.songs gives administrators a bypass
-- because moderating a shared catalogue requires seeing unapproved submissions.
-- Nothing about moderating a hymnal requires reading what someone has
-- favourited, so a moderator here is an ordinary user with ordinary rows. The
-- absence is the policy.
alter table public.user_favorites enable row level security;
alter table public.user_setlists  enable row level security;

create policy user_favorites_select_own on public.user_favorites
  for select to authenticated
  using (user_id = auth.uid());

-- with check, not using: an INSERT has no existing row to test. Without this a
-- signed-in user could write rows onto someone else's account -- which the
-- select policy would then hide from them, so they would never find out.
create policy user_favorites_insert_own on public.user_favorites
  for insert to authenticated
  with check (user_id = auth.uid());

-- Both clauses. `using` decides which rows may be touched, `with check` that the
-- result is still yours -- otherwise an update could re-parent a row to another
-- account.
create policy user_favorites_update_own on public.user_favorites
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Ordinary deletion is still permitted even though the client tombstones
-- instead: an account clearing its synced data outright is a legitimate thing to
-- want, and withholding DELETE would leave no way to do it.
create policy user_favorites_delete_own on public.user_favorites
  for delete to authenticated
  using (user_id = auth.uid());

create policy user_setlists_select_own on public.user_setlists
  for select to authenticated
  using (user_id = auth.uid());

create policy user_setlists_insert_own on public.user_setlists
  for insert to authenticated
  with check (user_id = auth.uid());

create policy user_setlists_update_own on public.user_setlists
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy user_setlists_delete_own on public.user_setlists
  for delete to authenticated
  using (user_id = auth.uid());
