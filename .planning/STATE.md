# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** Musicians can view any song with accurate chords and sheet music, transpose it to any key, and sing or play from the app during worship
**Current focus:** Phase 5 complete (code) — next: Phase 6 (Store Release Prep). Phase 5 visual UAT pending Robert's morning review.

## Current Position

Phase: 5 of 12 (Song Books) — COMPLETE (code; visual UAT pending)
Plan: 2 of 2 in current phase
Status: Complete — implemented overnight 2026-06-13 on branch claude/phase-5-song-books
Last activity: 2026-06-13 — Completed Phase 5 (Song Books)

Progress: [█████░░░░░] 42% (5/12 phases, 10/24 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 8
- Average duration: 5.4 min
- Total execution time: 0.72 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01    | 2     | 18min | 9min     |
| 02    | 2     | 18min | 9min     |
| 03    | 2     | 5min  | 2.5min   |
| 04    | 2     | 6min  | 3min     |

**Recent Trend:**
- Last 5 plans: 3min, 2min, 2min, 4min
- Trend: Excellent velocity (Phase 4: 3min average)

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
- [03-01]: SystemUiMode.immersiveSticky for full-screen presentation mode
- [03-01]: PageView + tap zones (left/right/center thirds) for verse navigation
- [03-01]: Auto-scaling text heuristic: availableWidth / (longestLine * 0.55) clamped 24-120px
- [03-01]: Local state projection mode toggle (black/white) vs app theme
- [03-01]: Auto-hide controls after 3s with center tap to toggle
- [03-02]: Projection mode persists in SharedPreferences (user preference across sessions)
- [03-02]: Responsive breakpoints: phone (<600), tablet (600-1024), desktop (>=1024)
- [03-02]: Landscape orientation centers text in middle 60% of width for projection screens
- [03-02]: Song title/number displayed at top of verses, fades with controls
- [03-02]: Single-verse songs hide verse indicator; long verses enable scrolling
- [04-01]: Material bottom sheet pattern for controls (showModalBottomSheet)
- [04-01]: Single FAB entry point with tune icon replaces 12-button floating column
- [04-01]: Pinch-to-zoom gesture for text scaling (GestureDetector onScaleUpdate)
- [04-01]: AnimatedSize for Custom toggles expand/collapse
- [04-02]: Presentation mode button in app bar (fullscreen icon, before favorite)
- [04-02]: isScrollControlled: true for bottom sheet to prevent overflow
- [05-01]: `book` is a flat optional String on Song; books derived dynamically (like tags), no registry
- [05-01]: Bundled songs split Zsoltárok (≤150) / Dicséretek (>150) — real Hungarian Reformed hymnal sections
- [05-01]: Unbooked songs grouped under "Other", sorted last, always present in All Songs
- [05-01]: convert_hymn.py gains --book; assigns book during import (criterion #5)
- [05-02]: Book browser is a /books screen opened from a song-list app-bar icon (NOT a 4th nav tab)
- [05-02]: Selected book persists across restart via SettingsRepository (key selected_book)
- [05-02]: Search + favorites span all books regardless of the active book filter

### Pending Todos

None (redesign-song-controls-ui todo completed by Phase 4)

### Blockers/Concerns

- Phase 5 visual UAT pending — implemented overnight without a device/browser; see
  `.planning/phases/05-song-books/OVERNIGHT-REPORT-2026-06-13.md` for 5-minute UAT steps + morning decisions.
- Test coverage now started: book logic covered (BookService + book providers, 17 new tests). Broader
  screen/widget coverage still absent.
- RadioListTile API deprecation warnings in settings_screen.dart (Flutter 3.32+ info-level) — 8 pre-existing analyze infos, unchanged.
- Pre-existing WIP (5 modified .dart files) preserved as commit 8969dd5 at the base of the Phase 5 branch.
- `.claude/skills/add-song.md` edit (import --book docs) is on disk but untracked (`.claude` is gitignored).

## Session Continuity

Last session: 2026-06-13 (overnight, unattended)
Stopped at: Completed Phase 5 (Song Books) on branch claude/phase-5-song-books — all 5 success criteria met at code level; visual UAT pending morning review
Resume file: .planning/phases/05-song-books/OVERNIGHT-REPORT-2026-06-13.md (has Morning resume prompt)
