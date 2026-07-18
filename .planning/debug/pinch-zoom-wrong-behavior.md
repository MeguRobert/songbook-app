---
status: diagnosed
trigger: "Pinch-to-zoom on song content scales content like an image (geometric zoom) instead of adjusting the text-size setting like A-/A+; pinch does not work at all in Sheet Music view."
created: 2026-07-18T00:00:00Z
updated: 2026-07-18T00:30:00Z
---

## Current Focus

hypothesis: CONFIRMED - see Resolution
test: n/a
expecting: n/a
next_action: return diagnosis (goal: find_root_cause_only)

## Symptoms

expected: Two-finger pinch on song content changes text-size setting (same as A-/A+ in bottom sheet: reflows text, updates percentage, clamped 50%-200%), works in all views incl. Sheet Music.
actual: Pinch produces image-like geometric zoom (possibly browser/InteractiveViewer zoom) instead of text-scale change; in Sheet Music view pinch does nothing.
errors: None reported
reproduction: UAT Test 6 - flutter run -d chrome, open a song, pinch on content (or DevTools touch simulation); compare vs A+/A-. Repeat in Sheet Music view.
started: Discovered during Phase 4 UAT (Controls UI Redesign)

## Eliminated

- hypothesis: The screen-level GestureDetector applies a Transform/scale to the widget tree instead of updating the provider (implementation bug in the handler itself)
  evidence: song_view_screen.dart:91-104 - onScaleUpdate correctly calls ref.read(songViewProvider.notifier).setTextScale(_baseScale * details.scale); no Transform anywhere in the handler. setTextScale clamps to 0.5-2.0 (song_provider.dart:126-130), same range as A+/A- (song_provider.dart:106-118).
  timestamp: 2026-07-18

- hypothesis: Browser-native pinch zoom is the primary cause of the image-like zoom
  evidence: The image-like zoom is fully explained in-app by InteractiveViewer(minScale:0.5, maxScale:3.0) wrapping ChordView content (chord_view.dart:34-36). Browser zoom would also zoom the app chrome (AppBar/FAB) and would affect Sheet Music view identically, but Sheet Music shows NO zoom at all - consistent with in-app gesture arena behavior, not browser zoom. (Note: web/index.html has no viewport meta tag, so browser pinch zoom on a real mobile browser remains a possible secondary interference, but it is not the observed mechanism.)
  timestamp: 2026-07-18

## Evidence

- timestamp: 2026-07-18
  checked: song_view_screen.dart:91-130
  found: GestureDetector with onScaleStart/onScaleUpdate wraps the Scaffold body; onScaleUpdate calls setTextScale correctly. Body renders SheetMusicView OR ChordView as children. textScale is passed to ChordView (lines 115-127) but NOT to SheetMusicView (lines 108-113).
  implication: Handler wiring is correct; problem must be children swallowing the gesture, and sheet music has no textScale plumbing at all.

- timestamp: 2026-07-18
  checked: chord_view.dart:34-37
  found: ChordView build returns InteractiveViewer(minScale: 0.5, maxScale: 3.0, child: SingleChildScrollView(...)). InteractiveViewer applies a matrix transform (geometric zoom).
  implication: InteractiveViewer's internal scale recognizer is DEEPER in the tree than the screen's GestureDetector, so it wins the gesture arena and consumes the pinch, applying image-like matrix zoom. The screen's onScaleUpdate never receives the pinch. Explains symptom 1 exactly.

- timestamp: 2026-07-18
  checked: sheet_music_view.dart (SheetMusicViewWidget)
  found: For songs WITH notation (hasNotation), renders SheetMusicRenderer (custom Canvas). For legacy songs, renders its own InteractiveViewer (line 96) around SVG content.
  implication: Two different sheet-music paths; the UAT song (42) uses the Canvas renderer path.

- timestamp: 2026-07-18
  checked: sheet_music_renderer.dart:149-200
  found: SheetMusicRenderer wraps content in Scrollbar + SingleChildScrollView (no InteractiveViewer, no scale handling). CustomPaint size comes purely from layout engine.
  implication: The scrollable's vertical drag recognizer claims the pinch pointers in the gesture arena, so the ancestor GestureDetector's scale recognizer never wins -> pinch does nothing in Sheet Music view. Explains symptom 2.

- timestamp: 2026-07-18
  checked: grep textScale in lib/presentation/widgets/sheet_music/
  found: Zero matches. SheetMusicRenderer/layout/painter never consume textScale; song_view_screen also doesn't pass it.
  implication: Even if the pinch gesture DID reach the handler in Sheet Music view, setTextScale would update provider state with zero visual effect. Sheet music text-scaling is unimplemented.

- timestamp: 2026-07-18
  checked: song_provider.dart:106-130, 208-211; song_controls_sheet.dart:32,238
  found: increase/decrease/setTextScale all clamp 0.5-2.0; bottom sheet displays (textScale*100)% from textScaleProvider.
  implication: Provider path used by A+/A- is the correct target; pinch handler already targets it - only gesture delivery and sheet-music consumption are broken.

- timestamp: 2026-07-18
  checked: web/index.html
  found: No viewport meta tag (no user-scalable=no, no touch-action config).
  implication: On real mobile browsers, native page pinch-zoom could additionally interfere; worth adding viewport meta as hardening, but not the observed root cause.

## Resolution

root_cause: |
  Two independent causes, one per symptom:

  1. IMAGE-LIKE ZOOM (chords/lyrics views): ChordView wraps its content in
     InteractiveViewer(minScale: 0.5, maxScale: 3.0) (chord_view.dart:34-36).
     InteractiveViewer's own ScaleGestureRecognizer sits deeper in the widget
     tree than the screen-level GestureDetector (song_view_screen.dart:91), wins
     the gesture arena, and applies a matrix transform - geometric "image" zoom.
     The screen's onScaleUpdate (which correctly calls setTextScale) never fires.
     The legacy SVG sheet path has the same InteractiveViewer issue
     (sheet_music_view.dart:96).

  2. PINCH DEAD IN SHEET MUSIC (Canvas renderer): SheetMusicRenderer has no
     InteractiveViewer but wraps content in Scrollbar+SingleChildScrollView
     (sheet_music_renderer.dart:149-152); the scrollable's drag recognizer claims
     the pointers so the ancestor scale gesture never wins. AND even if it did,
     nothing would change: textScale is not passed to SheetMusicView
     (song_view_screen.dart:108-113) and no file under
     lib/presentation/widgets/sheet_music/ consumes textScale at all.

fix: |
  (Suggested direction only - goal is find_root_cause_only)
  - Remove InteractiveViewer from chord_view.dart (and the legacy path in
    sheet_music_view.dart) so the screen-level scale GestureDetector receives
    the pinch; keep the SingleChildScrollView for vertical scrolling.
  - Wire textScale into the sheet music path: pass it to SheetMusicView /
    SheetMusicRenderer and multiply it into the layout engine's sizing (or wrap
    canvas metrics), so pinch and A+/A- affect notation size.
  - Verify pinch vs scroll arena behavior after InteractiveViewer removal
    (scale recognizer on ancestor vs scrollable drag); if the scrollable still
    swallows two-finger gestures, use a RawGestureDetector/scale recognizer at
    the content level or gate scroll physics while 2 pointers are down.
  - Hardening: add viewport meta (user-scalable=no / interactive-widget config)
    to web/index.html to prevent native browser pinch zoom on mobile web.

verification:
files_changed: []
