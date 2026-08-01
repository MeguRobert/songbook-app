-- Songbook platform: catalogue, submissions and roles.
--
-- Design decision worth knowing before reading: the song payload is stored as
-- `jsonb`, NOT normalised into note/measure/verse tables. The Dart models in
-- songbook_app/lib/data/models/ (Song, SongNotation, Verse, ChordPosition) are
-- the schema of record; they already have versioned upgrade paths and the app
-- reads MusicXML into them natively. Normalising here would mean two schemas to
-- migrate in lockstep, and Postgres would win arguments it should not be having
-- about musical structure.
--
-- Columns are promoted out of the payload only when RLS or a query needs them:
-- owner_id and status (policy), title/number/book/tags (browse and filter),
-- search (lyric search). Everything else stays in `payload`.

create extension if not exists pg_trgm;

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
-- The old Songbook app put `isAdmin` in a client-readable `users/{email}`
-- document, which put the trust boundary in the wrong place. Here the table is
-- readable ONLY through is_admin(), which is `security definer` and therefore
-- runs as the function owner, bypassing RLS on the table it reads. No client
-- can enumerate admins, and no client can grant itself the role: there is
-- deliberately no INSERT/UPDATE policy on user_roles at all, so writes are
-- possible only from the service-role key (server side) or the SQL editor.

create table public.user_roles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role    text not null check (role in ('admin', 'moderator')),
  granted_at timestamptz not null default now()
);

alter table public.user_roles enable row level security;
-- No policies: RLS with zero policies denies everything to anon/authenticated.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid()
      and role in ('admin', 'moderator')
  );
$$;

-- ---------------------------------------------------------------------------
-- Profiles
-- ---------------------------------------------------------------------------
-- Display identity for attribution ("submitted by"). Deliberately separate
-- from user_roles: this one IS world-readable, roles are not.

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy profiles_read_all on public.profiles
  for select using (true);

create policy profiles_write_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

create policy profiles_insert_own on public.profiles
  for insert with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- Songs
-- ---------------------------------------------------------------------------
-- `status` is a four-state machine plus a rejection reason, not a boolean --
-- a boolean cannot distinguish "not submitted yet" from "rejected", and gives
-- the contributor no way to know why.

create type public.song_status as enum ('draft', 'pending', 'approved', 'rejected');

create table public.songs (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references auth.users (id) on delete cascade,

  status      public.song_status not null default 'draft',
  -- Enforced by the trigger in the next migration: non-null only when rejected.
  rejection_reason text,

  -- Promoted for querying. `number` is nullable: it is the hymnal number, and a
  -- user submission has none until an admin assigns one.
  number      integer,
  title       text not null check (length(btrim(title)) > 0),
  book        text,
  tags        text[] not null default '{}',

  -- The whole Song object as the Dart model serialises it, minus the fields
  -- promoted above. `Song.fromJson` consumes this after the repository merges
  -- the promoted columns back in.
  payload     jsonb not null,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  submitted_at timestamptz,
  reviewed_at  timestamptz,
  reviewed_by  uuid references auth.users (id) on delete set null
);

-- Lyric search. VERIFIED against supabase/postgres:17.6.1.156 on 2026-07-28:
-- 'hungarian' is present in pg_ts_config, and the stemmer genuinely works --
-- searching 'patak' matches the stored 'patakra', and 'bíztunk' indexes as
-- 'bízt'. That was the open question behind choosing Postgres over Firestore.
--
-- Every function here MUST be IMMUTABLE, because this is a generated column.
-- Checked via pg_proc.provolatile:
--   to_tsvector(regconfig, text)  i   <- 2-arg form with a literal config
--   jsonb_path_query_array        i
--   array_to_tsvector             i
--   tsvector_concat (||)          i
--   array_to_string               s   <- STABLE. Using it here fails with
--                                        "generation expression is not
--                                        immutable" (SQLSTATE 42P17).
-- Hence array_to_tsvector(tags) rather than to_tsvector(array_to_string(...)).
--
-- The jsonb is queried by PATH rather than whole. to_tsvector('hungarian',
-- payload) would index every string in the document -- including note pitches
-- ("C4"), durations ("quarter") and the key ("Bb") -- which is pure noise and
-- index bloat. Targeting the two keys that actually hold words was verified to
-- index lyrics and syllables while excluding pitches and durations entirely.
--   $.**.text      verse lines (Verse -> LyricLine.text)
--   $.**.syllable  lyrics carried on notation beats
alter table public.songs
  add column search tsvector
  generated always as (
    to_tsvector('hungarian', coalesce(title, '')) ||
    array_to_tsvector(tags) ||
    to_tsvector('hungarian',
      coalesce(jsonb_path_query_array(payload, '$.**.text')::text, '')) ||
    to_tsvector('hungarian',
      coalesce(jsonb_path_query_array(payload, '$.**.syllable')::text, ''))
  ) stored;

create index songs_search_idx   on public.songs using gin (search);
create index songs_status_idx   on public.songs (status);
create index songs_owner_idx    on public.songs (owner_id);
create index songs_number_idx   on public.songs (number) where number is not null;
create index songs_title_trgm   on public.songs using gin (title gin_trgm_ops);

-- Approved songs may not collide on hymnal number within a book. Scoped to
-- approved only, so competing submissions can coexist while pending.
create unique index songs_approved_number_unique
  on public.songs (book, number)
  where status = 'approved' and number is not null;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger songs_touch_updated_at
  before update on public.songs
  for each row execute function public.touch_updated_at();
