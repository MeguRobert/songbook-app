# Handoff — SATB engraving, URLs, localised import notices, editor measure ops

_Written 2026-07-31. Uncommitted by design._
_Scope: an autonomous session working the "Remaining work" list in
`HANDOFF-v1-pwa.md`. Nothing here touches the platform/Firebase stream._

## Where we are

**`master` is untouched.** All work is on branches, in worktrees under
`C:\Users\rober\source\repos\songbook-app-worktrees\`. Nothing is deployed; the
live site is still whatever `master` last built.

| Branch | Worktree | State |
|---|---|---|
| `claude/autonomous-enhance` | `autonomous-enhance` | **pushed to origin.** 929 tests, analyze exit 0 / 0 issues. Two files uncommitted — see below |
| `claude/ae-notation-editor` | `ae-notation-editor` | 3 commits verified green at `d878b51`. **Half-edited tree** — see below |
| `claude/v1-polish` | `v1-polish` | merged into the above (analyze baseline 8 → 0) |
| `claude/ae-l10n-warnings`, `claude/ae-deeplinks` | (worktrees) | merged into `claude/autonomous-enhance`; deletable |

The session ended on an **external block**, not on a decision: the harness's
command-safety classifier went down and refused every write and shell call for an
extended period. Two things are finished-but-uncommitted purely because of that.

## Done, on `claude/autonomous-enhance` (pushed)

**Four-staff SATB engraving** — the biggest item on the previous handoff's list,
and the one it deliberately did not half-do. The reason it gave was right: the
layout engine spaces each measure from its own notes, so calling it once per voice
puts the soprano's bar lines and the bass's at different x, and a score whose bar
lines do not line up reads as *wrong* rather than as unfinished.

- Horizontal positions are now solved for all voices together. The grid for a bar
  is the union of the moments any voice starts a note, keyed in **64ths** — not
  beats — because accumulating doubles and comparing them for equality is exactly
  how a dotted-rhythm voice quietly drifts out of alignment. Widths are solved as
  **constraints, shortest span first**, so a bass half note over two soprano
  quarters is at least as wide as a half note *in total* without forcing either
  quarter wider.
- **One bar line serves the group**, top staff's top line to bottom staff's bottom.
  That broke the repeat dots — the line's `topY` is now the top of the *group*, so
  all four pairs landed in the soprano staff. `PositionedBarLine.repeatDotStaffTops`
  carries an anchor per staff; `dotAnchors` falls back to `topY`, so the
  single-staff path is untouched.
- **Clefs come from the notes, not the part names**: whichever staff's middle the
  voice's median pitch is nearer. Handles a two- or five-voice score, and an SATB
  file whose parts are named in Hungarian. Read from **stored** pitches so the clef
  does not flip halfway through transposing.
- `StaffClef` holds the entire treble/bass difference as three constants: 12
  diatonic steps for pitches, 2 half-positions for key-signature accidentals, and
  which line the glyph hangs from. That last one matters — a music font draws a clef
  from its baseline, and the baseline *is* the reference line, so the existing
  0.58-of-height offset puts the F clef's dots on the F line with no per-glyph fudge.
- `StaffSystem.systemIndex` is **not** the index in `systems` any more: four voices
  on one line share one index. The painter draws the time signature on the first
  *line*, so without this three of four staves would silently have lost theirs.
- Reachable as one more chip on the existing VOICE picker (`All` / `Mind` /
  `Toate`), last in the row because it is the odd one out. `SongNotation.allVoices`
  is `-1`, and is deliberately *not* a projection — the grand staff needs `verses`
  as the top line and `voices` as the rest.

**Importer and parser warnings are localised** (was item 4). 17 `ImportNoticeCode`
values plus a presentation-layer formatter; ARBs went 228 → 245 keys × 3. The
agent added a **third guard** to `no_hardcoded_strings_test.dart` sweeping for
`warnings.add('…')` — neither existing guard could ever have caught these, since
both only look inside widget slots, which is how they survived every earlier pass.

**The URL bug — and the handoff's premise for it was wrong.** Not
`usePathUrlStrategy`. go_router's `optionURLReflectsImperativeAPIs` **defaults to
`false`**, so `context.go` (the bottom nav) reached the address bar and every
`context.push` (everything else) did not — which is why the old handoff both said
"the URL never changes" and "`#/settings` appeared". Worse, the reported location
was byte-identical to the previous one, so no history entry was created either.
Now `true`. Cold-loading `/song/hymnal:151` and `/song/user:abc` already worked and
needed no encoding; that was simply untested, and now is (13 tests). **Path URLs
were considered and rejected** — a hand-written `web/404.html` is copied verbatim
rather than templated, so it needs a hard-coded base href that breaks local
serving, and the SPA shell would be served with a 404 status to a precaching
service worker. Not worth losing a `#`.

**Two bugs the suite could not see, both found in a browser:**

1. **A shared song lost its only way out.** The way out was decided per build from
   `GoRouter.canPop()` — but the controls sheet is a route on the same navigator, so
   while it is open there *is* something to pop. Tapping anything in the sheet
   rebuilds the song view inside that window and latched "not a deep link", and
   nothing rebuilt it again on close because `InheritedGoRouter` does not notify on
   navigation. Now sampled once in `didChangeDependencies`.
   **The first version of this test passed against the broken code** — it opened and
   dismissed the sheet without touching anything, which never rebuilds the screen.
   It only became a test once it tapped a preset first.
2. **Staff lines poked out past the closing bar line** — they were drawn to the
   system's full width while normalisation puts the final bar line a right margin
   short of it. A blemish with one staff; the first thing you see with four.
   `StaffSystem.staffLineEndX` names the invariant.

**A cold-loaded presentation route crashed on exit** — `Navigator.pop` with an
empty match list threw `Bad state: No element`. Fixed.

**Housekeeping.** `Song.==` is **already** full value equality over all 13 fields
plus list equality — the old `HANDOFF.md` entry calling it "live ammunition" is
stale. `.planning/ROADMAP.md` Phase 4 criterion 3 corrected (it promised the
"Custom" view option that 04-03 removed). `claude/phase-0-declutter` and
`claude/poc-recent-songs` deleted locally — git reports **every** `claude/poc-*` and
`claude/phase-*` branch as fully merged into master with zero unique commits, which
contradicts any note about POCs awaiting a ship/iterate/drop decision.

## Uncommitted on `claude/autonomous-enhance` — finished, blocked mid-commit

Working tree has, and it is all verified:

- **`tools/browser-smoke/`** — the technique that has found every real bug in this
  repo, made executable. 18 checks, non-zero exit on any page error, defaulting to
  360px Hungarian. **All 18 pass.** Every awkward step is documented as to which bug
  it exists for. Writing it caught its own first bug: a fixed 2.5 s boot wait passed
  on every page except the first, because straight after the service worker is
  unregistered the app refetches its whole bundle — it reported "the song list is
  broken" and meant "I looked too early".
- One doc comment on `_clefFor` recording why the clef reads stored pitches.

`git add -A && git commit` with the message at
`<scratchpad>/msg-smoke.txt`, then `git push`.

## `claude/ae-notation-editor` — service layer done, UI not written

Three commits, each verified green before committing:

- **`8d250b9`** — `copyWith` on `NotatedVerse`, `SongNotation`, `NotatedVoice`, and
  the live bug that exposed: `NotationEditor._editBeats` rebuilt `SongNotation`
  field by field and **omitted `voices`**, so correcting one note in a four-part
  score silently deleted its alto, tenor and bass. **Third occurrence of that exact
  bug shape** (importer/`isPickup`, editor/`isPickup`, editor/`voices`).
- **`1e3e28f`** — cold-load `context.pop()` guard, **3** call sites not 1: both
  screens' Save *and* the notation editor's discard path, which the system back
  gesture reaches even where the app bar shows no arrow.
- **`d878b51`** — `splitMeasure` / `mergeMeasureIntoPrevious` /
  `insertMeasureBefore` / `insertMeasureAfter` / `deleteMeasure` /
  `setMeasureFlags` / `renameVoice` / `removeVoice`, 54 service tests. Structural
  edits apply to the other voices too, splitting by musical **time** not beat index,
  so `engravedAs` keeps its alignment contract. A new bar holds one rest, not
  nothing — an empty bar has no row and so would be a bar you could never fill.
  Two `isPickup` guards: a split never labels its *second* half a pickup, and a
  merge drops the flag once the bar is no longer short.
  **SÉ-90 verified**: an 18-beat bar in 4/4 split four times at beat 4 →
  `[4,4,4,4,2]`, 18 beats intact, and the 2-beat remainder is correctly the only bar
  still flagged.

**Uncommitted and NOT finished:**

- 22 ARB keys × 3 languages + generated output, `gen-l10n` run, all three l10n
  guards green. No `_localised` addition needed.
- ~15 new widget tests in `notation_editor_screen_test.dart` that **have never been
  executed**, and the screen wiring they describe **does not exist**. Treat them as
  unvalidated: watch them go red before writing the UI.

The contract those tests fix: `Key('measure-menu-0-$m')` per measure header with
`Merge into previous measure` (absent on bar 0) / `Insert measure before` /
`Insert measure after` / `Delete measure` / `Measure properties`; splitting on the
**beat** menu as `Start a new measure here` (absent on beat 0);
a properties sheet with `measure-repeat-end`, a `measure-volta` dropdown
(`None` / `Ending 1` / …), `measure-pickup`, `Apply`; an `OTHER VOICES` section
hidden when the score has one line, with `voice-menu-0` → `Rename` →
`voice-name` → `Apply`.

The agent's drafted shape: `_BeatAction { edit, splitHere, insertAfter, delete }`,
`_MeasureAction { properties, insertBefore, insertAfter, merge, delete }`,
`_VoiceAction { rename, remove }`, a `_MeasureFlags` value carried out of the sheet
so it never touches `beats`; `_MeasureHeader` gains `address` / `canMerge` /
`onAction`; `_rows` appends the voices section after the verse loop.

**Highest layout risk:** `Összevonás az előző ütemmel` in a per-bar header row at
360 px. If it overflows, drop the measure menu to an icon-only `PopupMenuButton`
with labels only inside the menu, which is what the beat row already does.

## Known issues / not done

- **Nothing is deployed.** Merging `claude/autonomous-enhance` to `master` triggers
  the Pages workflow and replaces the PWA Robert sings from. The URL change is the
  highest-risk piece behaviourally, though it was browser-verified extensively.
- **Notation editor UI** — above.
- Still needs a human: **native-speaker review of HU/RO** (now 245 + 22 keys, and
  this session added `voiceAll`, 17 import notices and 22 editor strings — the
  agents' judgement calls are listed in their commit messages), **Phase 6 store
  submission**, and Robert's two long-unanswered decisions (`SongNotation.pickup`,
  MusicXML import framing).
- `ImportedVoice.label` (`P1 (Soprano) staff 2 voice 6`) still reaches the voice
  picker un-localised whenever the extra-voice count is not exactly 3. It is a
  technical id read out of the file; deliberately left.
- **Simultaneous SATB has no bracket** at the left of the group, only the systemic
  bar line. Deliberate — that is standard in choral open score — but a bracket with
  serifs would read as a group more strongly.
- The four staves are small at 360 px. Pinch-zoom covers it.

## Commands

```bash
# from songbook_app/
flutter analyze --no-fatal-infos; echo $?   # expect exit 0, "No issues found!"
flutter test                                # expect 929 on claude/autonomous-enhance
flutter gen-l10n                            # after any ARB change

# the browser walk (needs: npm i -g playwright)
cd songbook_app && flutter build web --release && ls -l build/web/main.dart.js
powershell -c "Start-Process python -ArgumentList '-m','http.server','8795','--directory','<abs>/songbook_app/build/web' -WindowStyle Hidden"
NODE_PATH=$(npm root -g) node tools/browser-smoke/smoke.js
NODE_PATH=$(npm root -g) node tools/browser-smoke/smoke.js --locale en --width 412

# gh as MeguRobert (the global gh is the binhatch account)
export GH_CONFIG_DIR="$HOME/.config/gh-meguRobert"
```

## Resume prompt

```
Continue the Songbook app. Read C:\Users\rober\source\repos\songbook-app\HANDOFF-satb-urls-editor.md first.

master is untouched. Work is on claude/autonomous-enhance (pushed, 929 tests,
analyze exit 0) in the autonomous-enhance worktree, and claude/ae-notation-editor
(3 commits green at d878b51) in the ae-notation-editor worktree.

Two things are done but uncommitted on claude/autonomous-enhance because the
harness's safety classifier went down mid-session: tools/browser-smoke/ (18 checks,
all passing) and one doc comment. Commit with <scratchpad>/msg-smoke.txt and push.

Then finish the notation editor UI on claude/ae-notation-editor. Its service layer
and localisation are done; the screen wiring is not written and its ~15 widget
tests have NEVER been run. Watch them fail first — a test that has never been
observed red is not yet a test, and this session already had one that passed
against broken code. The contract and the drafted widget shape are both in the
handoff. Then merge it into claude/autonomous-enhance, run the full suite, and
check 360px Hungarian with tools/browser-smoke.

Deploying is not done and is a judgement call: merging to master replaces the live
PWA. Ask before doing it.
```
