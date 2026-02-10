---
phase: 01-bug-fixes-core-polish
plan: 01
subsystem: ui
tags: [flutter, dart, riverpod, transpose, svg, sheet-music]

# Dependency graph
requires:
  - phase: 00-init
    provides: GSD framework setup and project structure mapping
provides:
  - Symmetric transpose wrapping (-6 to +5 semitone range)
  - Transpose state reset on song navigation
  - Distinct SVG fallback messages for sheet music
affects: [phase-02, ui-improvements]

# Tech tracking
tech-stack:
  added: []
  patterns: [Record types for structured async returns, State cleanup in dispose()]

key-files:
  created: []
  modified:
    - songbook_app/lib/presentation/providers/song_provider.dart
    - songbook_app/lib/presentation/screens/song_view/song_view_screen.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart

key-decisions:
  - "Symmetric transpose range -6 to +5 (12 semitones total, no duplicate pitch at +6/-6)"
  - "Dart record types for structured SVG fallback state"

patterns-established:
  - "State reset pattern: openSong() creates fresh state, no explicit cleanup needed in dispose()"
  - "Async result patterns: Use record types to return multiple values with semantic names"

# Metrics
duration: 3min
completed: 2026-02-10
---

# Phase 01 Plan 01: Core Transpose & Sheet Music Fixes Summary

**Symmetric transpose wrapping (-6 to +5 semitones), state reset on navigation, and distinct SVG fallback messages using Dart record types**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-10T21:03:54Z
- **Completed:** 2026-02-10T21:07:08Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Fixed transpose wrapping to use symmetric 12-semitone range (-6 to +5 instead of -11 to +12)
- Added state cleanup on song navigation to prevent transpose leaking between songs
- Improved SVG sheet music fallback to distinguish "transposed key unavailable" from "no sheet music exists"

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix symmetric transpose wrapping and ensure state reset** - `47c5d25` (fix)
2. **Task 2: Improve SVG sheet music fallback messages** - `186107f` (feat)

## Files Created/Modified
- `songbook_app/lib/presentation/providers/song_provider.dart` - Fixed transposeUp/Down wrapping logic to symmetric -6 to +5 range
- `songbook_app/lib/presentation/screens/song_view/song_view_screen.dart` - Added closeSong() call in dispose() to reset transpose state
- `songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart` - Added _loadSheetMusicWithFallback using record types to distinguish fallback scenarios

## Decisions Made

**1. Symmetric transpose range of -6 to +5 (instead of -11 to +12)**
- Rationale: 12-semitone cycle should have exactly 12 values. -6 to +5 includes 0 and covers one octave. Having both +6 and -6 would be redundant (same pitch).
- Impact: Musicians transpose at most a tritone (6 semitones) in either direction, so this range is natural and symmetric.

**2. Use Dart record types for SVG fallback state**
- Rationale: Record types provide semantic, structured returns from async methods without creating a full class.
- Pattern: `({String? svg, bool isOriginalFallback})` clearly communicates three states: transposed loaded, fallback to original, or nothing available.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all changes implemented cleanly with no blocking issues.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 01 Plan 02:** Settings persistence and performance optimization.

**Observations:**
- Transpose logic now matches musician expectations (symmetric range)
- State cleanup prevents confusing behavior when navigating between songs
- Users will understand when sheet music needs manual transposition vs when it doesn't exist at all
- No test coverage yet - changes verified via flutter analyze only (regression risk remains)

---
*Phase: 01-bug-fixes-core-polish*
*Completed: 2026-02-10*
