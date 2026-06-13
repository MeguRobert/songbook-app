---
phase: 09-tags-search
plan: 02
subsystem: presentation-ui
status: complete
tags: [flutter, dart, riverpod, go-router, search, ui]
dependencies:
  requires:
    - 09-01 (Tag model, SearchService tag logic, tagOverridesProvider, tagsProvider)
  provides:
    - tag filtering in search (activeTags + chips)
    - TagBrowserScreen + /tags route + song-list entry point
    - in-song TagEditorSheet (add/remove, persisted)
  affects: []
tech-stack:
  added: []
  patterns:
    - Tag browser mirrors BookBrowserScreen (list + counts + tap-to-filter)
    - Tag filter passed across navigation via /search?tag= query param
    - Tag editor reuses the showModalBottomSheet pattern (parity with SongControlsSheet)
key-files:
  created:
    - songbook_app/lib/presentation/screens/tags/tag_browser_screen.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/tag_editor_sheet.dart
    - songbook_app/test/presentation/providers/search_tags_test.dart
    - songbook_app/test/presentation/screens/tag_browser_screen_test.dart
  modified:
    - songbook_app/lib/presentation/providers/search_provider.dart
    - songbook_app/lib/presentation/screens/search/search_screen.dart
    - songbook_app/lib/router/app_router.dart
    - songbook_app/lib/presentation/screens/song_list/song_list_screen.dart
    - songbook_app/lib/presentation/screens/song_view/song_view_screen.dart
key-decisions:
  - decision: Tag filter integrated INTO the existing search (activeTags on SearchState) rather than a separate filtered-list screen
    rationale: Phase brief said extend search, not duplicate; one results surface combines query + tags
    date: 2026-06-13
  - decision: Multiple active tags use AND semantics
    rationale: Narrowing is the natural expectation when stacking filters; matches filterByTags(matchAll:true) default
    date: 2026-06-13
  - decision: Tag browser tap → /search?tag=<name> (query param), not in-screen state hand-off
    rationale: GoRouter-native, deep-linkable, no cross-route provider coupling
    date: 2026-06-13
  - decision: Tag editing via a bottom sheet opened from a song-view app-bar action (label icon)
    rationale: Parity with the Phase 4 controls sheet; keeps metadata editing discoverable but non-intrusive
    date: 2026-06-13
metrics:
  completed: 2026-06-13
  tasks: 5
  files: 9
---

# Phase 09 Plan 02: Tags & Search UI — Summary

**One-liner:** A tag browser (all tags + counts) reachable from the song list, tag filtering folded
into the existing search (removable chips + AND, combinable with the query), and an in-song tag
editor that persists edits through the 09-01 override layer.

## What Was Built

**Search tag filtering** (`search_provider.dart`) — `SearchState.activeTags` (transient Set) +
`hasTags`/`isFiltering`; `SearchNotifier` gains `toggleTag`/`setTags`/`clearTags` and a shared
`_recompute()` that filters by tags (AND) then narrows by the query. Empty query + active tags shows
all songs carrying those tags.

**Search screen** (`search_screen.dart`) — optional `initialTag` constructor param seeded from the
`/search?tag=` route param; a removable `InputChip` row + "Clear tags" above the results; results area
now shown whenever `isFiltering` (query OR tags).

**Tag browser** (`tag_browser_screen.dart`, `/tags`) — lists every `Tag` with its song count (mirrors
`BookBrowserScreen`); tapping a tag → `context.push(AppRoutes.searchWithTag(name))`. Empty-corpus
state included. Entry point: a `sell_outlined` action in the song-list app bar (next to Books).

**In-song tag editor** (`tag_editor_sheet.dart`) — a bottom sheet (parity with `SongControlsSheet`)
opened from a song-view `label_outline` app-bar action. Current tags as removable chips, a text field
to add (trim + dedupe), quick-add suggestion chips from the rest of the library, **Save** →
`tagOverridesProvider.setTags(...)`, **Reset to default** → `clearOverride(...)`.

## Task Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1,2 | Search tag filtering + chips + route-param seeding | 78fc2d5 |
| 3 | Tag browser + /tags + song-list entry | f8d910b |
| 4 | In-song tag editor sheet | 8c1d237 |
| 5 | Tests (search filter + browser) | 91d17aa |

## Quality Gates

- `flutter analyze`: **8 issues, all pre-existing** RadioListTile deprecation infos (baseline
  unchanged — no new issues).
- `flutter test`: **81/81 pass** (full suite; +15 new across 09-01/09-02, no regressions from the
  override-aware `songsProvider`).

## Deviations from Plan

- The in-song read-only tag chip row (optional in the plan) was omitted to keep the song view
  uncluttered — tags are viewed/edited via the app-bar editor. Counts/visibility are fully covered by
  the tag browser. Easy to add later if UAT wants tags visible inline.

## Next Plan Readiness

Phase 9 feature-complete (code). Remaining: visual/on-device UAT (no device overnight). See
09-VERIFICATION.md and PHASE9-REPORT-2026-06-13.md.
