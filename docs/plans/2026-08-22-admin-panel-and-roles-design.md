# Admin panel, roles, and the publish gate

**Date:** 2026-08-22
**Status:** design agreed, not yet implemented

## What this is for

Four things the app cannot currently do:

1. Manage accounts from inside the app — see who exists, change what they may do,
   delete somebody.
2. Change settings that affect everyone, without a deploy.
3. Show who submitted a song, and who approved it.
4. Require an account before a song reaches the shared catalogue.

The fourth is the point of the other three. The shared songbook is sung from in
a service; nonsense text in it is not a cosmetic problem. Every mechanism below
exists to make sure that anything the congregation sees passed through a named
account and a human decision.

## What already existed

Worth stating plainly, because most of the data model is already here and the
gap is smaller than the feature list suggests:

- `public.user_roles` with `role in ('admin', 'moderator')`, readable only
  through `is_admin()`, with no client write path at all.
- `public.profiles` with a world-readable `display_name`.
- `public.songs` with `owner_id`, a four-state `status`, `reviewed_by`,
  `reviewed_at`, RLS policies per operation and a trigger enforcing legal status
  transitions.
- `SubmissionRepository` with `submit`, `pendingQueue`, `approve`, `reject`.
- `ModerationQueueScreen` and `MySubmissionsScreen`.

And the two gaps that matter:

- **Nothing calls `SubmissionRepository.submit()`.** `ImportSongScreen._save()`
  writes to the device-local `UserSongRepository`. No song has ever left a phone,
  so there is currently no upload to gate.
- **`is_admin()` returns true for `'admin'` and `'moderator'` alike**, so the two
  roles are indistinguishable everywhere they are used.

## Decisions

### Publishing is submit-then-review

A signed-in member presses Share, the song enters the queue as `pending`, a
moderator approves, and it becomes `status = 'approved'` — which is world
readable, including to signed-out visitors. This is exactly what the existing RLS
already implements; it needs wiring, not designing.

Saving a song to the device stays free and signed-out. Signed-out use of the
bundled hymnal remains fully functional, which is a standing requirement of this
codebase.

### Roles are a lookup table, not an enum

```sql
create table public.roles (
  name text primary key,
  rank smallint not null unique
);
insert into public.roles (name, rank) values
  ('member', 10), ('moderator', 50), ('administrator', 90);
```

`user_roles.role` references `roles(name)`. Policies test **rank**, never a role
name:

- `role_rank(uid)` — `security definer`, returns the caller's rank or 0.
- `can_moderate()` — rank >= 50.
- `is_administrator()` — rank >= 90.

**Why a table and not an enum or a `check` constraint:** adding a tier later must
be an `INSERT`, not a migration that rewrites a constraint and re-examines every
policy that referenced it. A `contributor` at rank 30 is one row. This was the
explicit requirement — the ladder has to be expandable, and whether a
`contributor` tier is wanted is a later decision.

**`is_admin()` is redefined as an alias for `can_moderate()`.** Six existing
policies and two triggers call it. Rewriting them all to the new predicate would
reopen the RLS surface that migration `..120200` and `..190000` were written to
harden, for no behavioural gain. Existing `'admin'` rows migrate to
`'administrator'`.

| | Member | Moderator | Administrator |
|---|---|---|---|
| Read approved catalogue | yes | yes | yes |
| Save to device | yes | yes | yes |
| Submit for review | yes | yes | yes |
| Approve / reject | — | yes | yes |
| Edit or delete any song | — | yes | yes |
| See the user list | — | — | yes |
| Change roles | — | — | yes |
| Delete an account | — | — | yes |
| Change app settings | — | — | yes |

### Every account has a role row

A trigger on `auth.users` insert creates a `profiles` row and a `member`
`user_roles` row; both are backfilled for existing accounts. A Member is
therefore a record rather than the absence of one — which is what makes the admin
user list complete, and what lets a future tier sit *below* moderator without a
special case for "no row".

### Deleting a user keeps their songs

An approved song belongs to the catalogue, not to the account that submitted it —
the same principle already written into migration `..190000`. So deleting an
account orphans its songs rather than removing them.

Three things have to change together for that, and missing any one of them is a
silent bug:

1. `songs.owner_id` becomes `on delete set null`. It is already nullable.
2. `songs_source_shape` (migration `..120300`) currently asserts
   `source = 'user' and owner_id is not null`. That constraint forbids the
   orphan. It has to permit a null owner on a user song.
3. `enforce_song_status_transition` guards ownership with
   `new.owner_id <> old.owner_id`. Once nulls exist that comparison evaluates to
   `NULL`, which is not `true`, so **the guard silently stops firing**. It must
   become `IS DISTINCT FROM`, and it must additionally refuse to set a non-null
   owner on a row whose owner is already null — an orphaned song cannot be
   adopted, or deleting an account would become a way to launder its submissions
   into another one.

### Attribution is frozen at submission time

`songs.submitted_by_name text`, stamped by trigger from `profiles.display_name`
at the moment the song becomes `pending`.

Deliberately a copy and not a join. `display_name` is user-editable and the
account can be deleted; an audit trail that reads live from `profiles` is one the
audited party can rewrite after the fact. The frozen name is also what makes the
orphan case readable — a deleted member's song still says who submitted it.

`public.admin_audit(id, actor_id, action, target_user_id, details jsonb, at)`
records every role change and account deletion. Append-only: no client write
path, no `UPDATE` or `DELETE` privilege for anyone.

### User CRUD needs an Edge Function

`supabase/functions/admin-users` — the first Edge Function in this repo. It holds
the service-role key, because listing `auth.users`, creating an account and
deleting one are all impossible with the anon key, by design.

It verifies the caller's JWT and then **re-checks `is_administrator()`
server-side**. The client's answer to "am I an admin" is for hiding buttons and
is never an authorisation.

- **Create** — invite by email.
- **Read** — list with role, created, last sign-in, and per-user approved /
  pending / rejected counts.
- **Update** — role, display name.
- **Delete** — hard delete, behind a typed confirmation.

Two refusals are built into the function, because both are one tap from locking
you out of your own panel:

- You cannot delete or demote **yourself**.
- It will not remove the **last** Administrator.

Email addresses live in `auth.users` and are exposed nowhere else. This function
is the only way to see one, which is the correct amount of exposure.

### App settings: the submissions gate and the guidelines

`public.app_settings`, a single row (`id smallint primary key check (id = 1)`):

| column | purpose |
|---|---|
| `submissions_open` | master switch; close the door without a deploy |
| `require_confirmed_email` | whether an unverified account may submit |
| `daily_submission_cap` | per-user submissions per day |
| `guidelines_en` / `_hu` / `_ro` | the rules a contributor accepts |
| `updated_at`, `updated_by` | who changed it |

`SELECT` is granted to `anon` and `authenticated` — a signed-out visitor has to
be able to read the guidelines and see whether the door is open. `UPDATE` is
Administrator only.

Deliberately excluded, having been considered: a notice banner and catalogue
defaults (default book, default language, featured song). Neither is needed yet.

## The publish gate

`Share with the congregation` runs five stops. Each one preserves the draft — a
sign-in prompt that discards a hymn somebody just typed in is how you teach them
never to contribute again.

1. **Signed out** → sign-in sheet, return to the same draft. This is the login
   gate.
2. **No display name** → "How should we credit you?" A null `display_name` would
   otherwise force attribution back onto an email address, publishing it.
3. **Email unconfirmed** → resend prompt, when `require_confirmed_email` is on.
4. **Guidelines not accepted** → the guidelines text, ticked once, stamped on
   `profiles.guidelines_accepted_at`.
5. **Submissions closed, or daily cap reached** → the specific reason, not a
   generic failure.

**All five are re-checked in the insert trigger.** Submissions open, email
confirmed, guidelines accepted, today's count under the cap. The client checks
exist to produce a good message; the database is the gate. Same division as the
rest of this schema — the app asks, the server decides.

## Admin panel routes

`ModerationQueueScreen` and `MySubmissionsScreen` are currently pushed as bare
`MaterialPageRoute`s from Settings, so they have no address at all — on a web app
that means no bookmark, no reload and no back button. They join a new `/admin`
branch, outside the bottom-bar shell for the same reason `/import` is: a focused
task area, not a congregation-facing tab.

```
/admin            overview: queue depth, member count, recent audit
/admin/queue      the existing moderation screen, now addressable
/admin/users      list, search, filter by role
/admin/users/:id  detail and destructive actions
/admin/settings   the server-side settings above
```

Reached from Settings → Administration. `/admin/queue` is visible from Moderator
up; everything else is Administrator only.

**The guard has one failure mode worth naming.** `isAdminProvider` is a
`FutureProvider`, so on a cold load of `/admin` the role is briefly unknown. A
`redirect` that treats unknown as "denied" bounces you to home every time you open
a bookmarked admin URL. So: redirect only on a **resolved** denial, and render a
checking state while it is pending.

## Where attribution appears

- Song view: "Submitted by X" on any `source = 'user'` song.
- Moderation queue: submitter name **plus their prior approved / rejected
  counts**, so a repeat offender is visible at the moment of the decision rather
  than after it.
- Audit trail: "Reviewed by Y", and the `admin_audit` list on `/admin`.

## Testing

`supabase/tests/songs_rls_test.sql` gains pgTAP cases per tier:

- a Member cannot read `user_roles`, cannot approve, cannot exceed the cap
- a Moderator can approve but cannot reach the user list
- an Administrator can, and still cannot demote themselves
- deleting an owner leaves their approved song in place, with its frozen
  `submitted_by_name`
- the re-adoption refusal: a null owner cannot be set to a non-null one

Dart-side: the guard's unknown-role state, the gate's stop ordering, and draft
survival across the sign-in round trip.

**Cost to plan for:** every new string needs en / hu / ro, or the localisation
guard tests fail. There are roughly 330 keys per language today and this feature
adds a visible fraction of that.
