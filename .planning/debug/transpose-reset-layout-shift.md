---
status: diagnosed
trigger: "In the bottom sheet Transpose section, the Reset to original button appears/disappears conditionally, shifting the position of the +/- buttons and key display."
created: 2026-07-18T00:00:00Z
updated: 2026-07-18T00:00:00Z
---

## Current Focus

hypothesis: CONFIRMED - Reset button is a conditional child appended below the transpose Row inside a bottom-anchored, height-to-content Column; when it appears the sheet grows and everything above shifts up.
test: Read song_controls_sheet.dart and song_view_screen.dart
expecting: n/a (root cause confirmed by direct code inspection)
next_action: Return diagnosis (goal: find_root_cause_only)

## Symptoms

expected: Transpose +/- buttons and the key display stay in fixed positions so the user can tap + or - repeatedly (carousel-style) without the controls moving under their finger.
actual: "the reset to original button appears and by taking up space it pushes up the other things a bit, like the transpose buttons and the transpose text itself"
errors: None
reproduction: Test 4 in UAT - open a song, tap the FAB, tap + in the Transpose section; Reset button appears and shifts the layout.
started: Introduced in Phase 4 (Controls UI Redesign), bottom sheet controls implementation (commits c156ad7 / fb05ebd era)

## Eliminated

(none - first hypothesis confirmed directly)

## Evidence

- timestamp: 2026-07-18
  checked: songbook_app/lib/presentation/screens/song_view/widgets/song_controls_sheet.dart lines 208-216
  found: |
    if (hasTranspose) ...[
      const SizedBox(height: 8),
      Center(child: TextButton(onPressed: ..., child: Text('Reset to ${widget.originalKey}'))),
    ],
  implication: Reset button (+8px spacer, ~48px TextButton) is conditionally inserted into the sheet Column only when transpose != 0. No space is reserved when hidden.

- timestamp: 2026-07-18
  checked: song_controls_sheet.dart lines 52-53 and 68-70
  found: Sheet root is Column(mainAxisSize: MainAxisSize.min) inside a plain Container - sheet height is content-driven.
  implication: Any conditional child changes total sheet height.

- timestamp: 2026-07-18
  checked: song_view_screen.dart lines 39-45
  found: Sheet shown via showModalBottomSheet(isScrollControlled: true) - anchored to bottom of screen.
  implication: When sheet height grows, growth extends UPWARD, so the Transpose row (and key text) above the newly-inserted Reset button move up under the user's finger. Matches report exactly.

- timestamp: 2026-07-18
  checked: song_controls_sheet.dart lines 191-197 (secondary shift)
  found: |
    if (hasTranspose)
      Text('${transpose > 0 ? '+' : ''}$transpose', style: bodySmall...)
  implication: The "+n" offset label inside the key display Column is ALSO conditional. Going 0 -> +1 adds a second text line, changing that Column's height and re-centering the key text - a second, smaller shift of the key display itself.

## Resolution

root_cause: |
  Two conditional children in song_controls_sheet.dart change the sheet's intrinsic height when transpose becomes non-zero:
  1. PRIMARY (lines 208-216): The "Reset to {key}" TextButton + SizedBox(8) are inserted below the transpose Row via `if (hasTranspose) ...[]`. The sheet is a bottom-anchored modal (showModalBottomSheet) whose root Column uses MainAxisSize.min, so the added ~56px grows the sheet upward, pushing the +/- IconButtons and key display up.
  2. SECONDARY (lines 191-197): The "+n" semitone offset Text inside the key-display Column is also conditional, changing that Column's height and shifting the key text within the row.
fix: (not applied - diagnose-only mode)
verification: (n/a)
files_changed: []

### Suggested fix direction

Reserve the space permanently instead of conditionally inserting widgets:
- Reset button: always render it, wrapped in Visibility(visible: hasTranspose, maintainSize: true, maintainAnimation: true, maintainState: true) or Opacity(opacity: hasTranspose ? 1 : 0) + IgnorePointer when hidden; alternatively give the slot a fixed SizedBox(height: ~56) container.
- Offset label: always render the Text, using an empty/space string or Opacity 0 when transpose == 0 (fixed two-line key display), so the key text stays vertically stable.
