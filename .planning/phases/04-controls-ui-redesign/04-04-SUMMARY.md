---
phase: 04-controls-ui-redesign
plan: 04
subsystem: ui
tags: [flutter, canvas, custom-painter, sheet-music, textScale]

# Dependency graph
requires:
  - phase: 04-controls-ui-redesign (plan 01-03)
    provides: Bottom sheet controls, textScaleProvider, per-song textScale state
provides:
  - textScale plumbing from song view screen through to the Canvas sheet-music renderer
  - SheetMusicPainter canvas.scale(textScale) with correctly centered header at any scale
affects: [04-05 (pinch-to-zoom fix, shares this render path)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Scale-aware CustomPainter: layout at unscaled width, size the canvas box by totalWidth*scale, wrap all draw calls in canvas.save()/scale(scale)/restore(), center overlays using the unscaled layout width to avoid double-scaling"

key-files:
  created: []
  modified:
    - songbook_app/lib/presentation/widgets/sheet_music/sheet_music_renderer.dart
    - songbook_app/lib/presentation/widgets/sheet_music/sheet_music_painter.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart
    - songbook_app/lib/presentation/screens/song_view/song_view_screen.dart

key-decisions:
  - "Scale the whole engraving via canvas.scale(textScale) rather than refactoring EngravingConstants to scale-aware values — keeps output vector-crisp and avoids a much larger refactor"
  - "Lay out at availableWidth / textScale so line wrapping matches the true physical width once the canvas is scaled up/down"
  - "Center the header text using the unscaled layout.totalWidth (not the scaled CustomPaint `size`), since drawing happens inside the canvas.scale() block — using `size.width` there would double-scale the offset"

patterns-established:
  - "Scale-aware CustomPainter pattern: layout at availableWidth/scale, size outer box at totalWidth*scale, canvas.scale(scale) inside paint(), center any header/overlay text against the pre-scale layout dimensions"

# Metrics
duration: 15min
completed: 2026-07-20
---

# Phase 4 Plan 04: Sheet Music textScale Scaling Summary

**A+/A- (and later pinch) now scale the rendered Canvas sheet music notation, not just chord/lyric text — via canvas.scale(textScale) with unscaled-width header centering to avoid double-offset.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-20
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- SheetMusicRenderer and SheetMusicPainter now accept a `textScale` parameter that uniformly scales the entire engraved canvas while keeping vector output crisp and re-flowing line wrapping to the true available width.
- Fixed a would-be double-scaling bug in the header ("Key: X | Time: Y") centering by computing the offset from the unscaled `layout.totalWidth` instead of the scaled CustomPaint `size`.
- `textScale` now flows end-to-end: `song_view_screen.dart` (already watching `textScaleProvider`) → `SheetMusicView`/`SheetMusicViewWidget` → `SheetMusicRenderer` → `SheetMusicPainter`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add textScale scaling to SheetMusicRenderer and SheetMusicPainter** - `07906a2` (feat)
2. **Task 2: Wire textScale from the song view screen into the sheet music path** - `38e7049` (feat)

_Note: no TDD tasks in this plan._

## Files Created/Modified
- `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_painter.dart` - Added `textScale` field, wrapped `paint()` body in `canvas.save()/scale(textScale)/restore()`, fixed `_drawHeader` to center off `layout.totalWidth`, added `textScale` to `shouldRepaint`.
- `songbook_app/lib/presentation/widgets/sheet_music/sheet_music_renderer.dart` - Added `textScale` field/param (default 1.0), included it in `didUpdateWidget` change detection, laid out the `SheetMusicLayoutEngine` at `constraints.maxWidth / textScale`, sized the `SizedBox`/`ConstrainedBox` by `totalWidth/Height * textScale`, passed `textScale` into `SheetMusicPainter`.
- `songbook_app/lib/presentation/screens/song_view/widgets/sheet_music_view.dart` - Added `textScale` field/param to `SheetMusicViewWidget` (default 1.0), forwarded it into `SheetMusicRenderer` in `_buildCustomRenderer`.
- `songbook_app/lib/presentation/screens/song_view/song_view_screen.dart` - Passed the already-watched `textScale` into the `SheetMusicView(...)` call.

## Decisions Made
- Scale the entire engraving via `canvas.scale(textScale)` rather than making `EngravingConstants` scale-aware — smaller, lower-risk change that keeps rendering resolution-independent.
- Divide `availableWidth` by `textScale` before layout so the number of measures per system (line wrapping) stays correct for the physical/visible width at any scale.
- Center the header text against the unscaled `layout.totalWidth`, since the header is drawn inside the `canvas.scale()` block — using the scaled `size.width` there would apply the scale factor twice to the centering offset.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. `flutter analyze` reported no new issues (8 pre-existing `RadioListTile` deprecation infos in `settings_screen.dart` are unrelated, from parallel plan 04-03). Full `flutter test` suite (364 tests) passed, including the existing `sheet_music_view_test.dart` cases which run at the default `textScale: 1.0` and are unaffected.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Sheet music render path now scale-aware; plan 04-05 (pinch-to-zoom fix, wave 2) can proceed to remove the gesture-stealing `InteractiveViewer`s without needing to touch the scaling logic added here.
- No blockers.

---
*Phase: 04-controls-ui-redesign*
*Completed: 2026-07-20*
