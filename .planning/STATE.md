# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** Musicians can view any song with accurate chords and sheet music, transpose it to any key, and sing or play from the app during worship
**Current focus:** Phase 9 (Tags & Search) complete (code) overnight 2026-06-13 — v1.1 milestone code-complete. Next: visual UAT across Phases 5/8/9 + v1.1 audit/close, or v1.0 store submission. On-device/store-submission and OMR/OCR accuracy pending Robert.

## Current Position

Phase: 9 of 12 (Tags & Search) — COMPLETE (codeable slice; visual/on-device UAT pending) — last v1.1 phase
Plan: 2 of 2 in current phase
Status: Complete (code) — implemented overnight 2026-06-13 on branch claude/phase-9-tags-search
Last activity: 2026-06-13 — Completed Phase 9 (tag model/logic/persistence + tag browser + tag-filtered search + in-song tag editor)

Progress: [████████░░] 75% (9/12 phases, 18/24 plans)

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
- [06-01]: Use Flutter meetsGuideline() matchers (tap-target size + labeled tap targets) as the automated a11y gate
- [06-01]: Relabel icon/letter-only controls via Semantics(label:, excludeSemantics:) + tooltips, preserving compact visuals
- [06-02]: App display name "Songbook"; ids stay com.songbook.songbook_app; version 1.0.0+1
- [06-02]: Zero Android runtime permissions (offline/local-first), documented in manifest
- [06-02]: Icon/splash via standalone generator config files, NOT pubspec deps (offline-safe); deps added later via `flutter pub add`
- [07-01]: Pure-stdlib Python validator (no pip); unrecognized key = warning (OCR-tolerant), schema errors = error
- [07-02]: Validation gate aborts import write on errors (warnings print); `--no-validate` override
- [07-02]: batch_import uses injectable runner so orchestration is unit-tested without spawning processes
- [08-01]: Setlist references songs by number (List<int>), not embedded Song objects (consistent with Favorite/Book)
- [08-01]: Stable id `sl_${microsecondsSinceEpoch}` generated by the repository; setlists stored as one JSON blob under `setlists` key
- [08-01]: Equality keyed on id only; repository mutators are no-ops returning false for unknown ids
- [08-02]: Playback is a separate provider (setlistPlaybackProvider) with pure navigation math; song view only reads it
- [08-02]: Next/Previous use pushReplacement(songPath) + initState jumpTo() to resync the cursor; reuses /song/:id unchanged
- [08-02]: SetlistNavBar self-hides (SizedBox.shrink) and is always set as bottomNavigationBar — no conditional Scaffold logic
- [08-02]: Setlists entry is a song-list app-bar action (queue_music), not a 4th nav tab (parity with Books in Phase 5)
- [09-01]: Tag logic extends SearchService (tagsWithCounts/filterByTags/applyTagOverrides), not a new parallel service (per brief: extend search)
- [09-01]: Tag edits = full-set override per song stored as `song_tag_overrides` blob (bundled tags read-only); empty set clears the override
- [09-01]: songsProvider applies tag overrides — single source of truth so list/search/favorites/browser all see edits; empty overrides = same list (no behavior change)
- [09-01]: Tag grouping/matching case-insensitive; display preserves first-seen casing ("Luther" not "luther")
- [09-02]: Multiple tag filters use AND semantics; filterByTags supports OR but no in-UI toggle
- [09-02]: Tag browser → search via /search?tag= query param (deep-linkable), folded into the one search surface
- [09-02]: Tags entry is a song-list app-bar action (sell_outlined), not a nav tab (parity with Books/Setlists); in-song editing via a bottom sheet (parity with controls sheet)

### Pending Todos

None (redesign-song-controls-ui todo completed by Phase 4)

### Blockers/Concerns

- Phase 9 visual UAT pending — implemented overnight without a device/browser; see
  `.planning/phases/09-tags-search/PHASE9-REPORT-2026-06-13.md` for a 5-minute UAT script + morning
  decisions. Tag browser, tag-filtered search (chips/AND), and the in-song tag editor have automated
  logic + widget coverage but have not been seen rendered.
- Phase 8 visual UAT pending — implemented overnight without a device/browser; see
  `.planning/phases/08-setlists/PHASE8-REPORT-2026-06-13.md` for a 5-minute UAT script + morning decisions.
  Drag-to-reorder and the in-service Next/Previous flow have automated logic coverage but have not been
  seen rendered.
- Phase 5 visual UAT pending — implemented overnight without a device/browser; see
  `.planning/phases/05-song-books/OVERNIGHT-REPORT-2026-06-13.md` for 5-minute UAT steps + morning decisions.
- Test coverage growing: book logic (17) + setlist (30, Phase 8) + tag logic/persistence/providers/
  search-filter/browser-widget (15, Phase 9). 81 tests total. Broader screen/widget coverage still partial.
- RadioListTile API deprecation warnings in settings_screen.dart (Flutter 3.32+ info-level) — 8 pre-existing analyze infos, unchanged.
- Pre-existing WIP (5 modified .dart files) preserved as commit 8969dd5 at the base of the Phase 5 branch.
- `.claude/skills/add-song.md` edit (import --book docs) is on disk but untracked (`.claude` is gitignored).

## Session Continuity

Last session: 2026-06-13 (overnight, unattended)
Stopped at: Completed Phase 9 (Tags & Search) codeable slice on branch claude/phase-9-tags-search,
branched off claude/phase-8-setlists. v1.1 milestone (Phases 7-9) now code-complete. Local only
(never pushed). Visual UAT across Phases 5/8/9 is the remaining work (no device overnight).
Resume file: .planning/phases/09-tags-search/PHASE9-REPORT-2026-06-13.md (UAT script + morning decisions)
Next move after UAT: /gsd:audit-milestone + /gsd:complete-milestone for v1.1 (do NOT start Phase 10).
Note: the report's canonical path C:\Users\rober\.claude\overnight\ may be unwritable from the sandbox;
report kept in-repo (see its banner). Branches: phase-5 → … → phase-8 → phase-9 (stacked).
