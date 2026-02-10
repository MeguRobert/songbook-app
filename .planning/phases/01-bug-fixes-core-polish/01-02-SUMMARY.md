---
phase: 01-bug-fixes-core-polish
plan: 02
subsystem: ui
tags: [flutter, dart, riverpod, chord-view, text-scale, centering]

# Dependency graph
requires:
  - phase: 01-01
    provides: Symmetric transpose wrapping, state reset, SVG fallback
provides:
  - Centered chord view layout with max-width constraint
  - Verified end-to-end text size controls (A+/A-)
  - Verified transpose controls working in floating menu
affects: [phase-02, ui-improvements]

# Tech tracking
tech-stack:
  added: []
  patterns: [Center + ConstrainedBox for responsive centered layout]

key-files:
  created: []
  modified:
    - songbook_app/lib/presentation/screens/song_view/widgets/chord_view.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/floating_controls_menu.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/transpose_controls.dart

key-decisions:
  - "Center + ConstrainedBox(maxWidth: 600) pattern for centered block of left-aligned text"
  - "Removed closeSong() from dispose — openSong() already creates fresh state, and Riverpod forbids state modification during unmount"

patterns-established:
  - "Responsive centering: Center > ConstrainedBox(maxWidth) > Column(crossAxisAlignment: start)"
  - "Riverpod lifecycle: never modify provider state in dispose(); rely on fresh state creation in init"

# Metrics
duration: ~15min (including human-verify checkpoint and dispose bug fix)
completed: 2026-02-10
---

# Phase 01 Plan 02: Center Chord View & Verify Text Controls Summary

**Centered chord view layout with responsive max-width, verified text size and transpose controls end-to-end via human testing**

## Performance

- **Duration:** ~15 min (includes human-verify checkpoint)
- **Completed:** 2026-02-10
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 3

## Accomplishments
- Centered chord view content using Center + ConstrainedBox(maxWidth: 600) pattern
- Verified text size A+/A- controls work end-to-end (floating menu → provider → ChordView)
- Verified transpose wrapping -6↔+5 works correctly
- Fixed dispose bug: removed closeSong() from dispose to avoid Riverpod lifecycle error
- Cleaned up unused variables in floating_controls_menu.dart and transpose_controls.dart

## Task Commits

Each task was committed atomically:

1. **Task 1: Center chord view layout and verify text size wiring** - `917a635` (feat)
2. **Orchestrator fix: Remove closeSong from dispose** - `3723d36` (fix)

## Files Created/Modified
- `songbook_app/lib/presentation/screens/song_view/widgets/chord_view.dart` - Added Center + ConstrainedBox(maxWidth: 600) wrapping for centered layout
- `songbook_app/lib/presentation/screens/song_view/widgets/floating_controls_menu.dart` - Removed unused menuItemHeight, keyDisplayHeight variables
- `songbook_app/lib/presentation/screens/song_view/widgets/transpose_controls.dart` - Removed unused semitones variable in dropdown items builder
- `songbook_app/lib/presentation/screens/song_view/song_view_screen.dart` - Removed closeSong() from dispose (Riverpod lifecycle fix)

## Decisions Made

**1. Center + ConstrainedBox pattern for chord view centering**
- Rationale: Keeps text left-aligned within a centered container. On wide screens (tablets/desktop), content stays max 600px wide with margins. On narrow screens, fills naturally.
- Pattern: `Center > ConstrainedBox(maxWidth: 600) > Column(crossAxisAlignment: start)`

**2. Remove closeSong() from dispose instead of caching notifier**
- Rationale: Riverpod forbids state modification during widget tree unmount/build lifecycle. openSong() already creates fresh SongViewState with default transposeAmount=0 and textScale=1.0, making closeSong unnecessary.
- Impact: Eliminates both "Cannot use ref after dispose" and "Cannot modify provider during build" errors.

## Deviations from Plan

**Dispose bug discovered and fixed during human-verify checkpoint:**
- Plan 01-01 introduced `closeSong()` in dispose() — this caused Riverpod lifecycle errors
- First fix attempt (commit `102b612`) cached notifier reference — wrong approach, shifted error
- Correct fix (commit `3723d36`) removed closeSong() entirely — openSong() handles state reset

## Human Verification Results

All checkpoint items verified via Playwright browser automation:
- Chord view centering: content centered with margins on wide screen
- Text size A+: text visibly grew after pressing
- Text size A-: text visibly shrank after pressing
- Transpose wrapping: +5 → -6 (confirmed), -6 → +5 (confirmed)
- State reset: song 1 transposed to +3, navigated to song 256, showed transpose 0
- Navigation round-trip: Song 1 → Home → Song 256 → Song 1 with zero console errors

## Issues Encountered

**Riverpod lifecycle error in dispose():**
- `closeSong()` in dispose triggered `StateError: Cannot use ref after dispose` and `Tried to modify provider while widget tree was building`
- Root cause: Riverpod deactivates ref before dispose runs, and state modification during unmount is architecturally forbidden
- Resolution: Removed closeSong() from dispose entirely — unnecessary since openSong() creates fresh state

## Next Phase Readiness

**Phase 01 complete.** All success criteria from ROADMAP.md met:
- Transpose wrapping is symmetric (-6 to +5)
- State resets between songs
- SVG fallback messages are distinct
- Chord view is centered
- Text size controls work end-to-end
- No new analyzer warnings introduced

---
*Phase: 01-bug-fixes-core-polish*
*Completed: 2026-02-10*
