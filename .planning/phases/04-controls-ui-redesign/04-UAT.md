---
status: complete
phase: 04-controls-ui-redesign
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md]
started: 2026-07-18T18:38:55Z
updated: 2026-07-18T19:30:00Z
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
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Transpose controls stay in fixed positions so repeated +/- taps work like a carousel without the Reset button shifting the layout"
  status: failed
  reason: "User reported: reset button appears and takes up space, pushing up the transpose buttons and key text; buttons should be fixed position so repeated tapping isn't disrupted"
  severity: minor
  test: 4
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Text size controls also scale the sheet music notation, not only text/chord views"
  status: failed
  reason: "User reported: with text size increase it would be nice that the musical sheet could be sized as well, not only the text and chord modes"
  severity: minor
  test: 5
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Pinch-to-zoom adjusts the text-size setting (same effect as A-/A+ in the bottom sheet) and works in all views including Sheet Music"
  status: failed
  reason: "User reported: it does not scale the text as the FAB menu does — it scales the content like an image, and pinch-to-zoom does not work in Sheet Music view"
  severity: major
  test: 6
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
