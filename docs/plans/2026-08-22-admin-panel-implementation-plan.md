# Admin Panel, Role Ladder and Publish Gate — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give the Administrator full CRUD over accounts and over the settings that
govern contribution, split Moderator from Administrator, require a named account
before a song reaches the shared catalogue, and show who submitted and who
approved every song.

**Architecture:** Database first. Every rule is enforced in Postgres — a role
lookup table with numeric ranks, RLS policies that test rank, and triggers that
gate submission — and proven with pgTAP before any screen exists. Account
listing, creation and deletion are impossible with the anon key by design, so
they go through one Edge Function holding the service-role key which re-checks
the caller's rank server-side. The Flutter layer asks; it never authorises.

**Tech Stack:** Postgres 17 / Supabase (RLS, pgTAP, Deno Edge Functions),
Flutter + Riverpod + GoRouter, `flutter_gen_l10n` with three ARB files.

**Design document:** `docs/plans/2026-08-22-admin-panel-and-roles-design.md`

---

## Before you start

**Read these first. This schema is unusually opinionated and the comments carry
the reasoning:**

- `supabase/migrations/20260728120100_songs_rls.sql` — why there is both RLS and
  a trigger, and which half prevents self-approval.
- `supabase/migrations/20260728120200_explicit_privileges.sql` — why privileges
  are revoked then granted back, and why `user_roles` is granted nothing.
- `supabase/migrations/20260820190000_approved_songs_are_admin_only.sql` — the
  principle that an approved song belongs to the catalogue, and the
  `auth.uid() is not null` escape hatch for server-side work.
- `supabase/tests/songs_rls_test.sql` — the impersonation idiom. Note the comment
  about `set local role postgres` before each switch; copy it exactly or your
  tests will fail in a way that looks like a policy bug.

**Environment:**

```bash
# Docker must be running for anything in Tasks 1-8.
npx supabase start
npx supabase db reset          # replays every migration from scratch
npx supabase test db           # runs everything in supabase/tests/
```

```bash
cd songbook_app
flutter test
flutter analyze
```

**Do not run `npx supabase db push`.** That targets the live project, which has
real accounts in it. Migrations are verified locally with `db reset`; pushing is
the project owner's explicit decision, taken once at the end.

**Ordering note — Tasks 3 and 4 are swapped** relative to the order agreed in the
design conversation. The shape constraint in Task 4 references
`submitted_by_name`, so the column has to exist first. Nothing else moved.

---

## Task 1: The role ladder

**Files:**
- Create: `supabase/migrations/20260822120000_role_ladder.sql`
- Create: `supabase/tests/roles_test.sql`

**Why a table and not an enum:** adding a tier later must be an `INSERT`, not a
migration that rewrites a constraint and re-examines every policy naming it. The
Contributor tier is explicitly a later decision, so this has to be cheap.

**Step 1: Write the failing test**

Create `supabase/tests/roles_test.sql`:

```sql
-- The role ladder is ranked, and the two predicates split on rank.
--
-- Impersonation idiom copied from songs_rls_test.sql: `set local role postgres`
-- before each switch, because `authenticated` cannot switch itself back.
begin;
select plan(9);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'member@example.test', '', now(), now()),
  ('a0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'mod@example.test', '', now(), now()),
  ('a0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'admin@example.test', '', now(), now());

update public.user_roles set role = 'moderator'
  where user_id = 'a0000000-0000-0000-0000-000000000002';
update public.user_roles set role = 'administrator'
  where user_id = 'a0000000-0000-0000-0000-000000000003';

-- The ladder itself
select is(
  (select rank from public.roles where name = 'member'), 10::smallint,
  'member sits at rank 10');
select ok(
  (select rank from public.roles where name = 'moderator')
    < (select rank from public.roles where name = 'administrator'),
  'moderator ranks below administrator');

-- A member
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is(public.can_moderate(), false, 'a member may not moderate');
select is(public.is_administrator(), false, 'a member is not an administrator');
select throws_ok(
  'select 1 from public.user_roles',
  '42501',
  null,
  'a member cannot read user_roles at all');

-- A moderator
set local role postgres;
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is(public.can_moderate(), true, 'a moderator may moderate');
select is(public.is_administrator(), false, 'a moderator is NOT an administrator');
select is(public.is_admin(), true,
  'is_admin() is an alias for can_moderate(), so existing policies are unchanged');

-- An administrator
set local role postgres;
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000003', true);
select set_config('request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is(public.is_administrator(), true, 'an administrator is an administrator');

set local role postgres;
select * from finish();
rollback;
```

Note this test already assumes Task 2's auto-provisioning (it `update`s a role row
it never inserted). That is deliberate — the two tasks land together and the test
proves both.

**Step 2: Run it to verify it fails**

```bash
npx supabase db reset && npx supabase test db
```

Expected: FAIL — `relation "public.roles" does not exist`.

**Step 3: Write the migration**

Create `supabase/migrations/20260822120000_role_ladder.sql`:

```sql
-- Roles become a ranked lookup table, and Moderator stops meaning Administrator.
--
-- WHY THIS EXISTS. `user_roles.role` was `check (role in ('admin','moderator'))`
-- and `is_admin()` returned true for both, so the two roles had identical
-- powers everywhere they were used. Splitting them needs a comparison, and a
-- comparison needs an order.
--
-- WHY A TABLE AND NOT AN ENUM. A tier has to be addable later without touching
-- a single policy. With ranks, `role_rank(uid) >= 50` keeps meaning "may
-- moderate" no matter how many tiers exist below it, so a future
-- ('contributor', 30) is one INSERT. A `check` constraint or a Postgres enum
-- would each require a migration plus a re-read of every policy that named a
-- role, which is exactly the audit this design is trying not to owe.

create table public.roles (
  name text primary key,
  rank smallint not null unique check (rank > 0)
);

-- Gaps between ranks are intentional: a tier can be inserted between two
-- existing ones without renumbering anything.
insert into public.roles (name, rank) values
  ('member', 10),
  ('moderator', 50),
  ('administrator', 90);

-- The ladder is public knowledge -- it is in this file, in a public repo. Who
-- holds which role is not, and that stays in user_roles, which is granted
-- nothing. Reading this table lets the admin UI populate a role picker without
-- hardcoding the list in Dart.
alter table public.roles enable row level security;
create policy roles_read_all on public.roles for select using (true);
revoke all on public.roles from anon, authenticated;
grant select on public.roles to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Migrate user_roles onto it
-- ---------------------------------------------------------------------------
-- The check constraint is dropped by discovered name rather than by the
-- assumed default, so this does not break if it was ever named by hand.
do $$
declare
  constraint_name text;
begin
  select conname into constraint_name
  from pg_constraint
  where conrelid = 'public.user_roles'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%role%';
  if constraint_name is not null then
    execute format('alter table public.user_roles drop constraint %I', constraint_name);
  end if;
end $$;

update public.user_roles set role = 'administrator' where role = 'admin';

alter table public.user_roles
  add constraint user_roles_role_fkey
  foreign key (role) references public.roles (name);

-- ---------------------------------------------------------------------------
-- The predicates
-- ---------------------------------------------------------------------------
-- All `security definer`, because user_roles grants nothing to any client role
-- and these have to read it as the function owner. All `stable`, so Postgres
-- may call them once per statement rather than once per row in a policy.

create or replace function public.role_rank(uid uuid)
returns smallint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select r.rank
       from public.user_roles ur
       join public.roles r on r.name = ur.role
      where ur.user_id = uid),
    0)::smallint;
$$;

create or replace function public.can_moderate()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.role_rank(auth.uid())
       >= (select rank from public.roles where name = 'moderator');
$$;

create or replace function public.is_administrator()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.role_rank(auth.uid())
       >= (select rank from public.roles where name = 'administrator');
$$;

-- is_admin() becomes an alias, and that is the point.
--
-- Six policies and two triggers call it: songs_select, songs_update_admin,
-- songs_delete_admin, enforce_song_status_transition,
-- enforce_song_source_immutable, and the hymnal policies in ..120300.
-- Rewriting all of them to name can_moderate() would reopen the RLS surface
-- that ..120200 and ..190000 were written to close, for no behavioural gain --
-- "may moderate" is exactly what every one of those call sites meant.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.can_moderate();
$$;

grant execute on function public.role_rank(uuid)     to anon, authenticated;
grant execute on function public.can_moderate()      to anon, authenticated;
grant execute on function public.is_administrator()  to anon, authenticated;
```

**Step 4: Run the tests**

```bash
npx supabase db reset && npx supabase test db
```

Expected: `roles_test.sql .. ok` (9 assertions) **and**
`songs_rls_test.sql .. ok` (26 assertions, unchanged). If the songs suite broke,
the `is_admin()` alias is wrong — fix that rather than editing the songs test.

**Step 5: Commit**

```bash
git add supabase/migrations/20260822120000_role_ladder.sql supabase/tests/roles_test.sql
git commit -m "feat: rank the roles so moderator stops meaning administrator"
```

---

## Task 2: Every account gets a role row

**Files:**
- Create: `supabase/migrations/20260822120100_provision_new_accounts.sql`
- Modify: `supabase/tests/roles_test.sql` (add 3 assertions, `plan(12)`)

**Why:** a Member has to be a record, not the absence of one. That is what makes
the admin user list complete, and what lets a future tier sit *below* Moderator
without a "no row" special case.

**Step 1: Write the failing test**

Append to `supabase/tests/roles_test.sql`, before `finish()`:

```sql
set local role postgres;

-- A brand new account is provisioned automatically.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values ('a0000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'fresh@example.test', '', now(), now());

select is(
  (select role from public.user_roles where user_id = 'a0000000-0000-0000-0000-000000000004'),
  'member',
  'a new account starts as a member');
select isnt_empty(
  $$select 1 from public.profiles where id = 'a0000000-0000-0000-0000-000000000004'$$,
  'a new account gets a profile row');
select is(
  (select role from public.user_roles where user_id = 'a0000000-0000-0000-0000-000000000003'),
  'administrator',
  'provisioning does not demote an account that already had a role');
```

Bump `select plan(9)` to `select plan(12)`.

**Step 2: Run it to verify it fails**

```bash
npx supabase db reset && npx supabase test db
```

Expected: FAIL — the `user_roles` row for `...0004` is null.

**Step 3: Write the migration**

Create `supabase/migrations/20260822120100_provision_new_accounts.sql`:

```sql
-- Every account gets a profile and a member role, on creation and in arrears.
--
-- `on conflict do nothing` on both inserts is what makes the backfill safe to
-- run over a database that already has an administrator in it: the existing row
-- wins. Getting this wrong would demote the only administrator to member and
-- lock the project owner out of the panel this feature is adding.

create or replace function public.provision_new_account()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id) values (new.id)
    on conflict (id) do nothing;
  insert into public.user_roles (user_id, role) values (new.id, 'member')
    on conflict (user_id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.provision_new_account();

-- Backfill. Order matters only in that both are idempotent.
insert into public.profiles (id)
  select id from auth.users on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
  select id, 'member' from auth.users on conflict (user_id) do nothing;
```

**Step 4: Run the tests**

```bash
npx supabase db reset && npx supabase test db
```

Expected: `roles_test.sql .. ok` (12 assertions).

**Step 5: Commit**

```bash
git add supabase/migrations/20260822120100_provision_new_accounts.sql supabase/tests/roles_test.sql
git commit -m "feat: provision a profile and a member role for every account"
```

---

## Task 3: Frozen attribution

**Files:**
- Create: `supabase/migrations/20260822120200_frozen_attribution.sql`
- Create: `supabase/tests/attribution_test.sql`

**Why frozen and not a join:** `profiles.display_name` is user-editable and the
account can be deleted. An audit trail read live from `profiles` is one the
audited party can rewrite after the fact.

**Step 1: Write the failing test**

Create `supabase/tests/attribution_test.sql`:

```sql
-- The submitter's name is stamped at submission and cannot be edited afterwards.
begin;
select plan(4);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values ('b0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'clara@example.test', '', now(), now());

update public.profiles set display_name = 'Clara K.'
  where id = 'b0000000-0000-0000-0000-000000000001';

insert into public.songs (id, owner_id, status, title, payload) values (
  'bbbbbbbb-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000001',
  'pending',
  'Erős vár a mi Istenünk',
  '{"originalKey":"C","verses":[]}'::jsonb);

select is(
  (select submitted_by_name from public.songs
    where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'Clara K.',
  'the display name is stamped when the song is submitted');

-- Renaming yourself does not rewrite history.
update public.profiles set display_name = 'Someone Else'
  where id = 'b0000000-0000-0000-0000-000000000001';
select is(
  (select submitted_by_name from public.songs
    where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'Clara K.',
  'renaming the account does not rewrite the stamped name');

-- Nor does editing the song.
update public.songs set submitted_by_name = 'Definitely Not Clara'
  where id = 'bbbbbbbb-0000-0000-0000-000000000001';
select is(
  (select submitted_by_name from public.songs
    where id = 'bbbbbbbb-0000-0000-0000-000000000001'),
  'Clara K.',
  'the stamped name cannot be overwritten by an update');

-- A draft has nothing to attribute yet.
insert into public.songs (id, owner_id, status, title, payload) values (
  'bbbbbbbb-0000-0000-0000-000000000002',
  'b0000000-0000-0000-0000-000000000001',
  'draft',
  'Still working on it',
  '{"originalKey":"C","verses":[]}'::jsonb);
select is(
  (select submitted_by_name from public.songs
    where id = 'bbbbbbbb-0000-0000-0000-000000000002'),
  null,
  'a draft carries no submitter name');

select * from finish();
rollback;
```

**Step 2: Run it to verify it fails**

```bash
npx supabase db reset && npx supabase test db
```

Expected: FAIL — `column "submitted_by_name" does not exist`.

**Step 3: Write the migration**

Create `supabase/migrations/20260822120200_frozen_attribution.sql`:

```sql
-- Who submitted this, recorded so it cannot be edited by the person it names.
--
-- A join to profiles.display_name would have been less to write and worth
-- nothing: display_name is under the contributor's own control and the account
-- can be deleted outright. This column is a copy taken at the moment of
-- submission, and it is also what keeps an orphaned song readable after its
-- owner's account is gone (see the next migration).

alter table public.songs add column submitted_by_name text;

-- Backfill from whatever is currently known, for songs already submitted.
update public.songs s
   set submitted_by_name = p.display_name
  from public.profiles p
 where p.id = s.owner_id
   and s.submitted_at is not null
   and s.submitted_by_name is null;

create or replace function public.stamp_submitted_by()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Stamp on the transition INTO pending, from either an insert or an update.
  if new.status = 'pending'
     and (tg_op = 'INSERT' or old.status is distinct from 'pending') then
    new.submitted_by_name :=
      (select display_name from public.profiles where id = new.owner_id);
  elsif tg_op = 'UPDATE' then
    -- Frozen. A client sending its own value has it discarded rather than
    -- rejected, because the value is not the client's to supply at all.
    new.submitted_by_name := old.submitted_by_name;
  end if;
  return new;
end;
$$;

-- Fires AFTER the existing status-transition triggers, alphabetically:
-- `songs_enforce_status_transition` < `songs_stamp_submitted_by`. Postgres runs
-- same-timing triggers in name order, so the status is already settled and
-- validated by the time this reads it.
create trigger songs_stamp_submitted_by
  before insert or update on public.songs
  for each row execute function public.stamp_submitted_by();
```

**Step 4: Run the tests**

```bash
npx supabase db reset && npx supabase test db
```

Expected: `attribution_test.sql .. ok` (4 assertions), everything else unchanged.

**Step 5: Commit**

```bash
git add supabase/migrations/20260822120200_frozen_attribution.sql supabase/tests/attribution_test.sql
git commit -m "feat: stamp the submitter's name so attribution cannot be rewritten"
```

---

## Task 4: Deleting an account keeps its songs

**Files:**
- Create: `supabase/migrations/20260822120300_orphan_songs_on_account_delete.sql`
- Create: `supabase/tests/account_delete_test.sql`

**Read this before writing a line.** Three changes are coupled and skipping any
one produces a silent bug:

1. `songs.owner_id` is `on delete cascade` — deleting an account currently
   deletes its approved songs out of the shared catalogue.
2. `songs_source_shape` asserts `source = 'user' and owner_id is not null`, which
   *forbids* the orphan the FK would create.
3. `enforce_song_status_transition` guards ownership with
   `new.owner_id <> old.owner_id`. With nulls that yields `NULL`, which is not
   `true`, so **the guard silently stops firing.**

And a fourth thing, which is the real trap: `ON DELETE SET NULL` performs an
**UPDATE** on `songs`, so it fires that same `BEFORE UPDATE` trigger. A naive
`IS DISTINCT FROM` guard therefore makes account deletion fail outright with
"song owner cannot be changed". The guard has to permit exactly the shape the FK
action produces — `uuid → null`, with no signed-in caller — and nothing else.

**Step 1: Write the failing test**

Create `supabase/tests/account_delete_test.sql`:

```sql
-- Deleting an account leaves the catalogue intact and the audit trail readable.
begin;
select plan(6);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'leaving@example.test', '', now(), now()),
  ('c0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'staying@example.test', '', now(), now());

update public.profiles set display_name = 'Departed Member'
  where id = 'c0000000-0000-0000-0000-000000000001';

insert into public.songs (id, owner_id, status, title, payload) values (
  'cccccccc-0000-0000-0000-000000000001',
  'c0000000-0000-0000-0000-000000000001',
  'pending',
  'Jövel Szentlélek Úristen',
  '{"originalKey":"F","verses":[]}'::jsonb);

update public.songs set status = 'approved'
  where id = 'cccccccc-0000-0000-0000-000000000001';

-- The act itself must not error. Before the trigger fix, this raised.
select lives_ok(
  $$delete from auth.users where id = 'c0000000-0000-0000-0000-000000000001'$$,
  'deleting an account succeeds');

select isnt_empty(
  $$select 1 from public.songs where id = 'cccccccc-0000-0000-0000-000000000001'$$,
  'the approved song survives its submitter');

select is(
  (select owner_id from public.songs
    where id = 'cccccccc-0000-0000-0000-000000000001'),
  null,
  'the song is orphaned rather than deleted');

select is(
  (select submitted_by_name from public.songs
    where id = 'cccccccc-0000-0000-0000-000000000001'),
  'Departed Member',
  'the frozen name is still readable after the account is gone');

-- An orphan cannot be adopted: otherwise deleting an account would be a way to
-- launder its submissions into a different one.
select throws_ok(
  $$update public.songs
       set owner_id = 'c0000000-0000-0000-0000-000000000002'
     where id = 'cccccccc-0000-0000-0000-000000000001'$$,
  'song owner cannot be changed',
  'an orphaned song cannot be re-adopted');

select is(
  (select count(*) from public.user_roles
    where user_id = 'c0000000-0000-0000-0000-000000000001'),
  0::bigint,
  'the role row goes with the account');

select * from finish();
rollback;
```

**Step 2: Run it to verify it fails**

```bash
npx supabase db reset && npx supabase test db
```

Expected: FAIL on assertion 2 — the song was cascaded away.

**Step 3: Write the migration**

Create `supabase/migrations/20260822120300_orphan_songs_on_account_delete.sql`:

```sql
-- An approved song outlives the account that submitted it.
--
-- Same principle as ..190000: an approved song belongs to the catalogue, not to
-- the contributor. Deleting a member must not take hymns off the shelf. So the
-- account goes, the song stays, and the frozen submitted_by_name from ..120200
-- is what keeps it attributable.
--
-- THREE COUPLED CHANGES. Each one alone is broken:
--   1. the FK, or the songs are cascaded away
--   2. the shape constraint, or the resulting orphan violates it
--   3. the trigger guard, or (a) it stops firing on nulls and (b) it rejects
--      the very UPDATE that ON DELETE SET NULL performs

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
-- exactly what a non-null submitted_by_name attests. That keeps the constraint
-- meaningful: an ownerless, nameless user song is still nonsense and still
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
-- Repeated in full because `create or replace function` takes a whole body.
-- Unchanged from ..190000 except the ownership guard at the top.
create or replace function public.enforce_song_status_transition()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  acting_admin boolean := public.is_admin();
begin
  -- Ownership is immutable, with one permitted exception.
  --
  -- `<>` used to be enough. It is not, now that owner_id can be null: NULL <>
  -- anything is NULL, which is not true, so the guard would silently stop
  -- firing and an orphan could be adopted. IS DISTINCT FROM fixes that.
  --
  -- But ON DELETE SET NULL performs an UPDATE on this table, so the FK action
  -- itself trips the guard and account deletion fails. The exception below is
  -- exactly the shape that action produces -- owner going to null, with no
  -- signed-in caller, matching the `auth.uid() is not null` convention already
  -- established in ..190000 for server-side work. Any other change of owner,
  -- including null -> uuid, is still refused.
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
```

**Step 4: Run the tests**

```bash
npx supabase db reset && npx supabase test db
```

Expected: `account_delete_test.sql .. ok` (6 assertions), and all three earlier
suites still green.

**Step 5: Commit**

```bash
git add supabase/migrations/20260822120300_orphan_songs_on_account_delete.sql supabase/tests/account_delete_test.sql
git commit -m "feat: keep a departed member's songs in the catalogue"
```

---

## Task 5: The audit log

**Files:**
- Create: `supabase/migrations/20260822120400_admin_audit.sql`
- Create: `supabase/tests/admin_audit_test.sql`

**Step 1: Write the failing test**

Create `supabase/tests/admin_audit_test.sql`:

```sql
-- The audit log is append-only from a client's point of view, and admin-read.
begin;
select plan(4);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, created_at, updated_at)
values
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'member@example.test', '', now(), now()),
  ('d0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'boss@example.test', '', now(), now());

update public.user_roles set role = 'administrator'
  where user_id = 'd0000000-0000-0000-0000-000000000002';

insert into public.admin_audit (actor_id, actor_name, action, target_user_id, target_email, details)
values ('d0000000-0000-0000-0000-000000000002', 'The Boss', 'role_changed',
        'd0000000-0000-0000-0000-000000000001', 'member@example.test',
        '{"from":"member","to":"moderator"}'::jsonb);

-- A member sees nothing.
select set_config('request.jwt.claim.sub', 'd0000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims',
  '{"sub":"d0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is_empty(
  'select 1 from public.admin_audit',
  'a member sees no audit entries');
select throws_ok(
  $$insert into public.admin_audit (action) values ('role_changed')$$,
  '42501',
  null,
  'a member cannot write an audit entry');

-- An administrator reads, and still cannot write.
set local role postgres;
select set_config('request.jwt.claim.sub', 'd0000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims',
  '{"sub":"d0000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is(
  (select count(*) from public.admin_audit), 1::bigint,
  'an administrator reads the audit log');
select throws_ok(
  $$insert into public.admin_audit (action) values ('role_changed')$$,
  '42501',
  null,
  'not even an administrator writes it from a client -- only the Edge Function does');

set local role postgres;
select * from finish();
rollback;
```

**Step 2: Run it to verify it fails**

Expected: FAIL — `relation "public.admin_audit" does not exist`.

**Step 3: Write the migration**

Create `supabase/migrations/20260822120400_admin_audit.sql`:

```sql
-- What an administrator did to somebody's account, and when.
--
-- Written only by the admin-users Edge Function, using the service-role key.
-- No client role gets INSERT, UPDATE or DELETE -- not even an administrator's,
-- because a log its own subject can edit is not a log.

create table public.admin_audit (
  id             bigint generated always as identity primary key,

  -- `on delete set null`: an administrator who later leaves must not erase the
  -- record of what they did. actor_name is the frozen copy, same reasoning as
  -- songs.submitted_by_name.
  actor_id       uuid references auth.users (id) on delete set null,
  actor_name     text,

  action         text not null check (action in
                   ('role_changed', 'user_deleted', 'user_invited', 'settings_changed')),

  -- DELIBERATELY NOT A FOREIGN KEY. The commonest entry here records a deleted
  -- account; an FK would either cascade the evidence away or block the delete.
  target_user_id uuid,
  target_email   text,

  details        jsonb not null default '{}'::jsonb,
  at             timestamptz not null default now()
);

create index admin_audit_at_idx on public.admin_audit (at desc);

alter table public.admin_audit enable row level security;

revoke all on public.admin_audit from anon, authenticated;
grant select on public.admin_audit to authenticated;

create policy admin_audit_read_admin on public.admin_audit
  for select to authenticated using (public.is_administrator());
```

**Step 4: Run the tests, Step 5: Commit**

```bash
npx supabase db reset && npx supabase test db
git add supabase/migrations/20260822120400_admin_audit.sql supabase/tests/admin_audit_test.sql
git commit -m "feat: record account changes in an append-only audit log"
```

---

## Task 6: App settings and the server-side submission gate

**Files:**
- Create: `supabase/migrations/20260822120500_app_settings_and_submission_gate.sql`
- Create: `supabase/tests/submission_gate_test.sql`

**Why the error messages are codes:** the Dart layer has to turn each refusal into
a Hungarian sentence. `AuthRepository._classify` already establishes the pattern —
map a stable machine-readable identifier to a localised message, never show the
server's prose. These exceptions therefore raise bare snake_case tokens.

**Step 1: Write the failing test**

Create `supabase/tests/submission_gate_test.sql`:

```sql
-- Submitting is gated in the database, not merely in the UI.
begin;
select plan(7);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values
  ('e0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'ok@example.test', '', now(), now(), now()),
  ('e0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000',
   'authenticated', 'authenticated', 'unconfirmed@example.test', '', null, now(), now());

update public.profiles set display_name = 'Ready', guidelines_accepted_at = now()
  where id = 'e0000000-0000-0000-0000-000000000001';
update public.profiles set display_name = 'Not Verified', guidelines_accepted_at = now()
  where id = 'e0000000-0000-0000-0000-000000000002';

-- Baseline: the settings row exists and submissions are open.
select is((select count(*) from public.app_settings), 1::bigint,
  'there is exactly one settings row');

select lives_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000001', 'pending', 'A valid submission',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'a confirmed member who accepted the guidelines may submit');

-- Unconfirmed email
select throws_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000002', 'pending', 'Unverified',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'email_not_confirmed', 'an unconfirmed address cannot submit');

-- Guidelines not accepted
update public.profiles set guidelines_accepted_at = null
  where id = 'e0000000-0000-0000-0000-000000000001';
select throws_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000001', 'pending', 'No guidelines',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'guidelines_not_accepted', 'the guidelines must be accepted first');
update public.profiles set guidelines_accepted_at = now()
  where id = 'e0000000-0000-0000-0000-000000000001';

-- Submissions closed
update public.app_settings set submissions_open = false where id = 1;
select throws_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000001', 'pending', 'Door shut',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'submissions_closed', 'the master switch closes the door');
update public.app_settings set submissions_open = true where id = 1;

-- A draft is never gated: saving privately is not submitting.
select lives_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000001', 'draft', 'Private draft',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'a draft is not gated');

-- Daily cap. One submission already exists above, so a cap of 1 blocks the next.
update public.app_settings set daily_submission_cap = 1 where id = 1;
select throws_ok($$
  insert into public.songs (owner_id, status, title, payload)
  values ('e0000000-0000-0000-0000-000000000001', 'pending', 'One too many',
          '{"originalKey":"C","verses":[]}'::jsonb)
$$, 'daily_limit_reached', 'the daily cap is enforced');

select * from finish();
rollback;
```

**Step 2: Run it to verify it fails**

Expected: FAIL — `relation "public.app_settings" does not exist`.

**Step 3: Write the migration**

Create `supabase/migrations/20260822120500_app_settings_and_submission_gate.sql`:

```sql
-- Settings that govern contribution, and the gate that enforces them.
--
-- The whole point of this feature: nothing reaches the shared songbook without
-- a named, verified account that has read the rules. Every one of those
-- conditions is checked HERE, in the database, because a check in the Flutter
-- app is a message rather than a gate.

-- ---------------------------------------------------------------------------
-- app_settings: one row, world-readable, administrator-writable
-- ---------------------------------------------------------------------------
-- One row enforced by `check (id = 1)`. A key/value table would have been more
-- flexible and would have cost a type per read; these are a fixed, small set of
-- knobs with different types, so columns are the honest shape.
create table public.app_settings (
  id                       smallint primary key default 1 check (id = 1),

  submissions_open         boolean  not null default true,
  require_confirmed_email  boolean  not null default true,
  -- 0 means "no submissions at all", which submissions_open already says more
  -- clearly; it is permitted rather than special-cased.
  daily_submission_cap     smallint not null default 5 check (daily_submission_cap >= 0),

  guidelines_en            text not null default '',
  guidelines_hu            text not null default '',
  guidelines_ro            text not null default '',

  updated_at               timestamptz not null default now(),
  updated_by               uuid references auth.users (id) on delete set null
);

-- Seed text, so the gate has something to show before an administrator ever
-- opens the settings screen. Written to be replaced.
insert into public.app_settings (id, guidelines_en, guidelines_hu, guidelines_ro) values (
  1,
  'Submit only songs that are actually sung in worship. Type the words and chords carefully — someone will sing from this. Do not submit jokes, tests, or songs you have no right to share.',
  'Csak olyan énekeket küldj be, amelyeket valóban énekelünk az istentiszteleten. A szöveget és az akkordokat gondosan írd le — valaki ebből fog énekelni. Ne küldj be tréfát, próbát, vagy olyan éneket, amelynek megosztására nincs jogod.',
  'Trimite doar cântări care se cântă cu adevărat la închinare. Scrie versurile și acordurile cu atenție — cineva va cânta din ele. Nu trimite glume, teste sau cântări pe care nu ai dreptul să le distribui.'
);

alter table public.app_settings enable row level security;

-- Readable by everyone including anon: a signed-out visitor has to be able to
-- read the guidelines and see whether the door is open before signing in.
revoke all on public.app_settings from anon, authenticated;
grant select on public.app_settings to anon, authenticated;
grant update on public.app_settings to authenticated;

create policy app_settings_read_all on public.app_settings
  for select using (true);

create policy app_settings_write_admin on public.app_settings
  for update to authenticated
  using (public.is_administrator())
  with check (public.is_administrator());

create trigger app_settings_touch_updated_at
  before update on public.app_settings
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Accepting the guidelines
-- ---------------------------------------------------------------------------
-- On profiles, which the owner may already update. Acceptance is a
-- self-assertion, so self-service is the correct trust level.
alter table public.profiles add column guidelines_accepted_at timestamptz;

-- ---------------------------------------------------------------------------
-- The gate, in one place
-- ---------------------------------------------------------------------------
-- Called from both the insert trigger and the status-transition trigger,
-- because a song can become 'pending' either way and a gate with two copies is
-- a gate with one hole.
--
-- Raises bare snake_case tokens rather than sentences. The Dart layer maps them
-- to localised messages, exactly as AuthRepository._classify already does for
-- GoTrue codes -- server prose in three languages is not a thing that works.
create or replace function public.assert_may_submit(submitter uuid)
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  settings public.app_settings;
  confirmed_at timestamptz;
  accepted_at timestamptz;
  submitter_name text;
  today_count integer;
begin
  -- Moderators and above are exempt: they are the people the gate exists to
  -- protect, and a moderator entering a song is already a reviewed act.
  if public.can_moderate() then
    return;
  end if;

  select * into settings from public.app_settings where id = 1;

  if not settings.submissions_open then
    raise exception 'submissions_closed';
  end if;

  if settings.require_confirmed_email then
    select email_confirmed_at into confirmed_at from auth.users where id = submitter;
    if confirmed_at is null then
      raise exception 'email_not_confirmed';
    end if;
  end if;

  select guidelines_accepted_at, coalesce(display_name, '')
    into accepted_at, submitter_name
    from public.profiles where id = submitter;

  if accepted_at is null then
    raise exception 'guidelines_not_accepted';
  end if;

  -- A missing display name would force attribution back onto an email address,
  -- publishing it. Refused here as well as prompted for in the UI.
  if submitter_name = '' then
    raise exception 'display_name_required';
  end if;

  select count(*) into today_count
    from public.songs
   where owner_id = submitter
     and submitted_at >= date_trunc('day', now());

  if today_count >= settings.daily_submission_cap then
    raise exception 'daily_limit_reached';
  end if;
end;
$$;

-- Insert side. Now `security definer` because it reads auth.users through
-- assert_may_submit.
create or replace function public.enforce_song_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status = 'pending' and new.source = 'user' then
    perform public.assert_may_submit(new.owner_id);
    new.submitted_at := coalesce(new.submitted_at, now());
  end if;
  if new.status <> 'rejected' then
    new.rejection_reason := null;
  end if;
  return new;
end;
$$;
```

Then extend the status-transition trigger to call the same gate. Add this inside
`if new.status <> old.status then`, immediately before the `submitted_at` stamp,
and repeat the function body in a second migration file
`20260822120600_gate_the_draft_to_pending_transition.sql` (append-only
migrations; `create or replace function` needs the whole body):

```sql
    if new.status = 'pending' and new.source = 'user' then
      perform public.assert_may_submit(new.owner_id);
    end if;
```

**Step 4: Run the tests**

```bash
npx supabase db reset && npx supabase test db
```

Expected: `submission_gate_test.sql .. ok` (7 assertions). Add one more test in
the second migration's step proving `update songs set status = 'pending'` on a
draft is gated identically — the hole this closes.

**Step 5: Commit**

```bash
git add supabase/migrations/20260822120500_app_settings_and_submission_gate.sql \
        supabase/migrations/20260822120600_gate_the_draft_to_pending_transition.sql \
        supabase/tests/submission_gate_test.sql
git commit -m "feat: gate submission on settings, verification and the guidelines"
```

---

## Task 7: Full-suite checkpoint

**Step 1:** `npx supabase db reset && npx supabase test db`

Expected: five suites green — `songs_rls_test` (26), `roles_test` (12),
`attribution_test` (4), `account_delete_test` (6), `admin_audit_test` (4),
`submission_gate_test` (8).

**Step 2:** Confirm the pre-existing suite is genuinely untouched:

```bash
git diff master --stat -- supabase/tests/songs_rls_test.sql
```

Expected: **no output.** If `songs_rls_test.sql` had to change, a policy changed
meaning and that needs explaining before the UI is built on it.

**Step 3:** Commit nothing; this is a gate, not a change.

---

## Task 8: The admin-users Edge Function

**Files:**
- Create: `supabase/functions/admin-users/index.ts`
- Create: `supabase/functions/admin-users/deno.json`
- Create: `supabase/functions/_shared/cors.ts`

**Why this exists at all:** listing `auth.users`, inviting an account and deleting
one are impossible with the publishable key, on purpose. This is the only place
in the project that holds the service-role key, and the only place an email
address is visible.

**The two refusals are not optional.** Each is one tap away from locking the
project owner out of the panel:
- you cannot change your own role or delete your own account
- the last remaining administrator cannot be removed or demoted

**Step 1: Write the function**

`supabase/functions/admin-users/index.ts`:

```ts
// Account administration, behind a server-side rank check.
//
// The service-role key bypasses RLS entirely, so the ONLY thing standing
// between a caller and every account in the project is the is_administrator()
// check below. It runs as the CALLER, using their JWT, before any privileged
// client is constructed. Never reorder that.
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

type Action =
  | { action: 'list' }
  | { action: 'invite'; email: string; role?: string }
  | { action: 'set_role'; userId: string; role: string }
  | { action: 'delete'; userId: string }

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return json({ error: 'unauthenticated' }, 401)

  // Step 1: who is calling, and may they? As the caller, with the anon key.
  const asCaller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })

  const { data: caller } = await asCaller.auth.getUser()
  if (!caller?.user) return json({ error: 'unauthenticated' }, 401)

  const { data: allowed } = await asCaller.rpc('is_administrator')
  if (allowed !== true) return json({ error: 'forbidden' }, 403)

  const callerId = caller.user.id
  const { data: callerProfile } = await asCaller
    .from('profiles').select('display_name').eq('id', callerId).single()
  const callerName = callerProfile?.display_name ?? caller.user.email ?? null

  // Step 2: only now, a privileged client.
  const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  let body: Action
  try {
    body = await req.json()
  } catch {
    return json({ error: 'bad_request' }, 400)
  }

  const audit = (
    action: string,
    targetUserId: string | null,
    targetEmail: string | null,
    details: Record<string, unknown>,
  ) => admin.from('admin_audit').insert({
    actor_id: callerId,
    actor_name: callerName,
    action,
    target_user_id: targetUserId,
    target_email: targetEmail,
    details,
  })

  // How many administrators are left. Used to refuse the last one's removal.
  const administratorCount = async () => {
    const { count } = await admin
      .from('user_roles')
      .select('user_id', { count: 'exact', head: true })
      .eq('role', 'administrator')
    return count ?? 0
  }

  switch (body.action) {
    case 'list': {
      const { data: list, error } = await admin.auth.admin.listUsers({ perPage: 1000 })
      if (error) return json({ error: error.message }, 500)

      const [{ data: roles }, { data: profiles }, { data: counts }] = await Promise.all([
        admin.from('user_roles').select('user_id, role'),
        admin.from('profiles').select('id, display_name, guidelines_accepted_at'),
        admin.from('songs').select('owner_id, status').eq('source', 'user'),
      ])

      const roleBy = new Map((roles ?? []).map((r) => [r.user_id, r.role]))
      const profileBy = new Map((profiles ?? []).map((p) => [p.id, p]))
      const tally = new Map<string, Record<string, number>>()
      for (const song of counts ?? []) {
        if (!song.owner_id) continue
        const t = tally.get(song.owner_id) ?? { approved: 0, pending: 0, rejected: 0 }
        if (song.status in t) t[song.status]++
        tally.set(song.owner_id, t)
      }

      return json({
        users: list.users.map((u) => ({
          id: u.id,
          email: u.email,
          emailConfirmed: u.email_confirmed_at != null,
          createdAt: u.created_at,
          lastSignInAt: u.last_sign_in_at,
          role: roleBy.get(u.id) ?? 'member',
          displayName: profileBy.get(u.id)?.display_name ?? null,
          guidelinesAcceptedAt: profileBy.get(u.id)?.guidelines_accepted_at ?? null,
          songs: tally.get(u.id) ?? { approved: 0, pending: 0, rejected: 0 },
        })),
      })
    }

    case 'invite': {
      const { data, error } = await admin.auth.admin.inviteUserByEmail(body.email)
      if (error) return json({ error: error.message }, 400)
      if (body.role && body.role !== 'member') {
        await admin.from('user_roles')
          .upsert({ user_id: data.user.id, role: body.role })
      }
      await audit('user_invited', data.user.id, body.email, { role: body.role ?? 'member' })
      return json({ ok: true, userId: data.user.id })
    }

    case 'set_role': {
      if (body.userId === callerId) {
        return json({ error: 'cannot_change_own_role' }, 400)
      }
      const { data: existing } = await admin
        .from('user_roles').select('role').eq('user_id', body.userId).single()
      if (existing?.role === 'administrator' && body.role !== 'administrator') {
        if ((await administratorCount()) <= 1) {
          return json({ error: 'last_administrator' }, 400)
        }
      }
      const { error } = await admin.from('user_roles')
        .upsert({ user_id: body.userId, role: body.role })
      if (error) return json({ error: error.message }, 400)
      await audit('role_changed', body.userId, null,
        { from: existing?.role ?? 'member', to: body.role })
      return json({ ok: true })
    }

    case 'delete': {
      if (body.userId === callerId) {
        return json({ error: 'cannot_delete_self' }, 400)
      }
      const { data: existing } = await admin
        .from('user_roles').select('role').eq('user_id', body.userId).single()
      if (existing?.role === 'administrator' && (await administratorCount()) <= 1) {
        return json({ error: 'last_administrator' }, 400)
      }
      // Audit BEFORE the delete: afterwards there is no email to record.
      const { data: target } = await admin.auth.admin.getUserById(body.userId)
      await audit('user_deleted', body.userId, target?.user?.email ?? null,
        { role: existing?.role ?? 'member' })
      const { error } = await admin.auth.admin.deleteUser(body.userId)
      if (error) return json({ error: error.message }, 400)
      return json({ ok: true })
    }

    default:
      return json({ error: 'unknown_action' }, 400)
  }
})
```

`supabase/functions/_shared/cors.ts`:

```ts
// The app is served from GitHub Pages, so browser calls are cross-origin.
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
```

**Step 2: Serve it locally and prove the rank check**

```bash
npx supabase functions serve admin-users
```

In another shell, with no token — expected `401`:

```bash
curl -s -X POST http://127.0.0.1:54321/functions/v1/admin-users \
  -H 'Content-Type: application/json' -d '{"action":"list"}'
```

Then repeat with a **member's** access token — expected `403 forbidden` — and
with an **administrator's** — expected a `users` array. Getting a member's token
locally: sign up through `npx supabase start`'s Studio, then use the GoTrue
`/token?grant_type=password` endpoint.

**Step 3: Commit**

```bash
git add supabase/functions/
git commit -m "feat: administer accounts through one service-role Edge Function"
```

---

## Task 9: Dart data layer

**Files:**
- Create: `songbook_app/lib/data/models/app_role.dart`
- Create: `songbook_app/lib/data/models/managed_user.dart`
- Create: `songbook_app/lib/data/models/app_settings.dart`
- Create: `songbook_app/lib/data/models/submission_refusal.dart`
- Create: `songbook_app/lib/data/repositories/admin_repository.dart`
- Modify: `songbook_app/lib/data/repositories/submission_repository.dart`
- Test: `songbook_app/test/unit/data/repositories/admin_repository_test.dart`
- Test: `songbook_app/test/unit/data/models/submission_refusal_test.dart`

**Step 1: Write the failing tests**

Model the refusal mapping on `AuthFailureCode` — read
`songbook_app/lib/data/repositories/auth_repository.dart` first and copy its
shape, including the doc comment explaining *why* server prose is never shown.

```dart
// test/unit/data/models/submission_refusal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/submission_refusal.dart';

void main() {
  group('SubmissionRefusal.fromServerMessage', () {
    test('maps each gate token to its own code', () {
      expect(SubmissionRefusal.fromServerMessage('submissions_closed'),
          SubmissionRefusal.submissionsClosed);
      expect(SubmissionRefusal.fromServerMessage('email_not_confirmed'),
          SubmissionRefusal.emailNotConfirmed);
      expect(SubmissionRefusal.fromServerMessage('guidelines_not_accepted'),
          SubmissionRefusal.guidelinesNotAccepted);
      expect(SubmissionRefusal.fromServerMessage('display_name_required'),
          SubmissionRefusal.displayNameRequired);
      expect(SubmissionRefusal.fromServerMessage('daily_limit_reached'),
          SubmissionRefusal.dailyLimitReached);
    });

    test('a token wrapped in Postgres prose is still recognised', () {
      // PostgrestException.message arrives as the raw exception text, which
      // carries the token but not always alone.
      expect(
        SubmissionRefusal.fromServerMessage(
            'new row violates ... submissions_closed ...'),
        SubmissionRefusal.submissionsClosed,
      );
    });

    test('anything unrecognised is unknown, never shown raw', () {
      expect(SubmissionRefusal.fromServerMessage('deadlock detected'),
          SubmissionRefusal.unknown);
    });
  });
}
```

For `AdminRepository`, test against a fake that records the invoked action and
returns canned JSON — do **not** hit a real Supabase client. Assert that `list`
parses users, that `setRole` sends the right body, and that a `403` surfaces as a
typed failure rather than an exception string.

**Step 2:** `cd songbook_app && flutter test test/unit/data/` — expect failures.

**Step 3:** Implement. `AdminRepository` wraps
`_client.functions.invoke('admin-users', body: {...})` and maps the function's
error strings (`cannot_delete_self`, `last_administrator`, `forbidden`) onto an
`AdminFailure` enum, same pattern again.

**Step 4:** `flutter test test/unit/data/` — expect pass. `flutter analyze` clean.

**Step 5: Commit**

```bash
git add songbook_app/lib/data songbook_app/test/unit/data
git commit -m "feat: type the admin API and the submission refusals"
```

---

## Task 10: Providers and the route guard

**Files:**
- Modify: `songbook_app/lib/presentation/providers/providers.dart:101-140`
- Create: `songbook_app/lib/presentation/providers/admin_provider.dart`
- Modify: `songbook_app/lib/router/app_router.dart`
- Test: `songbook_app/test/widget/admin_route_guard_test.dart`

**The failure mode to test first.** `isAdminProvider` is a `FutureProvider`, so on
a cold load of `/admin` the rank is briefly unknown. A `redirect` that treats
unknown as denied bounces the administrator to home every single time they open a
bookmarked admin URL. Redirect only on a **resolved** denial.

**Step 1: Write the failing test**

```dart
// test/widget/admin_route_guard_test.dart
//
// Three states, not two. The middle one is the bug.
testWidgets('a pending rank check waits rather than redirecting', (tester) async {
  // Override the rank provider with a Future that never completes.
  // Expect: the checking indicator is on screen and the location is STILL /admin.
});

testWidgets('a resolved denial redirects home', (tester) async {
  // Override with Future.value(AppRole.member).
  // Expect: location is '/'.
});

testWidgets('a resolved administrator sees the panel', (tester) async {
  // Override with Future.value(AppRole.administrator).
  // Expect: the admin overview renders.
});
```

Follow the existing idiom in `test/widget/cold_loaded_routes_test.dart` and
`router_urls_test.dart` — those already pump the real router at a given
`initialLocation`, which is exactly what this needs.

**Step 2:** `flutter test test/widget/admin_route_guard_test.dart` — expect
failure (no `/admin` route).

**Step 3:** Add to `AppRoutes`:

```dart
static const admin = '/admin';
static const adminQueue = '/admin/queue';
static const adminUsers = '/admin/users';
static const adminUser = '/admin/users/:id';
static const adminSettings = '/admin/settings';
```

Register them **outside** the `ShellRoute`, same reasoning as `/import`: a focused
task area, not a bottom-bar tab. Move the existing `ModerationQueueScreen` and
`MySubmissionsScreen` off their `MaterialPageRoute` pushes in
`settings_screen.dart:65,78` onto real paths — on a web app a bare
`MaterialPageRoute` means no bookmark, no reload and no back button.

Add `currentRoleProvider` (a `FutureProvider<AppRole>`) alongside the existing
`isAdminProvider`, and keep `isAdminProvider` as-is so nothing that reads it
breaks.

**Step 4:** `flutter test test/widget/` — expect pass, including
`router_urls_test.dart` and `cold_loaded_routes_test.dart` unchanged.

**Step 5: Commit**

```bash
git add songbook_app/lib/router songbook_app/lib/presentation/providers songbook_app/test/widget/admin_route_guard_test.dart
git commit -m "feat: route the admin panel, and wait on an unresolved rank check"
```

---

## Task 11: Admin screens

**Files:**
- Create: `songbook_app/lib/presentation/screens/admin/admin_overview_screen.dart`
- Create: `songbook_app/lib/presentation/screens/admin/admin_users_screen.dart`
- Create: `songbook_app/lib/presentation/screens/admin/admin_user_detail_screen.dart`
- Create: `songbook_app/lib/presentation/screens/admin/admin_settings_screen.dart`
- Modify: `songbook_app/lib/presentation/screens/settings/settings_screen.dart`
- Test: `songbook_app/test/widget/admin_users_screen_test.dart`
- Test: `songbook_app/test/widget/admin_settings_screen_test.dart`

Build one screen per commit, test first each time. Follow
`settings_screen.dart`'s section-header idiom and use `ContentPane`
(`lib/presentation/widgets/content_pane.dart`) for form layout — the responsive
behaviour is already solved there.

**Behaviour the tests must pin:**

- The user list shows role, last sign-in and the approved/pending/rejected tally.
- Deleting requires typing the account's email — a confirmation dialog with a
  destructive button is not enough for an irreversible action.
- The row for **yourself** offers neither delete nor a role change, and says why.
- A `last_administrator` refusal from the function renders as a localised
  explanation, not an error code.
- The settings screen writes `app_settings` and shows the three guideline text
  fields side by side with their language labels.

**Commit after each screen.**

---

## Task 12: The publish gate in the Add-song screen

**Files:**
- Modify: `songbook_app/lib/presentation/screens/import/import_song_screen.dart` (the `_save` path, ~line 595, and the app-bar actions, ~line 640)
- Create: `songbook_app/lib/presentation/screens/import/publish_gate.dart`
- Test: `songbook_app/test/widget/publish_gate_test.dart`

`Save to my device` keeps working exactly as it does today, signed-out and
offline. A second action, `Share with the congregation`, runs the gate.

**Every stop must preserve the draft.** A sign-in prompt that discards a hymn
somebody just typed in is how you teach them never to contribute again. Test that
explicitly — it is the assertion most likely to be skipped.

**Step 1: Write the failing tests**, one per stop, in order:

```dart
testWidgets('signed out, Share opens sign-in and the draft survives', ...);
testWidgets('no display name, Share asks how to credit you', ...);
testWidgets('unconfirmed email, Share offers to resend', ...);
testWidgets('guidelines unaccepted, Share shows them and records the tick', ...);
testWidgets('submissions closed, Share says so specifically', ...);
testWidgets('all clear, Share submits and lands on My submissions', ...);
```

**Steps 2-4:** implement `PublishGate` as a sequence of checks returning the
first unmet one, so the ordering is data rather than nested `if`s. Then wire the
button.

**Step 5:** Commit per stop if it is cleaner; one commit for the gate is fine.

---

## Task 13: Attribution on screen

**Files:**
- Modify: `songbook_app/lib/presentation/screens/song_view/song_view_screen.dart`
- Modify: `songbook_app/lib/presentation/screens/moderation/moderation_queue_screen.dart`
- Modify: `songbook_app/lib/data/models/submission.dart`
- Test: `songbook_app/test/widget/attribution_test.dart`

- Song view: "Submitted by X" on any `source = 'user'` song; "a former member"
  when `owner_id` is null but the frozen name survives.
- Moderation queue: submitter name **plus their prior approved/rejected counts**,
  so a repeat offender is visible at the moment of the decision rather than
  after it.

---

## Task 14: Localisation

**Files:**
- Modify: `songbook_app/lib/l10n/app_en.arb`, `app_hu.arb`, `app_ro.arb`
- Modify: `songbook_app/test/l10n/no_hardcoded_strings_test.dart` (`_localised` list)

**This is real work, not a formality.** `test/l10n/translations_test.dart` fails on
any key present in the template and missing from `hu` or `ro` — without it the
app silently shows English inside a Hungarian sentence. Roughly 45 new keys:

- Role names: `roleMember`, `roleModerator`, `roleAdministrator` — **and these are
  the "proper names" that were asked for**, so they are user-facing nouns in each
  language, not identifiers.
- Admin panel: titles, section headings, the user-list column labels, the tally.
- Destructive confirmation: the typed-email prompt, and its warning.
- Refusals: one message per `SubmissionRefusal` value and per `AdminFailure`.
- Gate: the display-name prompt, the guidelines sheet, the acceptance tick.
- Attribution: `submittedBy`, `submittedByFormerMember`, `reviewedBy`.

Add every new screen file to `_localised` in
`no_hardcoded_strings_test.dart` — that list is the claim that a file has been
translated, and adding the file is what turns the guard on for it.

**Verify:**

```bash
cd songbook_app && flutter gen-l10n && flutter test test/l10n/ && flutter analyze
```

---

## Task 15: Full verification

```bash
npx supabase db reset && npx supabase test db     # six suites
cd songbook_app && flutter test                   # 1203 baseline + new
flutter analyze
flutter build web --release --no-web-resources-cdn
```

The `--no-web-resources-cdn` flag is not optional — the CSP kills the app without
it.

Then a browser pass with `tools/browser-smoke/`: sign in as an administrator,
open `/admin/users` from a **cold load** (that is the guard's failure mode),
change a role, delete a throwaway account, close submissions, and confirm the
Share button explains itself.

**Do not `supabase db push` or `supabase functions deploy`.** Hand back a summary
and let the project owner run those against the live project, which has real
accounts in it.

---

## Deferred, on purpose

- The **Contributor** tier. The ranks leave room at 30; whether it is wanted is a
  later decision, and adding it now would be the one change that lets unreviewed
  text reach the congregation.
- **Notice banner** and **catalogue defaults** in app settings. Considered and cut.
- **Bulk moderation.** Not until the queue is long enough to be annoying.
