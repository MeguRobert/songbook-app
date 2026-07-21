---
phase: 04-controls-ui-redesign
plan: 05
type: execute
status: complete
completed: 2026-07-21
commits:
  - bf49fa8: remove InteractiveViewer wrappers so pinch reaches text-scale gesture
  - b61899e: add viewport meta tag to suppress native browser pinch-zoom
  - a6bb140: handle PointerScaleEvent so pinch-to-zoom works on web
files_modified:
  - songbook_app/lib/presentation/screens/song_view/widgets/chord_view.dart
  - songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart
  - songbook_app/web/index.html
  - songbook_app/lib/presentation/screens/song_view/song_view_screen.dart
---

# Plan 04-05 Summary: Pinch-to-zoom fix

## What was built

Closed UAT Test 6: pinch-to-zoom now drives the text-size setting (`setTextScale`,
clamped 50–200%) instead of geometric image zoom, and works across Chords, Lyrics,
and Sheet Music views.

**Task 1** — Removed the `InteractiveViewer` wrappers from `chord_view.dart` and the
legacy SVG path in `sheet_music_view.dart` (replaced with `SingleChildScrollView`
for vertical scrolling). This freed the gesture arena so the screen-level scale
gesture is no longer stolen by a matrix-transform zoom.

**Task 2** — Added a viewport meta tag to `web/index.html`
(`user-scalable=no`) to suppress native mobile-browser page pinch-zoom.

**Checkpoint follow-up (the real fix)** — Human verification failed: pinch still did
nothing on desktop. Root-caused via instrumentation + Playwright (see below) and
added the missing handler.

## Checkpoint outcome: FAILED → diagnosed → fixed

Tasks 1–2 were necessary but **not sufficient**. The original diagnosis (debug
session `pinch-zoom-wrong-behavior.md`) missed a second, decisive cause specific to
Flutter **web**:

- **Root cause:** A desktop trackpad pinch (and Ctrl+mouse-wheel) is delivered by
  Chrome as `ctrl+wheel`, which Flutter's web engine converts into a
  `PointerScaleEvent` — a *pointer signal*, like scroll. `GestureDetector` /
  `ScaleGestureRecognizer` do **not** receive pointer-signal scale events (only
  touch pointers and trackpad pan-zoom), so `onScaleUpdate` never fired on desktop
  web. Removing the InteractiveViewer freed the arena but couldn't help, because the
  gesture never entered the arena.
- **Evidence (instrumented build + Playwright):** dispatching `ctrl+wheel` produced
  `Listener.onPointerSignal → _TransformedPointerScaleEvent` × N while
  `onScaleStart`/`onScaleUpdate` stayed at 0. A synthetic 2-finger touch pinch, by
  contrast, fired `onScaleUpdate` (scale 1.0 → 1.89) and scaled the notation — so
  the touch/mobile path already worked and the notation already honored textScale
  (from plan 04-04).
- **Fix (commit a6bb140):** wrap the body in `Listener(onPointerSignal:)` that maps
  `PointerScaleEvent` to `setTextScale(current * event.scale)`. The existing
  `GestureDetector` scale handler is kept for multi-touch pinch on mobile. Bonus:
  Ctrl+mouse-wheel now zooms text for mouse-only users.

## Verification

- `flutter analyze`: clean (only 8 pre-existing RadioListTile deprecation infos).
- `flutter test`: all 364 tests pass.
- Browser (Playwright, Flutter web build):
  - Song 42 Sheet Music: `ctrl+wheel` pinch-out enlarged notation; pinch-in shrank
    it (clamped). Previously did nothing. **Confirmed.**
  - Touch 2-finger pinch: scales notation (`scale→1.89`). **Confirmed.**
- Not yet confirmed on a physical touch device by the user (automation covered the
  desktop ctrl+wheel path and synthetic touch path).

## Post-verification refinement: smooth uniform zoom (user-confirmed)

After the pinch fix landed, the user reported the notation zoomed in "chunks" and
wasn't a "customizable size," wanting the continuous feel of a trackpad pinch.
Instrumentation (Playwright + a setTextScale log) showed a single Ctrl+wheel notch
triggered ~100 notation rebuilds, each re-running the full layout engine — because
04-04 laid out at `availableWidth / textScale`, so every zoom step re-wrapped the
music onto fewer measures per line. That re-wrap was the "chunk"; the relayout flood
was the jank.

Two earlier attempts (per-notch step clamp `453882b`, per-notch eased animation
`8ad2dc7`) treated the symptom. The user chose (AskUserQuestion) the architectural
fix — **smooth uniform zoom** (`4e8031b`):
- Lay the engraving out ONCE at the viewport width (independent of textScale) and
  memoize it (recompute only on width/notation/transpose/showChords).
- Apply zoom purely as a visual scale (canvas.scale + scaled SizedBox) — no relayout
  or re-wrap per step, so it's continuous to any size and jank-free.
- Added horizontal scrolling so the enlarged sheet can be panned when it exceeds the
  viewport.
- **Accepted trade-off:** when zoomed past the screen width, the sheet scrolls
  horizontally (like zooming a PDF) instead of re-fitting to the width.

The Ctrl+wheel per-notch eased animation (`8ad2dc7`) is retained and now glides
cheaply since zoom no longer relayouts. User confirmed the result is good.

## Known limitation (pre-existing, out of scope)

For a song with **no** engraved notation shown in the notation/placeholder view
(e.g. song 1, "No sheet music available"), the plain-text verses in that legacy
path do not honor `textScale` — plan 04-04 wired textScale only into the custom
Canvas renderer. Chords/Lyrics presets scale correctly. Worth a follow-up if
scaling the placeholder-view plain text is desired.
