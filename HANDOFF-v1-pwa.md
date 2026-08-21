# Handoff — V1 PWA (local storage): localisation done, import deepened

_Updated 2026-07-30. Uncommitted by design._
_Scope: the shipping local-storage PWA only. Platform/backend decisions live in
`HANDOFF-platform.md` — do not mix the two streams._

## Where we are

Songbook is a Flutter PWA with a bundled hymnal, deployed to GitHub Pages, used by one
person (Robert) on his phone. **Localisation is finished** and **the import path went
four steps deeper** — repeats and voltas, per-voice reading of a four-part score, system
spacing, and the Python OMR pipeline. Everything below is live.

- **Live:** https://megurobert.github.io/songbook-app/ — **build 199**, tag `build-199`
- **Repo:** `C:\Users\rober\source\repos\songbook-app` (Flutter app in `songbook_app/`,
  Python import tooling in `tools/`)
- **Branch:** `master`, **pushed and deployed. Nothing local.**
- **Suite:** **860** Dart tests + **76** Python tests green. `flutter analyze
  --no-fatal-infos` exits **0** with **exactly 8** issues, all pre-existing
  `RadioListTile` deprecation *infos* in `settings_screen.dart`. Treat 8 + exit 0 as the
  baseline, and check the **exit code** rather than the count — a warning fails CI and
  piping to `tail` hides it.

## Done this session (all live at build 199)

**Localisation is complete.** 228 keys in each of `app_{en,hu,ro}.arb`, and **21 files**
claimed in `_localised`. Every screen: notation editor, settings, setlists, import, tag
editor, filter sheets, presentation mode, both sheet-music views, the chords view and the
router's 404.

- Three of those files were **not** on the previous handoff's list of what was left —
  `chord_view`, the legacy `sheet_music_view`, and `app_router`. All three are surfaces a
  singer sees, and nothing failed, because the leftover-English guard only ever looks
  where it is told to. **So the list itself is now guarded**: a second test in
  `no_hardcoded_strings_test.dart` sweeps `lib/` and fails on interface text in any file
  *not* claimed. Verified by dropping an untranslated `Text` into `lib/` and watching it
  fail. That test is the reason to trust the claim now.

**Repeats and volta brackets, imported and engraved.** `MusicXmlImporter` had no
`<barline>` case at all, so every repeat sign in an imported score was dropped — while
`NotatedMeasure.repeatEnd` had existed all along and the painter already drew it.
`NotatedMeasure.volta` is new: an `int?` on every bar the bracket covers rather than a
span, so a bracket crossing a line break comes out as two half-brackets with hooks only
at the real ends. The layout engine's `repeatStart` was previously **unreachable** — it
hard-coded the default on every bar line it built.

**A four-part score keeps its other voices.** `additionalVoices` was recovered on import
and then thrown away, so reading a bass line meant re-importing the file.
`SongNotation.voices` stores them; a **VOICE / SZÓLAM** section in the controls sheet
engraves any one in place of the melody. Three voices under a melody are named
Alto/Tenor/Bass; any other count keeps the file's own labels.

**System spacing follows content.** The advance between systems was a fixed sum assuming
exactly one lyric row — too much for an engraved score with no `<lyric>` elements (the
large gaps on `SÉ-90`), too little for three verses stacked under the notes.
`StaffSystem.contentBottom` derives it. Unchanged to the pixel for every bundled song.

**The Python OMR pipeline.** `parse_musicxml` walked `.//note` and appended every one to
one flat list, so an SATB page came out as all four voices interleaved. It now applies the
same reduction rule as the Dart importer, so the two paths agree. `song_validator` looks
inside `notation` for the first time and names bars that do not add up. New opt-in
`--rebar` splits over-long measures at the signature boundary.

- **Measured on the real `SÉ-90` Audiveris output:** Audiveris returns **one measure per
  system** — six measures of 18 beats each in 4/4. **0 of 6** bars added up before;
  **22 of 29** do after `--rebar`, with the 68-note stream byte-identical. The remaining
  7 are two-beat remainders (18 is not a multiple of 4, so durations were mis-read too),
  and the validator now names exactly those.

**Bugs found on the way, all fixed:**

1. `NotationEditor` rebuilt each edited measure field by field, so **`isPickup` and
   `volta` were lost on every beat edit** — correcting one note in an upbeat bar came back
   flagged as a damaged bar, the exact thing `isPickup` exists to prevent. Now `copyWith`.
2. `StaffSystem` had the same shape of hole in the width-normalisation pass; it got a
   `copyWith` before it could drop `voltas`.
3. Switching voices **dropped the repeats, voltas and line breaks** — they belong to the
   *bar*, not the line singing it. Found in a browser, not by the suite.
4. The Hungarian AUTO-SCROLL header was **truncated at 360 px**. Now `GÖRGETÉS` +
   `csak akkord nézetben`, and `DERULARE` + `doar cu acorduri` for the same reason.
5. **Hungarian capo wording was wrong** — see the native-speaker section below. `fogás`
   was doing duty for both the fret and the chord shape.
6. Two preview tests reported a missing `ChordView` that was **built and correct**: the
   new expander row pushed the preview below the fold, and every `find.*` skips offstage
   widgets by default. They scroll to it now — the same trap as the voice chip.

**And the one framing decision that was outstanding:** MusicXML import is **demoted behind
a "More ways to add" expander**, collapsed by default, with a line saying it is the only
path that brings in engraved notation. Paste now reads as the primary path, which is what
almost every import actually is.

## Verified in a browser (Hungarian, 360 px)

Settings, song view, the controls sheet, and the engraved staff — on both a bundled hymn
and an injected four-part score with a repeat and two endings. The VIEW chip row
(Kotta/Akkord/Szöveg) and the SZÓLAM row (Dallam/Alt/Tenor/Basszus) each fit one line.
Repeats and voltas render correctly on the melody *and* on the bass.

## In-flight (uncommitted)

**None of mine.** `backlog.md` carries an edit belonging to the *platform* stream — leave
it for that session.

## Blocked / Known issues

- **Nothing is blocking forward progress.**
- **Simultaneous four-staff SATB engraving is NOT done**, and is the one thing a reader
  might expect from "choral support". It needs **horizontal spacing computed across all
  voices at once**: the layout engine spaces each measure from its own notes, so soprano
  and bass bar lines would land at different x and the score would read as *wrong* rather
  than as unfinished. This session's work is the prerequisite — the data is no longer
  destroyed on import, and any single voice is readable.
- **Importer and parser warnings are still English.** `ChordSheetParser` and
  `MusicXmlImporter` are pure domain services with no `BuildContext`; they build their own
  prose. Translating them means structured codes plus a presentation-layer formatter —
  about 40 messages and their tests. Marked with comments at both call sites.
- **Audiveris's own barline and duration accuracy** is untouched and not fixable from
  here. `--rebar` mitigates the barline half.
- **One open decision, asked three times and unanswered. Harmless either way:**
  1. `SongNotation.pickup` — delete the dead field, or keep it documented as superseded?
     Provably never written. Its editor notice is now translated into three languages
     despite being unreachable, which is the cost of leaving it.
  2. ~~**MusicXML import's framing**~~ — **decided 2026-07-30: demoted.** It is behind a
     "More ways to add" expander, collapsed by default, with a line saying it is the only
     path that brings in engraved notation.
- **The browser URL never changes as you navigate.** `main.dart` never calls
  `usePathUrlStrategy()`. On GitHub Pages path URLs also need a 404 fallback, so hash
  routing may be the safer fix. (Note: the URL *did* show `#/settings` during this
  session's verification, so router-driven hash updates partly work — worth a look.)
- **A cross-widget selection copies without line breaks.** Flutter's own fragment joining.
- **The test suite does not cover integration seams.** Two of this session's four bugs were
  found by driving a browser; the suite could not have seen either.
- **Stale branches:** `claude/poc-recent-songs` (local + remote) is for a feature that no
  longer exists; `claude/phase-0-declutter` is merged. Both are clutter.

## Native-speaker review: started, not finished

Robert read the Hungarian on 2026-07-30 and found three things in the first pass, which is
the rate to expect from the rest:

- **`kapodaszter` → `capo`.** A real dictionary word (via German *Kapodaster*) that a
  Hungarian guitarist did not recognise. Players say "capo".
- **`fogás` was used for two different things.** It is the **chord shape**; the **fret** is
  a **`bund`** (from German *Bund*). So `capoClamp` read as "put it on the 1st grip, with A
  grips". Fixed: fret → bund, shape → fogás.
- **`kerülljön` → `kerüljön`.** Plain typo.

**Still unread**, and these are the ones most likely to be wrong the same way — borrowed or
invented where a real term exists: **Énekrendek** (setlists), **Kottajavítás** (notation
editor), **felütés** (pickup/anacrusis), **Ütés** (used for "beat" throughout the notation
editor — check this one, "ütés" may be a stroke rather than a beat; "leütés" or "hang"
could be righter), the note values (**egész/fél/negyed/nyolcad/tizenhatod**), the
accidentals (**feloldójel/kereszt/bé**), **Módosítójel** (accidental), **Hangérték** (note
value), and the seven speed names. **Romanian has had no read at all.**

## Remaining work (ordered — pick from these)

1. **Finish the native-speaker read** — see the section above for what is done and what is
   still unread. Three errors in the first pass over the capo section alone, so the rest is
   worth the same attention. Romanian has had none.
2. **Full four-staff SATB engraving** (see Blocked for what it needs).
3. **Phase 6 store submission** — the genuinely unfinished v1.0 work: final icon/splash
   art, release signing, on-device crash + a11y UAT, screenshots, store listing.
4. **Localise the importer/parser warnings** via structured codes (see Blocked).
5. **Decide `SongNotation.pickup`** and **MusicXML's framing** (see Blocked).
6. **The URL / deep-link bug**, if bookmarking or sharing matters.
7. **Phases 10–12** (v2.0): Cloud Backend, Custom Songbooks & Sharing, Scale & Quality.
8. **Housekeeping:** delete the two stale branches; `.planning/ROADMAP.md` Phase 4
   criterion 3 mentions the removed "Custom" view option; migrate the 8 `RadioListTile`
   deprecations in `settings_screen.dart` to `RadioGroup` to take the analyze baseline
   to 0.

**Smaller things, none blocking:**

- `NotatedVerse` and `SongNotation` still have no `copyWith`. `NotatedMeasure` and
  `StaffSystem` both got one this session after exactly that cost a field.
- The notation editor cannot add or remove a whole *measure*, only beats within one —
  which is what makes a mis-barred OMR import hard to fix by hand, and why `--rebar`
  exists on the Python side.
- The notation editor does not show or edit repeats, voltas or the voice list. It
  preserves them; it cannot change them.

## Files / commands reference

```bash
# verify — from songbook_app/
flutter test                                    # expect 860 passing
flutter analyze --no-fatal-infos; echo $?       # expect exit 0, "8 issues found"
flutter gen-l10n                                # after any ARB change
cd ../tools && python -m unittest test_song_validator test_batch_import test_convert_hymn
                                                # expect 76 passing

# CI runs `flutter analyze --no-fatal-infos`, which downgrades INFOS ONLY. A warning
# (an unused import) still fails the deploy. Check the EXIT CODE.

# release build + local serve. RUN FROM songbook_app/ — from the repo root it fails
# with "No pubspec.yaml found" while leaving the PREVIOUS build in place, which then
# serves happily and you verify hours-old code. Check the timestamp.
cd songbook_app && flutter build web --release
ls -l build/web/main.dart.js
powershell -c "Start-Process python -ArgumentList '-m','http.server','8777','--directory','C:/Users/rober/source/repos/songbook-app/songbook_app/build/web' -WindowStyle Hidden"

# gh as MeguRobert (the global gh is the binhatch account)
export GH_CONFIG_DIR="$HOME/.config/gh-meguRobert"
gh run list --limit 1
gh run watch <id> --exit-status
curl -s https://megurobert.github.io/songbook-app/version.json

# the old repo's vetted HU/RO translations
gh api repos/MeguRobert/Songbook/contents/lib/constants.dart --jq '.content' | base64 -d

# the OMR pipeline, including the new flag
cd tools && python convert_hymn.py --from-xml audiveris_output/zsolt-090.width-800.xml \
  --song 90 --rebar --no-update
```

**Key source files**

- `lib/l10n/app_{en,hu,ro}.arb` + `l10n.yaml` — 228 keys; generated output is committed
  at `lib/l10n/app_localizations*.dart`
- `test/l10n/no_hardcoded_strings_test.dart` — **two guards**: English left on a claimed
  file, AND interface text in a file that is not claimed. `_localised` is the claim.
- `test/l10n/translations_test.dart` — ARB drift guards. `sameOnPurpose` names the keys
  whose Hungarian legitimately equals the English (`voiceTenor` — "Tenor" is the
  Hungarian word).
- `lib/data/models/notation.dart` — `NotatedMeasure.volta`, `NotatedVoice`,
  `SongNotation.voices`, and **`engravedAs`**, whose doc explains why it must be applied
  to the STORED notation and never chained
- `lib/domain/services/musicxml_importer.dart` — the melody reduction rule, `_readBarline`,
  `_applyBarlines`, `_storedVoices`
- `lib/presentation/widgets/sheet_music/sheet_music_layout.dart` — `PositionedVolta`,
  `StaffSystem.contentBottom`, `_layoutVoltas`, `StaffSystem.copyWith`
- `lib/presentation/widgets/sheet_music/sheet_music_painter.dart` —
  `_drawRepeatBarLine` (both directions on one line, for `:‖:`), `_drawVoltas`
- `tools/convert_hymn.py` — `parse_musicxml_string` (testable without a file),
  `_melody_beats`, `_read_barline`, `rebar_measures`
- `tools/song_validator.py` — `_validate_notation`, the beat arithmetic
- `docs/plans/2026-07-27-song-import-and-editor-design.md` — design and rationale

**Browser verification — read this before trusting any UI check**

- **Enable Flutter's semantics tree and stop clicking by coordinate:**
  `document.querySelector('flt-semantics-placeholder,[aria-label="Enable accessibility"]').click()`
  The whole app becomes a real accessibility DOM that Playwright drives by role and label.
  **Take a fresh snapshot after each navigation** — the tree lags a beat, and a
  `querySelectorAll('flt-semantics')` sweep run too early finds almost nothing. Use the
  MCP `browser_snapshot` rather than hand-rolled DOM queries; it reads the tree properly.
- Flutter's **service worker caches aggressively**; `?cachebust=` is not enough:
  `for (const r of await navigator.serviceWorker.getRegistrations()) await r.unregister();`
  `for (const k of await caches.keys()) await caches.delete(k);`
- **To set up state, write `localStorage` directly.** `shared_preferences` on web stores
  under `flutter.<key>`, and the value is the JSON string *itself* JSON-encoded:
  `localStorage.setItem('flutter.user_songs', JSON.stringify(jsonString))`. **Generate the
  payload by printing `jsonEncode([song.toJson()])` from a throwaway test** — this session
  built the four-part fixture by running the real `MusicXmlImporter` in one, so the fixture
  could not disagree with what an import actually produces. Serve it from `build/web/` and
  `fetch` it, rather than pasting 6 KB through `browser_evaluate`. The locale override
  lives at `flutter.settings_locale`.
- **A bottom sheet's lower sections are below the fold.** `tester.tap` and a raw click do
  not check visibility — they hit the widget's centre coordinates, which for an off-screen
  chip land outside the sheet's clip, so the hit test quietly misses and the assertion
  fails with the picker looking fine. Use `tester.ensureVisible` in a test; scroll with
  wheel events in a browser.
- **Check translated layout at 360 px.** Hungarian runs longer than English. It re-broke
  the VIEW chip row once, and this session it truncated the AUTO-SCROLL header. No test can
  see this: widget tests substitute a font whose every glyph is a full em.
- After adding a **plugin**, run `flutter clean`.

## Recurring gotchas

- **`rootBundle.loadString` never completes inside `testWidgets`.** Use
  `makeAppContainer()`, which stubs *only* the bundled catalogue.
- **A field-by-field rebuild silently drops the next field added to the model.** This has
  now cost `isPickup` twice (importer, then editor) and nearly cost `voltas`.
  `NotatedMeasure`, `NotatedBeat` and `StaffSystem` all have `copyWith` for this reason —
  **use it** unless you specifically need the other side to win, in which case spell every
  field out (see `engravedAs`) because `copyWith(x: null)` cannot clear a value.
- **A timestamp is not an id.** Every generated id needs a random component.
- **A pattern-based string replacement misses cases silently.** Always follow with the
  guard test, never a visual skim.
- **`flutter analyze` info-level findings can be real bugs.** `contains`/`containsKey`/
  `indexOf` take `Object?`.
- **A new test file can move the analyze baseline.** A `prefer_null_aware_operators` info
  in a test took it from 8 to 9 this session. Check the count as well as the exit code.
- **Renaming a field renames its JSON key**, which destroyed stored favourites and setlists
  on upgrade until `JsonKey.readValue` fallbacks were added. `SongNotation.voices` is
  additive and nullable for exactly this reason, with a test that pre-`voices` payloads
  still decode.
- **VM tests cannot catch dart2js divergence.**
- **Check a new value type's `==` and `hashCode` cover its mutable fields**, lists included.
- **Do not reflexively `git checkout --` a file.** This session's `convert_hymn.py` rewrite
  was uncommitted and got reverted that way; it survived only because the new code had been
  staged through scratchpad files. Commit before running any destructive git command.
- **A premise about a file format can be wrong.** Refusing every XML `DOCTYPE` as a
  billion-laughs guard rejected the entire contents of `audiveris_output/` — the standard
  external MusicXML DTD reference is exactly what Audiveris and MuseScore emit. Only the
  *internal entity subset* is refused now. Test against the real files in the repo.

## Resume prompt

```
Continue the Songbook V1 PWA. Use the superpowers:test-driven-development skill for new
features.

Repo: C:\Users\rober\source\repos\songbook-app  (branch master).
Read the full handoff first: C:\Users\rober\source\repos\songbook-app\HANDOFF-v1-pwa.md

Live at build 199, everything pushed, nothing local. 860 Dart + 76 Python tests green;
flutter analyze --no-fatal-infos exits 0 with exactly 8 pre-existing RadioListTile infos.

Done: localisation is FINISHED (228 keys, 21 files, both directions guarded by tests), and
the import path went four steps deeper — repeat signs and volta brackets, per-voice
reading of a four-part score, content-driven system spacing, and the Python OMR pipeline
(melody reduction, notation validation, opt-in --rebar; 0 of 6 bars added up on the real
SÉ-90 output before, 22 of 29 after).

Pick the next item from "Remaining work" in the handoff. The top one is getting the
Hungarian and Romanian read by a native speaker — 228 keys, mostly machine-produced, with
the church and music terminology listed in the handoff. The biggest code item is full
four-staff SATB engraving, which needs horizontal spacing computed across all voices at
once; the handoff explains why that was deliberately not half-done.

Caveats: after localising any file, add it to `_localised` in
test/l10n/no_hardcoded_strings_test.dart and run that test — and note the second test in
that file now also fails if a file with interface text is NOT claimed. Check translated
layout at 360px in a browser; Hungarian has broken layout twice. Use copyWith when
rebuilding a model object — a field-by-field rebuild has silently dropped isPickup twice.
Do NOT touch backlog.md — it belongs to HANDOFF-platform.md.
```
