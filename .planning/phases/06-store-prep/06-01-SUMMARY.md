---
phase: 06-store-prep
plan: 01
subsystem: accessibility
status: complete
tags: [flutter, dart, accessibility, semantics, a11y, widget-tests]
dependencies:
  requires: []
  provides:
    - Screen-reader labels on icon/letter-only controls
    - Section-header semantics (settings, controls sheet)
    - "Song N" semantic labels on list tiles
    - Sheet-music canvas Semantics image label
    - Accessibility-guideline + text-scaling widget tests
  affects:
    - 06-02-platform-config
tech-stack:
  added: []
  patterns:
    - Semantics(header: true) for section headers
    - Semantics(label:, excludeSemantics: true) to relabel icon/letter-only controls
    - Semantics(image: true, label:) for invisible CustomPaint canvases
    - meetsGuideline(...) automated accessibility matchers in widget tests
key-files:
  created:
    - songbook_app/test/accessibility/accessibility_test.dart
  modified:
    - songbook_app/lib/presentation/screens/settings/settings_screen.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/song_controls_sheet.dart
    - songbook_app/lib/presentation/screens/song_list/widgets/song_list_tile.dart
    - songbook_app/lib/presentation/widgets/sheet_music/sheet_music_renderer.dart
    - songbook_app/lib/presentation/screens/presentation/presentation_screen.dart
key-decisions:
  - decision: Relabel icon/letter-only controls with Semantics + tooltips rather than visible text changes
    rationale: Preserves the compact visual design while giving screen readers meaningful labels
    date: 2026-06-13
  - decision: Use Flutter's meetsGuideline() matchers (tap target size + labeled tap targets) as the automated a11y gate
    rationale: Real, headless-verifiable accessibility checks — not a proxy; caught the unlabeled font-size buttons
    date: 2026-06-13
metrics:
  completed: 2026-06-13
  tasks: 5
  files: 6
---

# Phase 06 Plan 01: Accessibility — Summary

**One-liner:** The major screens now expose meaningful screen-reader labels and header semantics, the
sheet-music canvas is described to assistive tech, and automated guideline + text-scaling tests prove it.

## What Was Built

**Screen-reader labels on icon/letter-only controls.** The Settings font-size −/+ `IconButton`s had
no tooltip (and so no SR label — flagged by `labeledTapTargetGuideline`); they now read "Decrease
font size" / "Increase font size". The controls sheet's cryptic `A−`/`A+` text buttons now announce
"Decrease text size" / "Increase text size" via `Semantics(label:, excludeSemantics: true)` while
keeping the visible glyphs.

**Header semantics.** Settings section headers and the controls-sheet section headers are wrapped in
`Semantics(header: true)`; the presentation-mode title card is marked as a header too. Screen-reader
users can now jump by heading.

**Song list tiles read as a unit.** The bare leading number ("42") now announces as "Song 42" via
`Semantics(label:, excludeSemantics: true)`; the title, reference, and favorite action stay as
distinct nodes.

**Sheet-music canvas described.** The `CustomPaint` notation canvas is invisible to the a11y tree;
it now carries `Semantics(image: true, label: 'Sheet music notation for <title>')`.

**Tests.** `test/accessibility/accessibility_test.dart` (5 tests):
- `androidTapTargetGuideline` + `iOSTapTargetGuideline` + `labeledTapTargetGuideline` on the song list.
- `labeledTapTargetGuideline` on settings (proves the font-size buttons are now labeled).
- `find.bySemanticsLabel(RegExp('Song N'))` on list tiles; `find.byTooltip('Add to favorites')`.
- A 2.5× text-scaling smoke test (`MediaQuery(textScaler: TextScaler.linear(2.5))`) asserting no
  exception and that content still renders.

## Quality Gates

- `flutter analyze`: **8 issues, all pre-existing** info-level RadioListTile deprecations in
  settings_screen.dart (baseline unchanged — no new issues).
- `flutter test`: **23/23 pass** (5 new accessibility + 18 prior).

## Deviations from Plan

- Favorite-button assertion: a `Tooltip` exposes its text via the semantics **tooltip** field, not
  **label**, so `find.bySemanticsLabel` misses it. Switched that assertion to `find.byTooltip`
  (the `labeledTapTargetGuideline` test already proves the button is labeled). `bySemanticsLabel`
  uses exact-equality for `String` but substring-match for `RegExp`, so the merged-tile label checks
  use `RegExp`.

## Notes / Pending

- **Visual / on-device UAT** (TalkBack on Android, VoiceOver on iOS, the system font-size slider) is
  **pending** — no device available overnight. The automated guideline tests are a strong proxy but
  do not replace a real screen-reader pass.
- Text scaling is honoured app-wide (no `textScaler` override disables it). Presentation mode uses its
  own projection-oriented auto-sizing (independent of system scale, by design).

## Next Plan Readiness

Ready for 06-02 (platform config, branding scaffold, store metadata).
