# Old Songbook → songbook-app: what's worth taking, and how

_2026-07-27. Sources: `github.com/MeguRobert/Songbook` (2,196 lines Dart, 68 commits, last active Jan 2023) and `github.com/MeguRobert/wsongbook`._

> **Backend superseded (2026-07-28): the platform runs on Supabase, not Firebase.**
> This document was written assuming Firebase, and phases C/D/E below still say so. Read every
> *forward-looking* Firebase reference as its Supabase equivalent — Firebase Auth → Supabase Auth,
> Firestore security rules → Postgres row-level security, custom claims → the `user_roles` table
> behind `is_admin()`. References to Firebase/Firestore describing **the old app** are historically
> accurate and stand as written.
>
> The decision and its reasoning are in `HANDOFF-platform.md` → Decision 2. The short version: RLS
> *filters* rows whereas Firestore rules *reject the whole query*, which makes the old app's headline
> defect structurally hard to reproduce rather than a discipline to sustain. The schema, policies and
> a passing 21-assertion pgTAP test now live in `supabase/`.

## Verdict

**`wsongbook` contains no source** — it is the compiled web deploy of `Songbook` (one 2.4 MB `main.dart.js`). Everything below comes from `Songbook`.

**Do not migrate the code. Do migrate the central idea.**

The old code is Flutter 2.x (`sdk >=2.16.0 <3.0.0`), Provider + `setState` + static singletons, package still named `hello_word`. It carries defects that must not enter this codebase (listed in "Why not the code"). There is nothing here to copy-paste.

But the old app solved a problem this one has not touched: **where songs come from**. This app has world-class engraving, transposition, capo, setlists, tags and presentation mode — over **8 songs**. The old app was plain, and had a catalog that grew without the maintainer: users upload, admins approve. That is the highest-value idea in the repo, and it is exactly the sketch ("add your own songs, songbooks and publish; admins should approve").

---

## Enumerated ideas (32)

Verdicts: **TAKE** = adopt the idea, write fresh code · **ADAPT** = idea is right, old shape is wrong · **HAVE** = this app already does it, better · **SKIP** = actively don't.

### A. Identity & accounts

| # | Idea | Old code | Verdict |
|---|---|---|---|
| 1 | Email/password sign-in & register | `auth_service.dart:15,35` | **TAKE** |
| 2 | Email-verification gate before app access; 3 s poll, resend on 10 s cooldown | `verify_email.dart` | **TAKE** |
| 3 | Password reset by email | `auth_service.dart:83` | **TAKE** |
| 4 | Password visibility toggle | `authentication.dart:138` | TAKE (trivial) |
| 5 | Firebase error-code → human, localized message | `authentication.dart:48–73` | **TAKE** — the mapping table is genuinely useful; raw Firebase errors are unusable |
| 6 | Sign-out confirmation dialog | `sign_out_button.dart:27` | TAKE (trivial) |

### B. Roles, ownership & moderation — *the sketch*

| # | Idea | Old code | Verdict |
|---|---|---|---|
| 7 | `users` collection carrying `isAdmin` | `user_data.dart`, `auth_service.dart:131` | **ADAPT** — roles belong in custom claims, not a client-readable doc |
| 8 | `approved` + `approvedBy` on every song | `song.dart:12–13` | **ADAPT** — needs `draft/pending/approved/rejected` + reason, not a bool |
| 9 | Unapproved songs visible only to owner + admins | `song_list.dart:70–88` | **ADAPT** — must be enforced server-side (see defects) |
| 10 | Write permission = `isAdmin \|\| isOwner` | `song_list.dart:74` | **TAKE** |
| 11 | Admin-created songs auto-approve | `song_repository.dart:39–41` | **TAKE** |
| 12 | Audit trail: `uploader`, `uploaderEmail`, `lastEditedByEmail` | `song.dart:9–11` | **TAKE** |

### C. Content creation

| # | Idea | Old code | Verdict |
|---|---|---|---|
| 13 | In-app song editor with add/edit modes | `song_editor.dart`, `editor.dart` | **TAKE** — the single biggest gap in this app |
| 14 | Rich-text body stored as Quill delta JSON | `editorController.dart`, `flutter_quill` | **SKIP** — see "Why not Quill" |
| 15 | Deliberately stripped-down toolbar (everything off except colour) | `editor.dart:188–206` | **SKIP** with 14, but note the instinct was right: a songwriter needs ~3 controls, not 20 |
| 16 | Chords encoded as coloured text + `extractChords()` reading `attributes['color']` | `editor.dart:137–156` (dead stub; PR #22 "US-15 Auto Chord Detection") | **ADAPT** — abandoned in the old app, and the mechanism was wrong, but the *goal* (type lyrics, get chords) is right. Do it as ChordPro/bracket parsing |
| 17 | Save-time validation: title required, content required, title unique | `song_repository.dart:86–100` | **TAKE** |
| 18 | Whitespace-only content rejected (`^(\n\|\s)+$`) | `validate.dart:11,15` | **TAKE** |
| 19 | Auto-increment song number (max + 1) | `song_repository.dart:74–84` | **ADAPT** — not transactional (two concurrent creates collide) and user songs must not collide with hymnal numbers |

### D. Cloud & content supply

| # | Idea | Old code | Verdict |
|---|---|---|---|
| 20 | Firestore snapshot stream → list updates live, across devices | `song_repository.dart:17–22` | **TAKE** |
| 21 | Separate collection per language (`test_songs_hu/ro/en`) | `song_repository.dart:14,28–33` | **ADAPT** — a `language` field or the existing `book` field, not separate collections |
| 22 | **The catalog grows without the maintainer** | (the architecture itself) | **TAKE** — the strategic point of this whole exercise |

### E. Localization

| # | Idea | Old code | Verdict |
|---|---|---|---|
| 23 | Full HU / RO / EN UI strings (~40 keys) | `constants.dart` (188 lines) | **TAKE** — this app is English-only hardcoded, for a Hungarian congregation. The old file is a ready-made translation memory: copy the *text*, not the pattern |
| 24 | Language switcher in the app bar | `dropdown_button.dart` | **ADAPT** — Settings, not the app bar (see UI density) |
| 25 | Locale-aware defaults ("Ismeretlen" / "Unknown" / "Necunoscut") | `constants.dart:59` | **TAKE** |

### F. Interaction & UI

| # | Idea | Old code | Verdict |
|---|---|---|---|
| 26 | Auto-scroll with adjustable speed | `editor.dart:35–56` | **HAVE** — `autoscroll_provider.dart` is better: px/s, clamped 12–120, persisted per song, `dt`-clamped ticker |
| 27 | ExpandableFab hiding the speed slider | `expandable_fab.dart` (252 lines) | **HAVE** — the controls sheet supersedes it |
| 28 | Song card: number avatar + title + author + uploader | `song_card.dart` | **HAVE** (`song_list_tile.dart`), but see 29 |
| 29 | **Author and uploader as separate, displayed fields** | `song_card.dart:36–43` | **TAKE** — attribution matters once songs are user-contributed; today's model has `origin`/`tune` but no contributor |
| 30 | Diacritic-insensitive search | `song_list.dart:157–165` | **HAVE** — `string_extensions.dart:10` covers all 9 Hungarian pairs incl. ő/ű |
| 31 | Search matches author and uploader too | `song_list.dart:159–160` | **TAKE** — current search covers title/number/reference/lyrics, not people |
| 32 | Delete confirmation dialog | `song_list.dart:121` | TAKE (trivial, needed once songs are deletable) |

---

## Why not the code

Beyond age, these are defects that must not be carried over:

- **Approval is enforced only in the UI.** `SongRepository.songs` streams the *entire* collection to every device; `song_list.dart:76` merely hides unapproved rows from the widget tree. Any client reads every unapproved submission. This is a data leak, not a rendering bug — and it is the mistake most likely to be repeated, because the client-side version is the easy one to write.
- **`isAdmin` lives in a client-readable Firestore doc** (`users/{email}`), keyed by email. Trust boundary in the wrong place.
- **One Firestore read per visible row, per rebuild** — `FutureBuilder(future: _auth.isAdmin)` is constructed *inside* `ListView.builder` (`song_list.dart:68`).
- **Errors returned as values**: `catch (e) { print(e); return e; }` throughout, then type-tested at the call site (`if (response is Exception)`). Silently returns `null`/`Exception` where a `User` was expected.
- **Global mutable singletons**: `editorController` (`editorController.dart:8`) is a top-level `QuillController` shared across screens, disposed inside a widget's `dispose` and reassigned; `language` (`globals.dart:3`) is a top-level `String`.
- **`Navigator.pushNamedAndRemoveUntil` inside `initState`** (`song_list.dart:32`), before the first frame.
- **`_setSongId` is a non-transactional max+1 read.**

### Why not Quill

`flutter_quill` stores a song as an opaque rich-text delta. This app's `Song` is structured — `Verse → LyricLine → ChordPosition`, plus `SongNotation` for engraving. Everything that makes this app worth using reads that structure: transposition, capo, chords-above-staff rendering, verse-by-verse presentation mode, lyrics search snippets. A delta blob supports none of it. Adopting Quill would trade the product's differentiator for a faster editor build. The editor must produce the structured model.

---

## The blocker: song identity is an `int`

**This must be fixed before any user-authored song exists**, or everything built on top is on sand.

`Song.number` is an `int` and is the only key in the system:

- `Song.==` compares `number` and nothing else (`song.dart:209`) — already flagged in `HANDOFF.md` as live ammunition
- `Favorite.songNumber` → `int` (`favorite.dart:9`)
- `RecentSong.songNumber` → `int` (`recent_song.dart:6`)
- `Setlist.songNumbers` → `List<int>` (`setlist.dart:21`)
- tag overrides → `Map<int, List<String>>` (`local_datasource.dart:152`)
- route → `/song/:number`

Hymnal numbers are authoritative and shared. User songs have no such number. Two users each writing "song 300" collide; a favorite pointing at `300` becomes ambiguous. Sequential max+1 (old app, idea 19) does not fix it — it just moves the collision to the boundary between bundled and user content.

The fix is a `SongId` value type — a source plus a reference, e.g. `hymnal:151` / `user:9f3a2c`. It touches four persisted formats, so it needs a versioned read that upgrades existing `int` payloads in place. Invisible to the user, fully testable offline, and cheap now versus expensive later.

### Second identity trap, in the same family

`Verse.==` (`verse.dart:60`) compares `number`, `hasNotation` and `plainText` — **not `lines`**, and
`hashCode` omits `lines` too. Today nothing mutates a verse, so it is dormant. An editor mutates
verses constantly: `verse.copyWith(lines: …)` produces a verse that compares **equal** to the
original, so any widget or provider comparing verses will not see the edit. This must be fixed
alongside `Song.==` in Phase A, before the editor is written against it.

---

## Plan

**Decision (2026-07-27): Phases 0 → A → B only.** Local authoring first; accounts, publishing and
moderation (C, D, E) are deferred until it is clear the catalog needs more than one contributor.
They stay described below so the sequencing survives the decision. F is independent.

Ordered by dependency. Phase 0 and F are independent and can be slotted anywhere.

### Phase 0 — Declutter the mobile UI *(no backend; do this first)*

Robert's complaint, and a prerequisite: contribution features add *edit*, *submit*, *approve* buttons, and the app bar has no room left.

Today `song_view_screen.dart:257` renders: back · `"151. Title"` · tags · auto-scroll · presentation · favourite — five targets crowding the title on a phone, which is why the full title is unreadable.

- Song number becomes a leading chip or moves under the title; the title gets the width and wraps to two lines
- Keep at most one action visible (favourite); everything else goes to an overflow menu — or better, into `song_controls_sheet.dart`, which already has a fixed five-section layout and is the established home for view controls
- Same pass on the song list bar (`song_list_screen.dart:75` — search + two more actions)

*Effort: small. No dependencies. Directly answers the UAT finding.*

### Phase A — `int number` → `SongId` *(prerequisite for everything below)*

`SongId` type; migrate favorites, recents, setlists and tag overrides behind a versioned reader that upgrades old `int` payloads; router accepts both forms during transition; fix `Song.==` to cover its fields while in there.

*Effort: medium. No user-visible change. Ideas: 19.*

### Phase B — Local song authoring *(no cloud yet)*

Deliberately before the backend: the editor is the hard UX problem, it is useful on its own (Robert can add songs today), and it settles the schema before anything is written to Firestore.

- Structured editor: title, number, key, time signature, book, tags, verses; per-line chord entry producing real `ChordPosition`s
- **ChordPro / bracket paste**: `[G]Amazing [C]grace how [G]sweet` → `LyricLine` + `ChordPosition`. This is idea 16 done correctly, and it is how the catalog actually gets filled fast
- Validation in the spirit of 17/18: title required, at least one verse, duplicate-title warning, whitespace-only rejected
- Contributor fields on `Song` (idea 29) and search over them (idea 31)
- Single-song JSON export/import — sharing that works with no server at all

*Effort: large. Depends on A. Ideas: 13, 16, 17, 18, 19, 29, 31, 32.*

### Phase C — Accounts *(≈ roadmap Phase 10, first half)*

Firebase Auth, using the old app as a behavioural reference: email/password, verification gate, password reset, the error-code mapping table (idea 5). **Signed-out must remain fully functional** — the app works with no account today and must not regress.

*Effort: medium. Ideas: 1–6.*

### Phase D — Publish & moderate *(≈ roadmap Phase 10, second half — the sketch)*

- `SongSubmission`: `draft | pending | approved | rejected`, plus `rejectionReason`, timestamps, `submittedBy`, `reviewedBy`
- **Firestore security rules do the enforcement.** Unapproved submissions must be unreadable by anyone but their owner and admins — server-side. Do not repeat the old app's client-side hiding
- Admin roles via custom claims, not a readable `users` doc
- Moderation queue screen: pending list, approve / reject-with-reason, diff against the previous version on edits
- Approved songs merge into the catalog alongside bundled `songs.json`

*Effort: large. Depends on A, B, C. Ideas: 7–12, 20, 22.*

### Phase E — User songbooks & sharing *(≈ roadmap Phase 11)*

`book` is a bare `String` today. Promote it: owner, visibility (private / unlisted / public), ordered song list, share link, import into another user's app.

*Effort: large. Depends on D. Ideas: 21.*

### Phase F — Localization *(independent)*

`flutter_localizations` + `gen_l10n`, HU/EN/RO, switcher in Settings. Lift the Hungarian and Romanian **text** out of the old `constants.dart` — ~40 strings already translated and idiomatic. Reject the old pattern (`const Map` per string, global `language`).

*Effort: medium, mostly mechanical. No dependencies. Ideas: 23, 24, 25.*

---

## Constraints worth deciding before Phase D

- **User-generated content triggers extra store requirements.** Apple's App Review Guidelines cover UGC (§1.2) and require a content-filtering method, a report mechanism, the ability to block abusive users, and published contact info; Google Play has an equivalent UGC policy. Worth confirming the current text before planning around it, but it is a real scope addition the sketch does not account for — and v1.0 store submission is still open.
- **Moderation is ongoing human labour.** The approval queue only works if someone works it. A single-admin app where the admin is also the only content producer may be better served by Phase B alone.
- **Firebase adds cost, an auth surface, and offline-sync complexity** to an app that is currently a static PWA deployed to GitHub Pages for free.

## Not doing

- Copying any old Dart file
- `flutter_quill` or any rich-text body format
- Per-language Firestore collections
- Client-side approval filtering
- Sequential integer IDs for user-created songs
