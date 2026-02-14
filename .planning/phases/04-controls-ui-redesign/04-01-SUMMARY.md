---
phase: 04-controls-ui-redesign
plan: 01
subsystem: presentation-ui
status: complete
tags: [flutter, material-design, bottom-sheet, gestures, riverpod]
dependencies:
  requires:
    - 03-02-responsive-layout
    - 02-02-view-config-toggles
  provides:
    - SongControlsSheet bottom sheet widget
    - FAB trigger for controls
    - Pinch-to-zoom text scaling gesture
  affects:
    - 04-02-preset-persistence
tech-stack:
  added: []
  patterns:
    - Material bottom sheet pattern with showModalBottomSheet
    - GestureDetector with onScaleStart/Update/End for pinch-to-zoom
    - AnimatedSize for smooth expand/collapse of Custom toggles
key-files:
  created:
    - songbook_app/lib/presentation/screens/song_view/widgets/song_controls_sheet.dart
  modified:
    - songbook_app/lib/presentation/screens/song_view/song_view_screen.dart
    - songbook_app/lib/presentation/providers/song_provider.dart
key-decisions:
  - decision: Use Material bottom sheet instead of redesigning floating menu
    rationale: Better discoverability, standard Material pattern, reduces visual clutter
    date: 2026-02-14
  - decision: FAB with tune icon as single entry point for all controls
    rationale: Clear affordance, removes 12-button floating column, standard Material pattern
    date: 2026-02-14
  - decision: Add pinch-to-zoom gesture in addition to A+/A- buttons
    rationale: Modern gesture interaction, faster than button taps for text scaling
    date: 2026-02-14
  - decision: AnimatedSize for Custom toggles expand/collapse
    rationale: Smooth visual feedback when switching between presets and custom view
    date: 2026-02-14
metrics:
  duration: 2min
  completed: 2026-02-14
  tasks: 2
  files: 3
---

# Phase 04 Plan 01: Bottom Sheet Controls Summary

**One-liner:** Material bottom sheet with FAB trigger and pinch-to-zoom text scaling replaces 12-button floating column

## Performance

**Execution:** 2 minutes
**Started:** 2026-02-14
**Completed:** 2026-02-14

**Breakdown:**
- Tasks: 2/2 complete (100%)
- Files: 3 (1 created, 2 modified)
- Commits: 2 atomic task commits

## What Was Built

Replaced the overloaded 12-button floating controls menu with a clean Material bottom sheet pattern, providing the core UX improvement of Phase 4.

**New widget: SongControlsSheet**
- Three labeled sections: View, Transpose, Text Size
- View section: ChoiceChip widgets for 3 presets (Sheet Music, Chords, Lyrics) + Custom option
- Custom option expands to show SwitchListTile for "Show Notation" and "Show Chords"
- Transpose section: +/- IconButtons with center key display and reset TextButton
- Text Size section: A-/A+ TextButtons with percentage display
- AnimatedSize for smooth expand/collapse of Custom toggles
- Drag handle and rounded top corners for Material bottom sheet styling

**Updated SongViewScreen:**
- Removed FloatingControlsMenu widget and import
- Added FloatingActionButton.small with tune icon
- FAB opens SongControlsSheet via showModalBottomSheet
- Wrapped content in GestureDetector for pinch-to-zoom
- Added _baseScale field for gesture tracking
- onScaleStart stores current text scale
- onScaleUpdate calculates new scale and calls setTextScale
- Only applies when scale delta > 0.01 (avoids single-finger drag)

**Updated SongViewNotifier:**
- Added setTextScale(double scale) method
- Clamps scale to 0.5-2.0 range
- Enables direct scale setting from gesture

## Task Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Create SongControlsSheet bottom sheet widget | 0505686 | song_controls_sheet.dart |
| 2 | Replace floating menu with FAB and add pinch-to-zoom | 633b717 | song_view_screen.dart, song_provider.dart |

## Files Created

1. **songbook_app/lib/presentation/screens/song_view/widgets/song_controls_sheet.dart** (285 lines)
   - ConsumerStatefulWidget for bottom sheet content
   - Three labeled sections with controls
   - _SectionHeader helper widget for consistent styling
   - All controls wired to songViewProvider.notifier

## Files Modified

1. **songbook_app/lib/presentation/screens/song_view/song_view_screen.dart**
   - Removed FloatingControlsMenu from Stack
   - Changed import from floating_controls_menu.dart to song_controls_sheet.dart
   - Added _baseScale field and _showControlsSheet method
   - Wrapped body in GestureDetector with scale handlers
   - Added floatingActionButton property to Scaffold

2. **songbook_app/lib/presentation/providers/song_provider.dart**
   - Added setTextScale(double scale) method to SongViewNotifier
   - Placed after resetTextScale() method
   - Clamps scale to 0.5-2.0 range

## Decisions Made

**1. Material bottom sheet over redesigned floating menu**
- Rationale: Better discoverability, follows Material Design guidelines, reduces visual clutter on song view screen
- Impact: All controls now hidden by default, accessed via FAB tap

**2. Single FAB entry point with tune icon**
- Rationale: Clear affordance for "controls", removes 12-button floating column, standard Material pattern users recognize
- Impact: Cleaner song view, less cognitive load, but requires one tap to access controls

**3. Pinch-to-zoom gesture for text scaling**
- Rationale: Modern touch interaction, faster than button taps, familiar gesture from photos/maps
- Impact: Faster text adjustment, but requires onScaleUpdate threshold to avoid conflicts with single-finger scrolling

**4. AnimatedSize for Custom toggles**
- Rationale: Smooth visual feedback when switching between presets and custom configuration
- Impact: Better UX than instant show/hide, communicates state change clearly

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - both tasks completed without errors.

## Next Phase Readiness

**Ready for 04-02 (Preset Persistence):**
- ✓ Bottom sheet structure in place
- ✓ All controls functional and wired to providers
- ✓ setPreset() calls work correctly

**Blockers:** None

**Concerns:**
- No visual testing yet - need to verify bottom sheet appearance on different screen sizes
- Pinch-to-zoom threshold (0.01) may need tuning based on device testing
- Custom toggles may need better labeling for discoverability

**Technical debt:**
- FloatingControlsMenu widget still exists in codebase but is unused (can be removed in cleanup)
- No test coverage for gesture handling or bottom sheet interactions
