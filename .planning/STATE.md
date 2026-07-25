# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** Musicians can view any song with accurate chords and sheet music, transpose it to any key, and sing or play from the app during worship
**Current focus:** Phase 5 (Song Books) integrated into master — next: Phase 6 (Store Release Prep). Phases 5+ still await hands-on UAT.

## Current Position

Phase: 5 of 12 (Song Books) — COMPLETE (code + verifier; hands-on UAT pending)
Plan: 2 of 2 in current phase
Status: Complete — implemented overnight 2026-06-13, merged to master 2026-07-25
Last activity: 2026-07-25 — Integrated Phase 5 into master (convergent Custom-removal conflicts resolved in favour of Phase 4's verified code)

Progress: [█████░░░░░] 42% (5/12 phases, 13/24 plans)

## Performance Metrics

**Velocity:**
- Total plans completed: 13
- Average duration: ~5 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01    | 2     | 18min | 9min     |
| 02    | 2     | 18min | 9min     |
| 03    | 2     | 5min  | 2.5min   |
| 04    | 5     | ~40min| 8min     |
| 05    | 2     | overnight | — |

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
- [04-02]: Presentation mode button in app bar (fullscreen icon, before favorite)
- [04-02]: isScrollControlled: true for bottom sheet to prevent overflow
- [04-03]: Custom view chip/toggles removed entirely (dead-end state per UAT) — bottom sheet View section is now exactly 3 presets
- [04-03]: ViewConfig.fromStorageString normalizes legacy "true:false" persisted data to sheetMusic() preset
- [04-03]: Visibility(maintainSize: true) pattern for fixed-position transpose Reset button/offset label in bottom-anchored sheet
- [04-04]: Scale entire sheet-music engraving via canvas.scale(textScale) rather than making EngravingConstants scale-aware
- [04-04]: Center header text against unscaled layout.totalWidth (not scaled CustomPaint size) to avoid double-scaling the offset
- [04-05]: Removed InteractiveViewer from chord/legacy-SVG views (was stealing pinch as matrix zoom); viewport meta user-scalable=no
- [04-05]: KEY WEB GOTCHA — desktop trackpad pinch / Ctrl+wheel arrives as PointerScaleEvent (a pointer signal), NOT handled by GestureDetector/ScaleGestureRecognizer. Fixed via Listener.onPointerSignal → setTextScale in song_view_screen.dart; GestureDetector retained for mobile touch. Verified with Playwright + instrumentation.
- [04-05]: Notation zoom is SMOOTH UNIFORM (user choice): layout computed once at viewport width and memoized (independent of textScale); zoom applied as pure visual scale (canvas.scale + scaled SizedBox). No re-wrap, no per-step relayout. Enlarged sheet scrolls horizontally (accepted trade-off vs re-fitting width). Ctrl+wheel notch uses a short eased animation to glide. NOTE: chords/lyrics text view still reflows on scale (not changed).
- [05-01]: `book` is a flat optional String on Song; books derived dynamically (like tags), no registry
- [05-01]: Bundled songs split Zsoltárok (≤150) / Dicséretek (>150) — real Hungarian Reformed hymnal sections
- [05-01]: Unbooked songs grouped under "Other", sorted last, always present in All Songs
- [05-01]: convert_hymn.py gains --book; assigns book during import (criterion #5)
- [05-02]: Book browser is a /books screen opened from a song-list app-bar icon (NOT a 4th nav tab)
- [05-02]: Selected book persists across restart via SettingsRepository (key selected_book)
- [05-02]: Search + favorites span all books regardless of the active book filter

Integration decisions (2026-07-25) are logged in `.planning/INTEGRATION-DECISIONS.md`.

### Pending Todos

- [Follow-up] Legacy "no sheet music" placeholder view renders plain-text verses that do NOT honor textScale (04-04 only wired the custom Canvas renderer). Chords/Lyrics presets scale fine. Low priority.
- [Follow-up] Consider adding `flutter test` as a CI gate now that the suite is tracked in git.

### Blockers/Concerns

- Hands-on UAT pending for Phase 5 onward — these phases were implemented unattended. Phase 4 passed its
  automated verifier 5/5 and still needed 4 gap fixes once exercised by hand, so treat "verified" as
  provisional until clicked through.
- RadioListTile API deprecation warnings in settings_screen.dart (Flutter 3.32+ info-level) — 8 pre-existing analyze infos, unchanged.
- `.claude/skills/add-song.md` edit (import --book docs) is on disk but untracked (`.claude` is gitignored).

## Session Continuity

Last session: 2026-07-25
Stopped at: Phase 5 merged into master. Test suite (336 previously-untracked tests) committed; CI Pages deploy fixed and live. Next: integrate Phase 6.
Resume file: None
