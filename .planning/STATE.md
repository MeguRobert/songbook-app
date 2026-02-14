# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** Musicians can view any song with accurate chords and sheet music, transpose it to any key, and sing or play from the app during worship
**Current focus:** Phase 2 complete — next: Phase 3 (Presentation Mode)

## Current Position

Phase: 2 of 11 (Configurable Song View) — COMPLETE
Plan: 2 of 2 in current phase
Status: Complete
Last activity: 2026-02-14 — Completed Phase 2 (Configurable Song View)

Progress: [██░░░░░░░░] 18% (2/11 phases)

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 8 min
- Total execution time: 0.5 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01    | 2     | 18min | 9min     |
| 02    | 2     | 18min | 9min     |

**Recent Trend:**
- Last 5 plans: 3min, 15min, 4min, 14min
- Trend: Consistent velocity (~9min avg)

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: Local-first architecture for MVP, cloud backend deferred to v2.0
- [Init]: Books as primary organization model (matching physical hymnal structure)
- [Init]: Configurable overlay view preferred over separate view modes
- [01-01]: Symmetric transpose range -6 to +5 (12 semitones total, no duplicate pitch at +6/-6)
- [01-01]: Dart record types for structured SVG fallback state
- [01-02]: Center + ConstrainedBox(maxWidth: 600) pattern for responsive centered layout
- [01-02]: Never modify provider state in dispose(); rely on fresh state creation in openSong()
- [02-01]: ViewConfig two-toggle model (showNotation + showChords) with lyrics always visible
- [02-01]: Per-song overrides stored as nullable activeViewConfig (null = use global default)
- [02-01]: Storage format uses colon-delimited string "notation:chords" for SharedPreferences
- [02-02]: ChordView accepts showChords as direct parameter (parent controls, not provider)
- [02-02]: Reuse ChordView with showChords=false for lyrics-only view
- [02-02]: Flexible + SingleChildScrollView for dynamic-height floating menus

### Pending Todos

None yet.

### Blockers/Concerns

- No test coverage — changes carry regression risk (unchanged from init, still applies)
- RadioListTile API deprecation warnings in settings_screen.dart (Flutter 3.32+ info-level)

## Session Continuity

Last session: 2026-02-14
Stopped at: Completed Phase 2 (Configurable Song View) — all 5 success criteria verified
Resume file: None
