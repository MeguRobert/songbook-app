# Project State

> **This file is history, not status. Corrected 2026-08-22.**
>
> Everything below the Current Position block describes the GSD phase run that ended
> 2026-07-25, and it is kept for its decision log, which is still the best record of
> *why* the app's UI works the way it does. It is not a description of the app as it
> is now, and it went on claiming otherwise for four weeks — branches that were
> deleted, a test count a third of the real one, UAT blockers overtaken by a rebuild.
>
> **For what is actually true and what to do next, read `HANDOFF.md` and `backlog.md`.**
> They are the live queues. See also the "off-plan" note at the end of `ROADMAP.md`.

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-07)

**Core value:** Musicians can view any song with accurate chords and sheet music, transpose it to any key, and sing or play from the app during worship
**Current focus:** Not tracked here any more. As of 2026-08-22 the app is a Supabase-backed catalogue with optional accounts, a moderation queue, photo import, four-staff SATB engraving and a notation editor, localised into en/hu/ro, live on GitHub Pages. The named next items live in `HANDOFF.md` under "Outstanding, verified" — the top one is a native-speaker read of the Hungarian and Romanian strings, which is Robert's to do and not code.

## Current Position

Phase: the 12-phase plan stopped being the unit of work on 2026-07-28, when Songbook became a
multi-user platform. Phases 1–9 shipped as planned; 10–12 arrived off-plan and are annotated in
`ROADMAP.md` rather than ticked.
Status (2026-08-22): master is the only branch and is in sync with origin, at build 273. ~1200 Dart
tests and 317 Python tests green; `flutter analyze --no-fatal-infos` exits 0 with 0 issues.
Last GSD activity: 2026-07-25 — merged Phases 5,6,7,8,9 into master sequentially; fixed a search
regression found by the merge (see 09 fix below). Everything after that date is in git, not here.

Progress: 9 of 9 planned phases complete. The v2.0 phase count is no longer meaningful — see
`ROADMAP.md`.

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

Integration decisions (2026-07-25) are logged in `.planning/INTEGRATION-DECISIONS.md`.

### Pending Todos

- [Follow-up] Legacy "no sheet music" placeholder view renders plain-text verses that do NOT honor textScale (04-04 only wired the custom Canvas renderer). Chords/Lyrics presets scale fine. Low priority.
- [Follow-up] Consider adding `flutter test` as a CI gate now that the suite is tracked in git.

### Blockers/Concerns

**Every entry in this list is from 2026-06/07 and none of it is a live blocker. Overtaken as of
2026-08-22:** the three "visual UAT pending" items predate `tools/browser-smoke/`, which now walks
these screens in a real browser on demand and is the technique that has found every serious bug in
this app; the 81-test count is off by a factor of fifteen; and the branches the continuity note says
were never pushed were merged into master and deleted. Kept only so a future session can see what
was believed at the time. Live concerns are in `HANDOFF.md`.

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
- `.claude/skills/add-song.md` edit (import --book docs) is on disk but untracked (`.claude` is gitignored).

## Session Continuity

**Superseded. `HANDOFF.md` carries the current resume prompt.** The note below describes a stack of
branches (`claude/phase-5-song-books` → … → `claude/phase-9-tags-search`) that no longer exists:
all of it was merged into master on 2026-07-25 and the branches were deleted. master is now the only
branch. Do not act on the "next move" line.

Last session: 2026-06-13 (overnight, unattended)
Stopped at: Completed Phase 9 (Tags & Search) codeable slice on branch claude/phase-9-tags-search,
branched off claude/phase-8-setlists. v1.1 milestone (Phases 7-9) now code-complete. Local only
(never pushed). Visual UAT across Phases 5/8/9 is the remaining work (no device overnight).
Resume file: .planning/phases/09-tags-search/PHASE9-REPORT-2026-06-13.md (UAT script + morning decisions)
Next move after UAT: /gsd:audit-milestone + /gsd:complete-milestone for v1.1 (do NOT start Phase 10).
Note: the report's canonical path C:\Users\rober\.claude\overnight\ may be unwritable from the sandbox;
report kept in-repo (see its banner). Branches: phase-5 → … → phase-8 → phase-9 (stacked).
