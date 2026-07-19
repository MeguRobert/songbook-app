---
phase: 04-controls-ui-redesign
plan: 03
subsystem: ui
tags: [flutter, riverpod, bottom-sheet, view-config]

# Dependency graph
requires:
  - phase: 04-controls-ui-redesign (04-01, 04-02)
    provides: Material bottom sheet controls with View/Transpose/Text Size sections, ViewConfig two-toggle model
provides:
  - Bottom sheet View section reduced to exactly three preset chips (no Custom chip/toggles)
  - Fixed-position transpose carousel (Reset button and offset label reserve their layout space via Visibility maintainSize)
  - ViewConfig.fromStorageString normalizes legacy orphaned notation-only persisted data to Sheet Music preset
affects: [05-song-books, future controls/UI work touching ViewConfig or song_controls_sheet.dart]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Visibility(maintainSize/maintainState/maintainAnimation: true) to reserve layout space for conditionally-shown widgets, avoiding position shifts in bottom-anchored sheets"
    - "Normalize orphaned/unreachable model states at the deserialization boundary (fromStorageString) rather than scattering checks through the UI"

key-files:
  created: []
  modified:
    - songbook_app/lib/presentation/screens/song_view/widgets/song_controls_sheet.dart
    - songbook_app/lib/presentation/providers/song_provider.dart
    - songbook_app/lib/presentation/providers/settings_provider.dart
    - songbook_app/lib/data/models/view_config.dart
    - songbook_app/lib/presentation/screens/settings/settings_screen.dart
    - songbook_app/test/unit/presentation/providers/song_provider_test.dart
    - songbook_app/test/unit/presentation/providers/settings_provider_test.dart
    - songbook_app/test/unit/data/models/view_config_test.dart
    - songbook_app/test/unit/data/repositories/settings_repository_test.dart

key-decisions:
  - "Custom view removed entirely rather than fixed — its only unique state (notation without chords) was a design dead end per UAT feedback"
  - "Legacy persisted 'true:false' view config data is normalized to Sheet Music (not treated as an error) so no user-facing regression occurs from old SharedPreferences values"
  - "Transpose Reset button and offset label always occupy their layout slot (hidden via Visibility, not removed via if) to keep the sheet a stable, non-shifting carousel"

patterns-established:
  - "Visibility(maintainSize: true) for stable layout in bottom-anchored/growing-upward containers"

# Metrics
duration: 12min
completed: 2026-07-20
---

# Phase 4 Plan 3: Bottom Sheet Gap Closure Summary

**Removed the dead-end Custom view chip/toggles and made the Transpose row's Reset button and offset label permanently reserve their layout space, closing two UAT-reported gaps in the Phase 4 controls bottom sheet.**

## Performance

- **Duration:** ~12 min
- **Tasks:** 2
- **Files modified:** 9 (5 lib, 4 test)

## Accomplishments
- Bottom sheet View section now shows exactly three preset chips (Sheet Music, Chords, Lyrics) with no Custom chip or notation/chords SwitchListTiles
- Transpose +/- buttons and key text no longer shift position as transpose crosses 0 — Reset button and "+n" offset label are wrapped in `Visibility(maintainSize: true, maintainState: true, maintainAnimation: true)`
- Removed now-dead `toggleNotation()`/`toggleChords()` methods from both `SongViewNotifier` and `SettingsNotifier`, and the `isNotationWithoutChords` getter from `ViewConfig`
- `ViewConfig.fromStorageString` normalizes legacy persisted `"true:false"` data to `ViewConfig.sheetMusic()` so old SharedPreferences values never resurface the removed Custom state
- Settings screen labels/preset keys fall back to "Sheet Music"/`'sheet'` instead of "Custom"/`'custom'`
- Updated unit tests: removed toggle-specific tests, updated the two normalization-sensitive tests (song_provider "per-song override wins" and settings_repository "reads a stored override for the right song key") to expect `ViewConfig.sheetMusic()`

## Task Commits

1. **Task 1: Remove Custom UI and fix transpose layout shift in the bottom sheet** - `48e454e` (feat)
2. **Task 2: Remove dead Custom code from providers/model/settings and update tests** - `e2cd54b` (refactor)

_Note: no plan metadata commit created yet — pending STATE.md update below._

## Files Created/Modified
- `songbook_app/lib/presentation/screens/song_view/widgets/song_controls_sheet.dart` - Removed Custom chip/AnimatedSize toggles block and isCustomSelected; wrapped Reset button + offset label in Visibility(maintainSize)
- `songbook_app/lib/presentation/providers/song_provider.dart` - Deleted `toggleNotation()`/`toggleChords()` from SongViewNotifier
- `songbook_app/lib/presentation/providers/settings_provider.dart` - Deleted `toggleNotation()`/`toggleChords()` from SettingsNotifier
- `songbook_app/lib/data/models/view_config.dart` - Deleted `isNotationWithoutChords`; `fromStorageString` now normalizes `notation && !chords` to `ViewConfig.sheetMusic()`
- `songbook_app/lib/presentation/screens/settings/settings_screen.dart` - `_getViewConfigLabel`/`_getPresetKey` fall back to Sheet Music/`'sheet'` instead of Custom
- `songbook_app/test/unit/presentation/providers/song_provider_test.dart` - Removed toggle tests; updated "per-song override wins" to expect `ViewConfig.sheetMusic()`
- `songbook_app/test/unit/presentation/providers/settings_provider_test.dart` - Removed toggle tests
- `songbook_app/test/unit/data/models/view_config_test.dart` - Removed `isNotationWithoutChords`/fourth-state tests; added normalization test; updated round-trip test to only cover the three presets
- `songbook_app/test/unit/data/repositories/settings_repository_test.dart` - Updated "reads a stored override for the right song key" to expect `ViewConfig.sheetMusic()`

## Decisions Made
- Custom view removed entirely (not fixed) per the plan's UAT-driven user decision — its only unique state was a dead end with broken entry/exit logic
- Legacy "true:false" persisted data normalized silently at the parsing boundary rather than migrated/logged, since it's a rare and harmless state collapse
- Reset button and offset label always rendered (Visibility-hidden, not conditionally removed) to guarantee fixed-position carousel behavior

## Deviations from Plan

None - plan executed exactly as written. Both tasks matched their `<action>` specifications precisely, including the exact test updates called out in the plan (song_provider_test "per-song override wins over the global setting" and settings_repository_test "reads a stored override for the right song key").

## Issues Encountered

None. All edits applied cleanly on first pass; `flutter analyze` showed only pre-existing RadioListTile deprecation infos (unrelated to this plan, already tracked in STATE.md Blockers/Concerns); full `flutter test` suite (364 tests) passed after both tasks.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Both UAT gaps (Custom view dead end, transpose layout shift) are closed and verified via `flutter analyze` + full test suite
- No remaining references to `toggleNotation`, `toggleChords`, `isCustomSelected`, or `isNotationWithoutChords` in `lib/`
- Plans 04-04 and 04-05 (also part of this gap-closure wave) are independent of this plan's changes
- No blockers for subsequent phases

---
*Phase: 04-controls-ui-redesign*
*Completed: 2026-07-20*
