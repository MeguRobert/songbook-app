---
phase: 02-configurable-song-view
plan: 02
subsystem: ui
tags: [flutter-widgets, sheet-music, view-config, floating-menu, settings]
requires:
  - phase: 02-01
    provides: ViewConfig model, effectiveViewConfigProvider, toggle/preset methods
provides:
  - Unified song view rendering all 4 ViewConfig states
  - Floating menu with notation/chords toggles and 3 preset buttons
  - Conditional chord rendering in sheet music painter
  - Settings screen with global default view config selection
  - Complete removal of SongViewMode enum from codebase
affects:
  - 03-presentation-mode (builds on view rendering system)
  - Future phases using floating controls menu
tech-stack:
  added: []
  patterns:
    - ViewConfig-driven conditional rendering in song view
    - Direct parameter passing for view state (ChordView.showChords) instead of provider watching
    - Flexible + SingleChildScrollView for dynamic-height floating menus
key-files:
  created: []
  modified:
    - songbook_app/lib/presentation/screens/song_view/song_view_screen.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/floating_controls_menu.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/chord_view.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart
    - songbook_app/lib/presentation/widgets/sheet_music/sheet_music_renderer.dart
    - songbook_app/lib/presentation/widgets/sheet_music/sheet_music_painter.dart
    - songbook_app/lib/presentation/widgets/sheet_music/sheet_music_layout.dart
    - songbook_app/lib/presentation/screens/settings/settings_screen.dart
    - songbook_app/lib/presentation/providers/settings_provider.dart
key-decisions:
  - decision: ChordView accepts showChords as direct constructor parameter instead of reading from provider
    rationale: Parent controls view state via ViewConfig; eliminates hidden provider dependency
    date: 2026-02-14
  - decision: Reuse ChordView with showChords=false for lyrics-only view instead of creating separate widget
    rationale: Simpler code, ChordView already handles the layout without chords
    date: 2026-02-14
  - decision: Floating menu uses Flexible + SingleChildScrollView to prevent overflow
    rationale: Menu has many items that can exceed viewport on smaller screens
    date: 2026-02-14
patterns-established:
  - ViewConfig-driven rendering with effectiveViewConfigProvider as single source of truth
  - Direct parameter passing for conditional widget rendering
  - Preset buttons with active state highlighting in floating menu
duration: 14min
completed: 2026-02-14
---

# Phase 2 Plan 02: Unified Song View UI Summary

**ViewConfig-driven unified song view with 4 rendering states, floating menu toggles/presets, and conditional sheet music chord rendering**

## Performance

- **Duration:** 14 minutes (including orchestrator overflow fix)
- **Tasks completed:** 3/3 (2 auto + 1 human-verify checkpoint)
- **Commits:** 3 task commits + 1 orchestrator fix
- **Files modified:** 9 files

## Accomplishments

- Unified song view renders all 4 states: notation+chords, notation only, chords+lyrics, lyrics only
- Floating menu has notation toggle, chords toggle, and 3 preset buttons with active highlighting
- Sheet music painter conditionally renders chord symbols based on showChords parameter
- Settings screen updated with Default View preset selection dialog
- Old SongViewMode enum completely removed from entire codebase
- Menu overflow bug found during testing and fixed

## Task Commits

| Task | Commit  | Description |
|------|---------|-------------|
| 1    | 3128c0f | Update song view screen and renderers for ViewConfig-driven display |
| 2    | 34f6928 | Add view toggle controls to floating menu and update settings screen |
| fix  | b634a92 | Wrap floating menu in SingleChildScrollView to prevent overflow |

**Plan metadata:** pending (will be committed with this SUMMARY)

## Files Modified

1. `songbook_app/lib/presentation/screens/song_view/song_view_screen.dart`
   - Replaced SongViewMode conditional with ViewConfig-driven rendering
   - Removed app bar view mode toggle button
   - Watches effectiveViewConfigProvider for active config

2. `songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart`
   - Added showChords parameter passed through to renderer

3. `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_renderer.dart`
   - Added showChords parameter passed through to painter

4. `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_painter.dart`
   - Conditionally calls _drawChords only when showChords is true
   - Added shouldRepaint check for showChords changes

5. `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_layout.dart`
   - Added showChords parameter to layout engine
   - Reduces top padding when chords are hidden for more compact notation

6. `songbook_app/lib/presentation/screens/song_view/widgets/chord_view.dart`
   - Made showChords a direct constructor parameter
   - Removed provider dependency for chord visibility

7. `songbook_app/lib/presentation/screens/song_view/widgets/floating_controls_menu.dart`
   - Added notation toggle (music note icon) and chords toggle ("C7")
   - Added 3 preset buttons: Sheet Music (piano), Chords ("C"), Lyrics ("T")
   - Active toggles/presets highlighted with color
   - Wrapped in Flexible + SingleChildScrollView to prevent overflow

8. `songbook_app/lib/presentation/screens/settings/settings_screen.dart`
   - Replaced SongViewMode dialog with ViewConfig preset radio selection
   - Removed "Show Chords" toggle (now in ViewConfig)
   - Shows current preset name as subtitle

9. `songbook_app/lib/presentation/providers/settings_provider.dart`
   - Removed showChords field from SettingsState
   - Removed showChordsProvider
   - Removed setShowChords from SettingsNotifier

## Decisions Made

1. **ChordView as Lyrics-Only View** — Reused ChordView with showChords=false for lyrics-only mode instead of creating a separate LyricsOnlyView widget. Simpler and ChordView already handles the layout.

2. **Direct Parameter Passing** — ChordView and SheetMusicView receive showChords as a constructor parameter from the parent rather than watching providers internally. This makes the widget tree more explicit and testable.

3. **Overflow Fix** — Wrapped floating menu content in Flexible + SingleChildScrollView. Discovered during Playwright testing that the menu Column exceeded viewport height on 412x915 viewport.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug Fix] Floating menu RenderFlex overflow**
- **Found during:** Playwright verification testing
- **Issue:** Expanded menu Column exceeded viewport height by 19px, causing yellow/black overflow warning
- **Fix:** Wrapped SizeTransition content in Flexible + SingleChildScrollView
- **Files modified:** floating_controls_menu.dart
- **Verification:** Retested with Playwright — no overflow, zero console errors
- **Committed in:** b634a92

---

**Total deviations:** 1 auto-fixed (bug fix)
**Impact on plan:** Essential fix for usability on smaller screens. No scope creep.

## Issues Encountered

- RadioListTile API deprecation warnings in settings_screen.dart (Flutter 3.32+ deprecates groupValue/onChanged in favor of RadioGroup). Info-level only, no functional impact.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 4 view states render correctly and tested via Playwright
- Toggle and preset controls work with proper active state highlighting
- Global default persistence and per-song override system fully integrated
- Settings screen provides clean preset selection
- Ready for Phase 3 (Presentation Mode) which builds on the view rendering system

---
*Phase: 02-configurable-song-view*
*Completed: 2026-02-14*
