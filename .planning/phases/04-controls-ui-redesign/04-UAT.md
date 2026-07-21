---
status: diagnosed
phase: 04-controls-ui-redesign
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md]
started: 2026-07-18T18:38:55Z
updated: 2026-07-18T19:55:00Z
---

## Current Test

[testing complete]

## Tests

### 1. FAB Opens Controls Sheet
expected: Song view shows a small FAB (tune icon) in bottom-right. Tapping it opens a Material bottom sheet with drag handle and three labeled sections: View, Transpose, Text Size.
result: pass

### 2. View Presets Switch Modes
expected: In the bottom sheet View section, three ChoiceChip presets are shown: Sheet Music, Chords, Lyrics. Tapping each preset immediately switches the song content to that view mode.
result: pass

### 3. Custom View with Toggles
expected: Selecting "Custom" in the View section smoothly expands to reveal two SwitchListTile toggles: "Show Notation" and "Show Chords". Toggling each independently controls what's displayed. Selecting a preset collapses the Custom toggles.
result: issue
reported: "Custom button does nothing useful. I think we can get rid of that"
severity: major

### 4. Transpose Controls in Sheet
expected: Transpose section shows - and + buttons with the current key displayed between them and a Reset button. Tapping + raises the key by one semitone, tapping - lowers it. Reset returns to original key.
result: issue
reported: "In Transpose section the reset to original button appears and by taking up space it pushes up the other things a bit, like the transpose buttons and the transpose text itself... maybe the buttons can be somehow fixed positions so the reset button not pushes them? it would enhance the UX because the user can use the transpose as a carousel and the button not repositions"
severity: minor

### 5. Text Size Controls in Sheet
expected: Text Size section shows A- and A+ buttons with a percentage display (e.g., "100%"). Tapping A+ increases text size, A- decreases it. The percentage updates to reflect the current scale.
result: issue
reported: "With text size increase it would be nice that the musical sheet could be sized as well, not only the text and chord modes"
severity: minor

### 6. Pinch-to-Zoom Scales Text
expected: On the song content area (outside the bottom sheet), a two-finger pinch gesture changes the text size — pinch out to enlarge, pinch in to shrink. The scale is clamped between 50% and 200%.
result: issue
reported: "it does not scales the text as the fab menu does... it scales the text as it would be an image and this pinch-to-zoom not working at Sheet"
severity: major

### 7. Presentation Mode in App Bar
expected: The app bar shows a fullscreen icon button (before the favorite heart). Tapping it navigates to the full-screen presentation mode with lyrics.
result: pass

### 8. Clean Song View
expected: The song view has no floating column of buttons on the right side. Only the FAB and app bar icons are visible as controls. The view area is uncluttered.
result: pass

## Summary

total: 8
passed: 4
issues: 4
pending: 0
skipped: 0

## Gaps

- truth: "Custom view option expands to reveal notation/chords toggles that usefully control the view"
  status: failed
  reason: "User reported: Custom button does nothing useful. I think we can get rid of that"
  severity: major
  test: 3
  root_cause: "Design dead end + broken entry logic: ViewConfig is only 2 booleans (4 states, 3 covered by presets). Custom chip's entry handler calls toggleNotation(), which from Sheet Music or Chords just lands on another preset so isCustomSelected stays false and the chip never engages; only from Lyrics does it work, and flipping either toggle there immediately collapses back to a preset. User decision: remove Custom entirely."
  artifacts:
    - path: "songbook_app/lib/presentation/screens/song_view/widgets/song_controls_sheet.dart"
      issue: "Custom chip + AnimatedSize toggle block (lines 42-45, 123-167) and doc comment line 11 — remove"
    - path: "songbook_app/lib/presentation/providers/song_provider.dart"
      issue: "toggleNotation/toggleChords (lines 150-165) become dead code after removal"
    - path: "songbook_app/lib/presentation/providers/settings_provider.dart"
      issue: "toggleNotation/toggleChords (lines 60-67) already dead code"
    - path: "songbook_app/lib/presentation/screens/settings/settings_screen.dart"
      issue: "'Notation without chords'/'Custom' fallback labels (lines 111-112, 182)"
  missing:
    - "Delete Custom chip and toggle block from song_controls_sheet.dart"
    - "Delete dead toggle methods in song_provider.dart and settings_provider.dart plus their unit tests (song_provider_test.dart:223-247, settings_provider_test.dart:98-118)"
    - "Guard persisted 'true:false' storage state: keep isNotationWithoutChords settings label fallback or normalize (T,F) to a preset in ViewConfig.fromStorageString"
  debug_session: ".planning/debug/custom-view-useless.md"

- truth: "Transpose controls stay in fixed positions so repeated +/- taps work like a carousel without the Reset button shifting the layout"
  status: failed
  reason: "User reported: reset button appears and takes up space, pushing up the transpose buttons and key text; buttons should be fixed position so repeated tapping isn't disrupted"
  severity: minor
  test: 4
  root_cause: "Two conditional children change the bottom sheet's intrinsic height when transpose != 0: the Reset button (song_controls_sheet.dart:208-216, conditionally spread into a MainAxisSize.min Column) and the semitone offset label (lines 191-197). The sheet is bottom-anchored (showModalBottomSheet), so added height grows upward, moving the +/- buttons under the user's finger on first tap."
  artifacts:
    - path: "songbook_app/lib/presentation/screens/song_view/widgets/song_controls_sheet.dart"
      issue: "Conditional Reset button (lines 208-216) and conditional offset label (lines 191-197) — no space reserved when hidden"
  missing:
    - "Always render Reset button wrapped in Visibility(visible: hasTranspose, maintainSize/maintainAnimation/maintainState: true) or Opacity + IgnorePointer"
    - "Always render the two-line key display, using an invisible/empty offset label at transpose 0"
  debug_session: ".planning/debug/transpose-reset-layout-shift.md"

- truth: "Text size controls also scale the sheet music notation, not only text/chord views"
  status: failed
  reason: "User reported: with text size increase it would be nice that the musical sheet could be sized as well, not only the text and chord modes"
  severity: minor
  test: 5
  root_cause: "Per-song textScale is consumed only by ChordView. song_view_screen.dart:108-113 constructs SheetMusicView without textScale; SheetMusicRenderer has no scale parameter; all engraving geometry derives from static const staffLineSpacing = 10.0 in engraving_constants.dart, so nothing could scale even if the value arrived. Canvas is a fixed-size SizedBox — availableWidth only controls line wrapping."
  artifacts:
    - path: "songbook_app/lib/presentation/screens/song_view/song_view_screen.dart"
      issue: "textScale not passed to SheetMusicView (lines 108-113)"
    - path: "songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart"
      issue: "No textScale field; custom render path drops it"
    - path: "songbook_app/lib/presentation/widgets/sheet_music/sheet_music_renderer.dart"
      issue: "No scale parameter; fixed-size canvas"
    - path: "songbook_app/lib/core/constants/engraving_constants.dart"
      issue: "All-static constants, no scale support"
  missing:
    - "Thread textScale from screen into SheetMusicRenderer"
    - "Lay out at availableWidth / textScale, render CustomPaint in SizedBox of layout.totalWidth * textScale by totalHeight * textScale with canvas.scale(textScale) in SheetMusicPainter.paint (keeps wrapping correct, vector-crisp, avoids EngravingConstants refactor)"
    - "Handle legacy SVG path separately (scale SVG width)"
  debug_session: ".planning/debug/sheet-music-not-scaling.md"

- truth: "Pinch-to-zoom adjusts the text-size setting (same effect as A-/A+ in the bottom sheet) and works in all views including Sheet Music"
  status: failed
  reason: "User reported: it does not scale the text as the FAB menu does — it scales the content like an image, and pinch-to-zoom does not work in Sheet Music view"
  severity: major
  test: 6
  status_final: fixed (commits bf49fa8, b61899e, a6bb140)
  root_cause: "THREE causes. Original diagnosis found two: (1) ChordView/legacy-SVG wrapped content in InteractiveViewer stealing the gesture as matrix zoom; (2) sheet music widgets didn't consume textScale (fixed by 04-04). Removing InteractiveViewer (04-05 task 1) was necessary but INSUFFICIENT. The decisive missed cause (3): on Flutter WEB a desktop trackpad pinch / Ctrl+mouse-wheel is delivered as a PointerScaleEvent (a pointer signal), which GestureDetector/ScaleGestureRecognizer never receive — so onScaleUpdate never fired on desktop. Proven via instrumentation + Playwright: ctrl+wheel produced onPointerSignal/_TransformedPointerScaleEvent x N with onScaleStart/Update at 0, while synthetic 2-finger touch fired onScaleUpdate and scaled correctly. Fix (a6bb140): Listener.onPointerSignal maps PointerScaleEvent -> setTextScale; GestureDetector retained for mobile touch."
  artifacts:
    - path: "songbook_app/lib/presentation/screens/song_view/widgets/chord_view.dart"
      issue: "InteractiveViewer steals pinch, applies geometric zoom (lines 34-36)"
    - path: "songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart"
      issue: "Legacy SVG path also wraps in InteractiveViewer (line 96)"
    - path: "songbook_app/lib/presentation/widgets/sheet_music/sheet_music_renderer.dart"
      issue: "Scroll view swallows pinch; no textScale consumption"
    - path: "songbook_app/web/index.html"
      issue: "No viewport meta tag — native browser pinch zoom possible secondary interference on mobile web"
  missing:
    - "Remove InteractiveViewer wrappers so the screen-level scale gesture receives the pinch"
    - "Plumb textScale into SheetMusicView/SheetMusicRenderer (shared with gap 3) so pinch and A+/A- affect notation"
    - "Verify pinch wins over scrollables after removal (may need content-level scale recognizer)"
    - "Add viewport meta tag to web/index.html to suppress native browser zoom on mobile web"
  debug_session: ".planning/debug/pinch-zoom-wrong-behavior.md"
