# Admin panel: what was built, and where it differs from the plan

**Date:** 2026-08-22
**Branch:** `admin-panel`
**Status:** implemented and verified locally. **Not deployed.**

Read alongside `2026-08-22-admin-panel-and-roles-design.md` (the decisions) and
`2026-08-22-admin-panel-implementation-plan.md` (the intended steps). This file
records what the work actually taught, so the next person does not have to
rediscover it.

## Verification

| | |
|---|---|
pgTAP | 79 assertions, 7 suites, `npx supabase test db` |
Flutter | 1240 tests (1203 before this work), `flutter test` |
Analyzer | clean over `lib/` and `test/` |
Edge Function | 13 integration checks, `supabase/functions/admin-users/verify.sh` |
Release build | `flutter build web --release --no-web-resources-cdn` succeeds |

Not done: a browser pass against the deployed app, and `supabase db push` /
`supabase functions deploy`. Both are below.

## Five things the plan got wrong

### 1. `service_role` had no privileges on anything

The Edge Function answered **403 to a genuine administrator**. Its own
`is_administrator()` check passed and every read after it failed.

`bypassrls` is not "bypass grants". `service_role` skips row-level security and
still needs a table-level `GRANT` like any other role — and migration
`20260728120200` had deliberately established that a new table in `public` gets
nothing implicitly. Verified locally: all six tables, `select`/`insert`/`update`,
false for `service_role`.

It would probably have worked in the cloud, via the permissive default
privileges that `..120200` exists to distrust — so it would have failed on every
developer machine and worked in production, which is the worst version of this
bug. Fixed by `20260822120700_service_role_privileges.sql`, granting exactly what
`index.ts` uses, with `privileges_test.sql` (16 assertions) pinning the whole
matrix for every client role.

### 2. `ON DELETE SET NULL` fires the `BEFORE UPDATE` trigger

Anticipated in the plan, but only half of it. The FK action performs an *update*
on `songs`, so the ownership guard rejects the very deletion it is meant to
permit — `delete from auth.users` fails with "song owner cannot be changed".

The other half was not anticipated: **relaxing `songs_source_shape` removed a
protection nobody had written down.** `songs_update_admin`'s `WITH CHECK` is only
`is_admin()`, so nothing in RLS stopped a *moderator* writing `owner_id = null`
and stripping a song of its attribution. Until now the shape constraint blocked
that by accident. Scoping the guard to `auth.uid() IS NULL` restores it:
orphaning is confined to a service-role context, so the Edge Function may do it
and a signed-in moderator may not. `account_delete_test.sql` asserts both.

### 3. A gate on `INSERT` alone is trivially bypassable

Save a draft, then submit it. That is the ordinary path through the Add-song
screen, not an exotic one, and it reaches `pending` through `UPDATE`. Hence
`20260822120600` and a cap test that submits via the update path.

### 4. The route guard is a widget, not a `redirect`

The plan said redirect-on-resolved-denial. Two problems with that:

- go_router does not re-run `redirect` when a Riverpod provider settles, so it
  would need a `refreshListenable` and would *still* have to answer "checking"
  with something.
- `redirect` runs during navigation, so the denied path means navigating while
  building.

`AdminGate` is a `ConsumerWidget` instead, and denial says so plainly rather than
bouncing home — a silent redirect from a bookmarked link is indistinguishable
from a broken link, and `/admin` is documented in a public repo anyway.

### 5. "songs_rls_test.sql unchanged" was the wrong gate

It could not hold: the provisioning trigger creates the role row that file's
fixture used to `INSERT`, and `'admin'` was retired. The defensible claim is
narrower and was verified instead — **no `select is(...)`, `ok(...)` or
`throws_ok(...)` line differs.** All 26 assertions intact. That, not an untouched
file, is what proves the `is_admin()` alias preserved behaviour.

## One design decision worth keeping

**The publish gate reports a closed door before it asks for anything.** Walking
somebody through sign-in, email confirmation, a display name and the guidelines
and *then* telling them submissions were shut the whole time is how a
contribution flow gets abandoned. Among the remaining stops, whatever forces the
user to leave the app (confirming an address) comes before whatever they can
finish inline (a name, a tick).

The daily cap is deliberately **not** pre-checked. The client does not know the
count, and asking would be a round trip for a case that is nearly always fine. It
arrives as a server refusal — the one stop that can only be reported after the
attempt.

## Deployment, when you want it

Nothing has touched the live project yet. **The push is a manual step** — an
agent's attempt to write to the production database is refused by the permission
classifier, which is the right default for this.

### What is actually at risk, verified from a backup taken 2026-08-25

Taken with `supabase db dump` into `backups/` (gitignored — these files contain
`auth.users` password hashes and must never be committed):

| | |
|---|---|
`songs` | 8 rows, **all `source = 'hymnal'`** with `owner_id IS NULL` |
`profiles` | empty |
`user_roles` | **one row**, currently `'admin'` |

So there are no user submissions in production at all. Nothing can be orphaned by
the foreign-key change, and the new `songs_source_shape` constraint validates
against all 8 existing rows (they take the `hymnal` branch unchanged).

**You do not need a bootstrap step.** An earlier draft of this file said there was
no in-app path to the first administrator, which is true in general and wrong
here: migration `20260822120000` rewrites `role = 'admin'` to `'administrator'`,
and the one existing row is yours. You come out of the push as the Administrator.

### The push

```bash
cd <this worktree>
npx supabase db push          # 8 migrations, dry-run verified
npx supabase functions deploy admin-users
```

`SUPABASE_SERVICE_ROLE_KEY` is provided to deployed functions automatically; it
does not need setting by hand.

### Order matters

Migrations first, **then** the app. `master` deploys to GitHub Pages on push, so
merging this branch publishes an admin UI to every visitor. If the app lands
first it will call `role_rank` and `app_settings` on a database that has neither,
and every contributor's Share button will fail until the migrations catch up.

### Then the browser pass

The part no test here covers:

- open `/admin/users` from a **cold load** in a fresh tab — that is the guard's
  failure mode, and a hot-reloaded session will not reproduce it
- change a role, and confirm the audit entry appears
- share a song end to end: the name prompt, the guidelines tick, then the queue
- close submissions, and confirm Share explains itself rather than failing
- read the Hungarian and Romanian on the admin screens; they were written in this
  session and have not been checked by a native speaker

## Still deferred, on purpose

- **The Contributor tier.** Rank 30 is free. Adding it is one `INSERT` plus one
  `AppRole` constant — that expandability was the point of the lookup table.
- **Notice banner, catalogue defaults.** Considered and cut.
- **Bulk moderation.** Not until the queue is long enough to be annoying.
