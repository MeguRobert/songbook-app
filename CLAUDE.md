# Songbook — instructions for Claude

## Instrumentation is part of the change, not a follow-up

**Every change to app code carries its own account of what it did.** Not because
logging is virtuous, but because of the position this project is in: it runs on a
public GitHub Pages URL, for a congregation, on a free-tier Supabase project
whose own platform logs are **kept for one day**. When somebody says "it didn't
work", the platform's record of it is already gone. If the app did not write
something down, nobody will ever know what happened.

Before finishing any change under `songbook_app/lib/`,
`supabase/functions/` or `supabase/migrations/`, answer both of these. Answering
"neither" is a legitimate answer — say so in one line and move on. Skipping the
question is not.

### 1. Did this add or change a way things can go wrong? → a diagnostic event

Not only a thrown error. The three that matter here have never thrown:

| | Example in this repo |
|---|---|
| **A handled failure** | `catch (_) { return null; }` in `remote_song_datasource.dart` |
| **A degraded result** | a photo read that found 3 of 4 chord rows |
| **A silent fallback** | Supabase init failing and the catalogue quietly going bundled-only |

Each of those needs a row in `error_reports`, written through the existing
transport:

```dart
// domain/services/crash_reporter.dart
reporter.note(DiagnosticEvent.photoImport, 'photo import: ok',
    details: {'outcome': 'ok', 'ms': 2140});
```

**Reuse the transport. Never build a second pipeline.** It already throttles,
swallows its own failures, and stamps the route, the locale, the platform and the
build number onto every row. A new sink would have to get four things right again
to arrive in the same table — and the real cost is that whoever is debugging then
has two places to look, and always checks the wrong one first.

Rules that are not negotiable:

- **A new event value lands with its writer, in the same commit** — the string in
  `DiagnosticEvent` *and* the `check` constraint in a migration. Never add a
  constraint value speculatively. `admin_audit` carried `settings_changed` for
  five days with nothing emitting it, and the schema read as though settings
  changes were accounted for when they were not.
- **`details` holds measurements only.** Counts, milliseconds, fractions, sizes,
  enum names, booleans. **Never content**: no lyrics, no ChordPro, no image
  bytes, no file names, no email addresses, no text a user typed. Moderators read
  this table and an anonymous client writes it. `deploy/omr/server.py` is the
  model — it logs the note count and the elapsed time and never the score.
- **Recording a failure must never cause one.** Every path swallows itself.
- **Do not log** route changes, Supabase queries, or render decisions. The two
  `kDebugMode`-gated `debugPrint`s in `sheet_music_view.dart` are the right
  shape; leave them alone.
- **`debugPrint` is NOT stripped in release.** Flutter's own source says so
  (`packages/flutter/lib/src/foundation/print.dart`). Wrap it in `kDebugMode` or
  mean for it to ship.

### 2. Did this add or change a privileged action? → an `admin_audit` row

A privileged action is one an administrator or moderator takes **against
somebody else, or against the project's shared rules**: a role change, an account
deletion or invitation, a settings edit, a moderation decision. All six are
audited; a seventh needs a value added to `admin_audit`'s check constraint, in
the same commit as its writer.

`admin_audit` is a different table with different promises, and keeping the two
apart is the design:

| | `error_reports` | `admin_audit` |
|---|---|---|
| Answers | why did this fail? | who did this, and when? |
| Lifetime | 30 days, pruned | permanent, append-only |
| Written by | the app, from anywhere | the server only |
| Volume | high, throttled, deduplicated | one row per real action |
| A lost row is | annoying | unacceptable |

So: **never write an audit row from the client, and never put an audit fact in
`error_reports`.** No client role has INSERT on `admin_audit` and none should get
one — a log its own subject can edit is not a log. Write it from either:

- a `security definer` **trigger**, when the action is an ordinary RLS-governed
  write (this is how `settings_changed` works — see
  `20260827130100_audit_settings_changes.sql`, which also explains why a trigger
  beat the Edge Function here); or
- `supabase/functions/admin-users/index.ts`, when the action already needs the
  service-role key.

Prefer the trigger where there is a choice. It runs inside the same transaction
as the change, so it cannot record something that rolled back or miss something
that committed — and it catches every writer, including a hand-run `UPDATE` in
the SQL editor.

Audit rows record **what changed**, not the content that changed. Booleans and
numbers go in as `from`/`to`; long text goes in as lengths. Version history is a
different problem and this is not the table for it — that is why a guidelines
edit is logged as two lengths rather than two paragraphs.

**The one exception, and the test that distinguishes it:** text goes in whole
when it *is* the decision rather than the object of the decision, and when
nothing else will keep it. A rejection reason qualifies on both counts — it is
the moderator's judgement, and `songs.rejection_reason` is nulled the moment the
song leaves `rejected`, so a length would preserve nothing anybody could act on.
The guidelines qualify on neither: they are what was edited, and they are still
sitting in `app_settings` afterwards. Ask both questions before writing prose
into this table, and never write a contribution's payload into it at all.

### 3. Both come with tests

A diagnostic event gets a Dart test asserting the row's shape — the event, the
build number, and that no content leaked into `details`. An audit row gets a
pgTAP test in `supabase/tests/` asserting that the row is written, that a
**refused** or no-op change writes nothing, and that the actor still cannot edit
it.

## Working rules for this repo

- **`master` is the only branch, and pushing it deploys to GitHub Pages.** Never
  push without being asked. Work in a worktree under
  `../songbook-app-worktrees/`.
- **Never `git add -A`.** Another session writes to this working tree. Stage
  explicit paths.
- **Never run `dart format`.** SDK 3.9's tall style reformats every file it
  touches and buries the real diff. Format by hand.
- **`git status` lies here** — it lists unchanged files as ` M`. `git diff
  --numstat` is the authority.
- A new ARB key needs `cd songbook_app && flutter gen-l10n` before `analyze`
  passes, and every user-visible string goes in all three of
  `app_{en,hu,ro}.arb` or a guard test fails. **Diagnostics need no strings** —
  they are silent by design, which is one reason they are cheap to add.

## Verify

```bash
cd songbook_app && flutter analyze --no-fatal-infos
cd songbook_app && flutter test
python -m unittest discover -s tools -p "test_*.py"
npx supabase test db                 # needs Docker
```
