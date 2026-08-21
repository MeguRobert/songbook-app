# Browser smoke walk

Every serious bug in this app so far was found by driving a browser, and none of
them by `flutter test`. That is not a gap the widget suite can close: it cannot see
translated layout (it substitutes a font whose every glyph is a full em), it cannot
see the service worker, and `pumpAndSettle` hides timing seams that real frames
expose. This directory exists so the technique that actually works stops being
prose someone has to re-derive each session.

It is a **smoke walk, not a test suite.** It checks that the seams are connected
— a link opens a song, the sheet opens, the voice picker offers what it should,
the way out survives — and it takes screenshots so a human can look at the
engraving. It asserts nothing about pixels: a pixel assertion on a Bravura glyph
is a test of the font.

## Running it

```bash
# 1. Build. Two things matter here.
#
#    --no-web-resources-cdn is REQUIRED, and is what CI uses. Without it Flutter
#    loads canvaskit from gstatic.com, which this app's own Content-Security-Policy
#    blocks on purpose (web/index.html) — so the app never boots, and the walk
#    reports twenty failures that look like broken features. It now detects that
#    case and says so, but build it right and the question does not arise.
#
#    And it MUST run from songbook_app/ — from the repo root it fails while
#    leaving the PREVIOUS build in place, which then serves happily and you
#    verify hours-old code. Check the timestamp.
cd songbook_app && flutter build web --release --no-web-resources-cdn   && ls -l build/web/main.dart.js

# 2. Serve it. Any static server; this one survives the shell.
powershell -c "Start-Process python -ArgumentList '-m','http.server','8795','--directory','<abs>/songbook_app/build/web' -WindowStyle Hidden"

# 3. Walk it. Needs playwright on NODE_PATH (npm i -g playwright).
node tools/browser-smoke/smoke.js
node tools/browser-smoke/smoke.js --locale en --width 412   # another language/size
node tools/browser-smoke/smoke.js --keep-open               # leave the browser up
```

Exit code is 0 only if every check passed **and** the page logged no uncaught
error. Screenshots land in `tools/browser-smoke/shots/` (gitignored).

**Check 360 px and Hungarian.** That is the default for a reason: Hungarian runs
longer than English and has broken this app's layout twice — once the VIEW chip
row, once the AUTO-SCROLL header, both invisible to the suite.

## Why each awkward step is there

- **Service workers are unregistered and caches deleted** before loading. A
  `?cachebust=` query is not enough; Flutter's worker will serve the old build.
- **The semantics tree is enabled** by clicking `flt-semantics-placeholder`, which
  turns the canvas into a real accessibility DOM. The alternative is clicking by
  coordinate, which passes against broken code as happily as against working code.
- **The tree is polled until it stops changing** after every navigation. It lags a
  beat, so one snapshot taken straight after a tap finds almost nothing.
- **Labels are matched exactly — but per part of a merged label.** A substring
  match finds the whole app bar and proves nothing. Flutter does, however, merge a
  compound row into one node: a notation-editor bar header arrives as a single
  label reading `1. ütem\n4 / 4 ütés`. So `hasLabel` matches the whole label *or*
  any one of its newline-separated parts, exactly. Matching the whole label only
  reported working rows as broken.
- **Anything below the fold must be scrolled to first.** The semantics tree carries
  only what is laid out, so asking for an off-screen section reports it missing.
  That bit twice: the controls sheet opens at 72% of the screen so VOICE starts
  under the fold, and the editor's OTHER VOICES section sits after every verse. A
  click on an off-screen chip also lands outside its clip and quietly misses.
- **Interface strings live in `WORDS` in the script**, not read from the ARBs. A
  typo shared between the app and its own test is invisible; this way a changed
  translation is noticed. It earns its keep — it caught that the English view chip
  reads `Sheet` while the settings row for the same view reads `Sheet Music`.

**Overflow is measured, not reported.** A **release** build emits no `RenderFlex`
overflow at all: both the assertion and the yellow stripe are debug-only. So
`overflowing()` reads the semantics bounding boxes and flags anything reaching past
the viewport — which is also closer to the real question, since a label can be
clipped or ellipsized without any RenderFlex complaining. Run it at every width you
care about; `--width 360` is the one that has actually broken.

Two things this cannot do, both from the same cause — a headless browser renders
at roughly 1.3 fps here:

- **Anything timing-based is misleading.** It once made a correct `dt` clamp look
  like a 20× slowdown.
- **A mouse drag cannot test a scrollable.** Flutter excludes
  `PointerDeviceKind.mouse` from a scrollable's drag devices on web, so a
  mouse-drag "test" passes against broken code. Use CDP
  `Input.dispatchTouchEvent` after `Emulation.setTouchEmulationEnabled`, or wheel
  events as this script does.

## The fixture

`fixtures/satb.json` is one four-part song as the app stores it, so the walk has a
score with more than one voice to engrave. It was **produced by running the real
`MusicXmlImporter`**, not written by hand — a hand-built fixture is free to
disagree with what an import actually produces, and then the walk verifies a shape
the app never sees.

To regenerate it, put a throwaway test under `songbook_app/test/`, build the
MusicXML you want, run the importer on it, and print the stored form:

```dart
final result = const MusicXmlImporter().importXml(xml);
final song = Song(
  number: 900,
  title: result.title ?? 'x',
  originalKey: result.key ?? 'C',
  verses: result.verses,
  notation: result.notation,
  explicitId: const SongId.user('satb-check'),
);
print(jsonEncode([song.toJson()]));
```

Then delete the test. The `user:satch-check` id is what the walk deep-links to, so
keep it if you regenerate.

The current fixture is deliberately awkward in the ways that matter to layout:
soprano and alto in quarters, tenor and bass in halves (so a shared horizontal
grid has something to reconcile), lyrics on the soprano only, a closing repeat,
and two volta endings.
