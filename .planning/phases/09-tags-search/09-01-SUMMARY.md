---
phase: 09-tags-search
plan: 01
subsystem: data-model
status: complete
tags: [flutter, dart, riverpod, data-model, search, persistence]
dependencies:
  requires: []
  provides:
    - Tag value model
    - SearchService tag aggregation/filtering/override merge
    - per-song tag override persistence (LocalDataSource + TagRepository)
    - tagOverridesProvider + tagsProvider
    - override-aware songsProvider (single source of truth)
  affects:
    - 09-02-tags-search-ui
tech-stack:
  added: []
  patterns:
    - Derived value object (Tag) computed from songs, not stored as a registry (mirrors Book)
    - Tag logic extends the existing SearchService (no parallel service)
    - Single-blob override persistence keyed by song number (mirrors favorites/setlists)
    - Reactive single-source-of-truth: songsProvider merges overrides so all features observe edits
key-files:
  created:
    - songbook_app/lib/data/models/tag.dart
    - songbook_app/lib/data/repositories/tag_repository.dart
    - songbook_app/lib/presentation/providers/tag_provider.dart
    - songbook_app/test/domain/services/search_service_tags_test.dart
    - songbook_app/test/data/repositories/tag_repository_test.dart
    - songbook_app/test/presentation/providers/tag_provider_test.dart
  modified:
    - songbook_app/lib/domain/services/search_service.dart
    - songbook_app/lib/data/datasources/local/local_datasource.dart
    - songbook_app/lib/presentation/providers/providers.dart
    - songbook_app/lib/presentation/providers/song_provider.dart
key-decisions:
  - decision: Tag logic extends SearchService (tagsWithCounts/filterByTags/applyTagOverrides) rather than a new TagService
    rationale: Phase brief said extend the existing search service, not duplicate; SearchService already held getAllTags/filterByTag
    date: 2026-06-13
  - decision: A tag override REPLACES the bundled tags for that song (full set, not add/remove deltas)
    rationale: Uniformly models add AND remove; trivial merge; bundled assets are read-only so an override is the editable layer
    date: 2026-06-13
  - decision: songsProvider applies overrides (watches tagOverridesProvider) as the single source of truth
    rationale: Search, books, favorites, and the tag browser all read songsProvider — one merge point keeps every feature consistent and reactive; empty overrides return the same list (no behavior change)
    date: 2026-06-13
  - decision: Counts/matching are case-insensitive; display preserves first-seen casing
    rationale: "Luther" shouldn't render as "luther"; matches getAllTags case-folding for grouping
    date: 2026-06-13
metrics:
  completed: 2026-06-13
  tasks: 6
  files: 10
---

# Phase 09 Plan 01: Tag Data Model, Logic & Persistence — Summary

**One-liner:** Bundled `Song.tags` become editable via a per-song override layer; SearchService gains
tag counts + multi-tag filtering + a pure override merge; and `songsProvider` applies overrides so the
whole app sees edited tags through one source of truth.

## What Was Built

**Tag model** (`tag.dart`) — immutable `{name, songCount}` value object with equality; derived, not
persisted (mirrors `Book`).

**SearchService tag logic** (extended, not duplicated):
- `tagsWithCounts(songs)` — distinct tags with counts, case-insensitive grouping, first-seen casing
  preserved; ordered by count desc then name.
- `filterByTags(songs, tags, {matchAll})` — multi-tag AND/OR filtering, case-insensitive; empty set
  → all songs.
- `applyTagOverrides(songs, overrides)` — pure merge; empty map returns the same list reference.
- Existing `search`/`filterByTag`/`getAllTags` left intact.

**Override persistence** — `LocalDataSource` gains a `song_tag_overrides` JSON blob
(`getTagOverrides`/`saveTagOverrides`/`setSongTags`/`clearSongTags`), wrapped by a new `TagRepository`
(`getOverrides`/`setTags`/`clearOverride`/`hasOverride`).

**Providers** — `tagRepositoryProvider`; `tagOverridesProvider`
(`StateNotifier<Map<int,List<String>>>`, seeded from persistence, with `setTags`/`addTag`/`removeTag`/
`clearOverride`); `tagsProvider` (counts from effective songs). `songsProvider` now merges overrides
(watches `tagOverridesProvider`).

## Task Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1,2 | Tag model + SearchService tag logic | 5b3add7 |
| 3,4,5 | Override persistence + reactive providers | a9c77df |
| 6 | Unit tests | f300da6 |

## Quality Gates

- `flutter analyze`: **8 issues, all pre-existing** RadioListTile deprecation infos in
  settings_screen.dart (baseline unchanged — no new issues).
- `flutter test` (new files): **20/20 pass** (tag logic, persistence round-trip, provider reactivity).

## Deviations from Plan

- None material. `tag_provider_test` uses a `_FakeSongRepository extends SongRepository` override (so
  `songsProvider`'s real merge runs against fixtures) rather than overriding `songsProvider` directly —
  this is what lets the test prove the override actually propagates through `songsProvider`.

## Next Plan Readiness

Ready for 09-02 (UI): Tag/SearchService/overrides/providers are in place and tested. 09-02 adds
SearchState tag filtering, the search-screen chips, `TagBrowserScreen` + `/tags`, and the in-song
`TagEditorSheet`.
