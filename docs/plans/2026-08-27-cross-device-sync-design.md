# Favourites and setlists follow the account

_Design record, 2026-08-27. Decisions are Robert's; the reasoning is recorded so
the next session does not have to re-derive it, and so the costs are on paper
before the flag is switched on._

## The problem this solves

`FavoritesRepository` and `SetlistRepository` both hold one field — a
`LocalDataSource` — and every read and every write goes to `SharedPreferences`
and stops there. A person signed in on a phone and on a tablet therefore has two
unrelated sets of favourites and two unrelated shelves of setlists.

This is the one promise an account currently makes and does not keep. Accounts
already do real work — they carry submissions, moderation, the frozen
attribution on an approved song — but none of that is what a *user* signs in
for. `.planning/ROADMAP.md` Phase 10 says so in as many words: criterion 2 is
the only ❌ in the phase, and it "undercuts the reason to have accounts at all".

## The three constraints that decide almost everything

1. **Signed-out is a hard requirement.** The app must work with no account and
   no network, exactly as the bundled hymnal makes the catalogue work with no
   server. So local storage is not replaced by a server; the server is layered
   *over* it, the way `SongRepository` already layers the Supabase catalogue over
   `assets/data/songs.json`.
2. **Both collections are tiny.** A person has tens of favourites and a handful
   of setlists. Every design below is allowed to move the whole collection every
   time, and does — which removes an entire category of bug.
3. **This repo has destroyed persisted data before.** Renaming a stored field's
   JSON key wiped users' favourites (see `Favorite.songId`'s `readValue`
   fallback, and `Setlist.songIds`'), and field-by-field model rebuilds silently
   dropped newly-added fields three times. So: **no stored key changes shape in
   this work.** New state goes in new keys.

## What was decided

| question | answer |
|---|---|
| where truth lives | the device. The server is a shared copy, not the source |
| favourite merge | tombstoned last-write-wins, per song id |
| setlist merge | last-write-wins over the **whole setlist**, per setlist id |
| deletion | a tombstone with a timestamp, on both sides |
| favourite order | rides on the winning row's `sort_order`; no timestamp of its own |
| first sign-in | a merge, not a migration. Neither side is discarded |
| a failed push | the local write already succeeded; the next sync retries |
| the sync algorithm | full-state, both directions, idempotent, no watermark |
| user songs | out of scope, and their favourites do not sync (see below) |
| the flag | `--dart-define=CROSS_DEVICE_SYNC=true`, **off** by default |
| UI | none. The flag is off; what a user should *see* is Robert's call |

## Merge semantics, and what each one costs

### A favourite is set membership, so union works — until you remove one

Union is the obvious merge for a set and it is wrong on its own: with union,
un-favouriting on the phone is undone by the next sync from the tablet, forever.
The favourite comes back, the user removes it again, it comes back again. A set
that can only grow is not the set the user is editing.

So removal has to be a *fact that is stored*, not the absence of a fact — a
tombstone. Then the merge is per song id, over two claims:

```
local claim   present at addedAt   |  removed at removedAt
server claim  present at changed_at |  removed at changed_at   (removed = true)
```

and the later timestamp wins. This is a last-write-wins element set, and for
membership it is exactly right: the two claims are about one bit, and the user
made one of them more recently.

**On an exact timestamp tie, the server wins.** A tie in practice means the same
event round-tripping (added locally at T, pushed, pulled back at T), where both
sides agree about membership anyway — so the rule only decides `sort_order`, and
resolving toward the shared copy is what makes two devices converge instead of
each keeping its own answer.

**What it costs.** The merge trusts a client clock. A device whose clock is two
days slow makes changes that lose to older ones from a correct device. Two
mitigations, one taken and one not:

* *Taken:* a trigger clamps `changed_at` to `least(changed_at, now())` on the
  server, so a clock set to 2030 cannot win every argument for the next four
  years. A slow clock can still lose arguments it should win; a fast one cannot
  win them permanently.
* *Not taken:* server-assigned timestamps only ("last device to reach the server
  wins"). That is immune to client clocks and gets offline editing backwards — a
  change made on Tuesday and pushed on Friday would beat one made on Thursday.
  For an app whose whole point is working offline, event time is the honest
  clock, and the clamp covers the abuse case.

### A setlist is a named ordered list, and there is no correct merge

Two devices editing the same setlist have no obviously right answer, and every
answer that *looks* right is worse than it looks:

| candidate | why not |
|---|---|
| union of the song ids | produces an order nobody chose, and cannot express a removal at all — the same defect as union for favourites, but now silently rewriting the order songs are sung in |
| per-song list CRDT (RGA/LSEQ) | genuinely correct, and genuinely a project: position identifiers, interleaving rules, a second serialisation format, and a class of bug that only appears on someone else's device |
| keep both copies | the user opens the app to two "Sunday Morning" setlists and has to work out which is which, during the service |
| field-by-field merge | name from one, order from the other: a list that neither device ever had |

**So: last-write-wins over the whole setlist, keyed on `Setlist.updatedAt`.**

Said plainly, because it should be said plainly: **if you add a song to "Sunday
Morning" on the phone and rename it on the tablet, one of those two edits is
discarded.** Not merged, not queued — discarded, in favour of whichever record
carries the later `updatedAt`.

Three things make that the right trade here rather than a shrug:

* A setlist is prepared for one service, usually in one sitting, usually on one
  device. Concurrent editing of the *same* setlist from two devices is the rare
  case, not the normal one.
* `Setlist.updatedAt` already exists and is already bumped by every mutator
  (`SetlistRepository._update`). The merge key is not new machinery; it is a
  field that has been maintained correctly since the setlist feature shipped.
* The unit of loss is bounded and visible. You lose one edit to one setlist, and
  you can see that you did, because the setlist in front of you is the one the
  other device wrote. You do not lose *the setlist*.

The alternative that survives review — a real ordered-list CRDT — is the right
answer for a shared setlist that two people edit at once. That is Phase 11's
problem (sharing), not this one's, and building it now would be building it
without the requirement that shapes it.

### Order, for favourites

`Favorite.sortOrder` gets no timestamp of its own; it rides on the row that wins
membership. A reorder therefore propagates only because a reorder pushes every
row, and the receiving device takes the server's `sort_order` on the tie. Two
devices reordering while both offline: one order wins, and it is the one that
reached the server second.

This is deliberately less machinery than the membership merge, because the
consequence is smaller: a favourites list in an unexpected order is a
disappointment, a favourite that will not stay deleted is a defect.

## Local storage stays the floor

The catalogue's shape, copied exactly:

```
SongRepository  bundled asset (always)  <- Supabase catalogue merged over it
Favourites      SharedPreferences (always) <- user_favorites merged over it
Setlists        SharedPreferences (always) <- user_setlists merged over it
```

Concretely, and this is the part that keeps signed-out use intact:

* **Every read is local.** `getFavorites()` and `getSetlists()` still read
  `SharedPreferences` and are still synchronous, so `FavoritesNotifier` and
  `SetlistsNotifier` need no restructuring and no loading state.
* **Every write is local first**, and returns on the strength of the local write
  alone. The push that follows is best-effort.
* **The remote datasource is nullable**, exactly as `RemoteSongDataSource` is on
  `SongRepository`. Null with the flag off, null with no backend, null in tests,
  null when `Supabase.initialize` fails. In every one of those cases the two
  repositories are the code that shipped today, with one `if` in front of the
  push.

### The stored format does not change

`favorites` and `setlists` keep their exact JSON. Everything new lives in keys
that did not exist before:

| key | holds |
|---|---|
| `favorites_removed` | `[{"songId": "hymnal:5", "removedAt": "..."}]` |
| `setlists_removed` | `[{"id": "sl_...", "removedAt": "..."}]` |
| `sync_owner` | the account id this device's collections belong to |

A build with sync switched off never writes any of them, and a build that reads
them and finds nothing is in exactly the state a device is in the first time it
syncs. `test/unit/data/datasources/stored_format_survives_sync_test.dart` pins
this: a blob in today's format, and one in the pre-`SongId` format that shipped
before it, both still load record-for-record after this change.

## The sync itself

**Full state, both directions, no watermark.** Constraint 2 pays for this:
`sync()` fetches every row the account has, compares it against every local
record, writes the merged result locally, and pushes back everything the local
side won. There is no "changed since" cursor to get wrong, no dirty flag to lose,
and no ordering requirement between pushes — running it twice does nothing the
second time.

It runs on sign-in and on app start while signed in. A local mutation pushes just
the record it touched, which is one upsert and keeps the common case cheap.

### When the network is down, or the write fails

Nothing is lost and nothing looks like it failed, because **the local store is
the outbox**. A mutation is complete when `SharedPreferences` has it; the push is
fire-and-forget and its failure is swallowed exactly as `SongRepository`
swallows a failed catalogue fetch — offline is a normal state for this app, not
an error worth interrupting anyone with.

A push that failed leaves a local record whose timestamp is newer than the
server's, so the next `sync()` pushes it as a matter of course. That is the
retry: not a queue, not a journal, just the same comparison that runs every time.

Rejected: a separate pending-writes queue. It is a second copy of the truth that
can diverge from the first, it has to be persisted (so it is a new stored format,
see constraint 3), it needs de-duplication and ordering, and it can itself become
corrupt. The comparison-based sync gets the same guarantee out of state that has
to exist anyway.

**What it costs:** a change made offline is not on the server until the app is
next opened with a connection. There is no background sync — this is a PWA, and
a service worker that syncs while the app is closed is a project of its own.

## First sign-in

The device has favourites. The account has different ones. Neither may be
discarded, so:

**First sign-in is an ordinary sync, and an ordinary sync already does the right
thing.** The device's records are claims with their existing timestamps; the
account's rows are claims with theirs; the merge runs. For favourites the result
is the union (the device has no tombstones from this account, so nothing is
removed). For setlists both shelves survive side by side, because setlist ids are
minted from a timestamp plus randomness and two devices cannot collide.

Two consequences worth stating rather than discovering:

* **Two setlists named "Sunday Morning" both survive.** Merging by name would
  silently combine two different lists into one, which is the failure this whole
  record exists to avoid. Different ids are different setlists, whatever they are
  called.
* **A favourite of a user song does not sync.** Only `hymnal:` ids cross the
  wire. A `user:` id names a song that exists on one device only, so the row
  would be invisible on every other device and would resurrect on the device that
  deleted the song (`purgeSongReferences` removes the favourite without leaving a
  tombstone). Setlists *do* carry `user:` ids verbatim, because dropping members
  out of an ordered list corrupts it, and the other device already skips ids it
  cannot resolve.

### Signing in as a *different* account on the same device

The dangerous half of "first sign-in", and it is a real scenario: the app is
installed on a shared tablet, or a spouse signs in to check something.

`sync_owner` records which account the local collections belong to. When the
signed-in user does not match it, the merge still runs — the local state is not
thrown away, which would violate the same rule as discarding it on first sign-in
— but **the tombstones are dropped first**. That gives one invariant worth having:

> Signing in as a different account can add things to that account. It can never
> remove anything from it.

**What it still costs:** the second account inherits the first account's
favourites. They are additive and removable, and nothing of the second account's
is destroyed — but they are there, and the user did not ask for them. This is the
one item on this page that Robert should decide before the flag goes on; the
alternative is a prompt on first sign-in ("this device has 14 favourites — add
them to your account?"), which is a UI decision and therefore his.

## The schema

Two tables, and the conventions of
`supabase/migrations/20260728120100_songs_rls.sql` throughout — in particular
that **GRANT and RLS are independent layers and both are required**, and that
since `20260728120200` a new table in `public` is granted nothing by default and
must declare its access on purpose.

```sql
public.user_favorites (user_id, song_id) primary key
  changed_at  timestamptz   -- the merge timestamp; clamped to now() server-side
  sort_order  integer
  removed     boolean       -- true = tombstone
  updated_at  timestamptz   -- server clock, for support questions only

public.user_setlists (user_id, id) primary key
  name, song_ids text[], created_at, changed_at, removed, updated_at
```

Notes on shape:

* **`song_id` is text, not a foreign key to `songs`.** A favourite names a
  `SongId` — `hymnal:151` — which is the app's identity for a song and is not a
  row id in that table at all. Bundled hymnal songs may have no server row.
* **A tombstone is a row, not a deleted row.** `removed = true` with a
  `changed_at` is what makes removal survive a merge. Rows are hard-deleted only
  by the `auth.users` cascade, when the account itself goes.
* **No admin bypass, deliberately.** `songs` lets an admin see everything,
  because moderation requires it. Nothing about moderating a hymnal requires
  reading what someone has favourited, so these policies are `user_id =
  auth.uid()` and nothing else. `is_admin()` does not appear in this migration.
* **Nothing is granted to `anon`.** There is no such thing as a signed-out user's
  row here; the signed-out collections live on the device.

`supabase/tests/user_data_rls_test.sql` proves the part that matters: Alice
cannot see, alter, delete or forge Bob's favourites or setlists, in that order,
and can do all four to her own.

## Where the flag lives

`SupabaseConfig.crossDeviceSyncEnabled`, a `bool.fromEnvironment`, **false**.

```
flutter build web --dart-define=CROSS_DEVICE_SYNC=true
```

It is read in exactly one place — `main.dart`, where the sync datasource is
constructed — so with the flag off `remoteSyncDataSourceProvider` yields null,
both repositories take the null branch, and the code path is the one that shipped
today. That is the property the existing test suite is being asked to confirm:
1352 tests passing unchanged is the evidence that the flag is genuinely off, not
merely quiet.

A compile-time define rather than a settings toggle, for the same reason
`PHOTO_IMPORT_ENDPOINT` is one: a build that must not talk to a server should not
contain a switch that makes it, and the deployed build sets it in one line of
`.github/workflows/deploy-pages.yml` when Robert decides it is time.

## Risks

1. **A resurrected favourite.** The classic tombstoned-set failure: a removal
   made before sync was switched on leaves no tombstone, so the first sync
   restores it. Accepted and bounded — it happens once, at switch-on, to
   whichever favourites were removed on a device that also has an account.
2. **A discarded setlist edit.** Stated above; it is the cost of LWW and the
   thing to watch for after switch-on.
3. **A wrong clock.** Clamped upward, unfixable downward. If it ever bites, the
   fix is a Lamport counter per record, which fits this schema without a
   migration of the data (one more integer column, compared before the
   timestamp).
4. **Sync writing something the app then cannot read.** Guarded the only way that
   works here: the wire format is built from the same models and the same
   `SongId` parsing the local store uses, and every remote record that will not
   parse is skipped one at a time — `RemoteSongDataSource._tryParse`'s discipline,
   for the same reason.

## Order

Four commits: this record, then the schema and its RLS test, then the local
tombstones with the format-survival test, then the repositories and their merge
tests.

## Not in this change

* **Any UI.** No sync indicator, no "last synced" line, no first-sign-in prompt,
  no ARB keys. With the flag off there is nothing to show, and what to show at
  switch-on is a product decision.
* **Recents, tag overrides, per-song view configs and settings.** Each is a
  reasonable thing to sync and none of them is the reported problem. Tag
  overrides in particular need their own answer, because an override *replaces*
  the bundled tags rather than adding to them.
* **User songs.** Out of scope by instruction, and correctly so: they already
  have a server path through submissions and moderation, and a second one would
  compete with it.
* **Background sync.** See above; needs a service worker.
* **Sharing a setlist with another person.** Phase 11, and the thing that would
  justify a real CRDT.
