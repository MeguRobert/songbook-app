# Phase 09 Verification: Tags & Search

**Date:** 2026-06-13 (overnight, unattended)
**Branch:** `claude/phase-9-tags-search` (off `claude/phase-8-setlists`)
**Verifier:** Claude (Opus 4.8) — goal-backward analysis against ROADMAP success criteria.

> **Visual UAT is PENDING Robert's morning review.** No device/emulator/browser was available
> overnight, so this verification covers code-level evidence (file:line + tests + analyze) only.
> See "How to UAT in 5 minutes" in PHASE9-REPORT-2026-06-13.md for click-through steps.

## Quality Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | 8 issues — all pre-existing `info` RadioListTile deprecations in `settings_screen.dart`. **No new issues** from Phase 9 code. |
| `flutter test` | **81/81 pass** (15 new Phase 9 tests + 66 pre-existing; no regressions). |

## Success Criteria → Evidence

### Criterion 1 — Songs can have multiple tags (praise, communion, Christmas, etc.) ✅
- `Song.tags` (`List<String>`, JSON `defaultValue: []`): `lib/data/models/song.dart:130` (serializer
  `song.g.dart:60-61,76`). Pre-existing field; now made editable + surfaced.
- Bundled data already carries tags: `assets/data/songs.json` — all 8 songs have 2–3 tags
  (e.g. 300 → `karácsony`, `advent`, `imádás`).
- Editing replaces the full tag set per song (multi-tag), persisted as an override (criterion #4).

### Criterion 2 — Search supports filtering by tag ✅
- `SearchService.filterByTags(songs, tags, {matchAll})` (multi-tag AND/OR, case-insensitive):
  `lib/domain/services/search_service.dart:96`.
- `SearchState.activeTags` + `SearchNotifier.toggleTag/setTags/clearTags` + `_recompute()` (tags AND,
  then query narrows): `lib/presentation/providers/search_provider.dart:15,61,90,101`.
- Search screen renders active tags as removable `InputChip`s and shows the results area whenever a
  query OR tags are active: `lib/presentation/screens/search/search_screen.dart` (`_buildTagChips`,
  `isFiltering`).
- Deep link: `/search?tag=<name>` seeds the filter (`app_router.dart:95`, `searchWithTag` `:32`).
- Tests: `test/presentation/providers/search_tags_test.dart` — toggle, single tag, AND across two
  tags, tag-only (empty query), query+tag combo, clear; `test/domain/services/search_service_tags_test.dart`
  (filterByTags AND/OR + case-insensitivity).

### Criterion 3 — Tag browser shows all available tags with song counts ✅
- `SearchService.tagsWithCounts(songs)` (distinct, counts, case-insensitive grouping, count-desc
  order): `lib/domain/services/search_service.dart:65`.
- `tagsProvider` derives the list from the effective (override-merged) songs:
  `lib/presentation/providers/tag_provider.dart:74`.
- `TagBrowserScreen` (`/tags`): one `ListTile` per tag with `"<n> song(s)"`, tap → filtered search:
  `lib/presentation/screens/tags/tag_browser_screen.dart`. Route `app_router.dart:106-108`.
- Entry point: `sell_outlined` action in the song-list app bar →
  `lib/presentation/screens/song_list/song_list_screen.dart:38-41`.
- Tests: `test/presentation/screens/tag_browser_screen_test.dart` — renders a tile per tag with its
  count; empty-corpus → "No tags yet". `test/presentation/providers/tag_provider_test.dart` (counts).

### Criterion 4 — Tags are editable (add/remove from songs) ✅
- Per-song override persistence (bundled assets are read-only): `LocalDataSource`
  `song_tag_overrides` blob (`getTagOverrides/saveTagOverrides/setSongTags/clearSongTags`) +
  `TagRepository`: `lib/data/datasources/local/local_datasource.dart`, `lib/data/repositories/tag_repository.dart`.
- `TagOverridesNotifier.setTags/addTag/removeTag/clearOverride`:
  `lib/presentation/providers/tag_provider.dart:19,31,45,57`.
- `songsProvider` applies overrides (single source of truth) so edits propagate to list/search/browser:
  `lib/presentation/providers/song_provider.dart:17-19`.
- In-song editor: `label_outline` app-bar action → `TagEditorSheet` (add via field, remove via chip,
  Save / Reset to default): `lib/presentation/screens/song_view/song_view_screen.dart:63,95-99`,
  `lib/presentation/screens/song_view/widgets/tag_editor_sheet.dart`.
- Tests: `tag_repository_test.dart` (persist/clear/round-trip across a fresh instance);
  `tag_provider_test.dart` (setTags re-emits edited songs via songsProvider; addTag dedupe/blank;
  removeTag; setTags([]) clears; seed-from-prefs).

## Edge cases reviewed
- **Empty tags / blank input** → ignored on add; an empty tag set clears the override (no empty-list
  overrides stored). Tested.
- **Case-insensitivity** → grouping, filtering, add-dedupe, and remove all fold case; display keeps
  first-seen casing ("Luther", not "luther"). Tested.
- **No overrides** → `applyTagOverrides` returns the same list reference; existing behavior unchanged
  (no regressions; 81/81). Tested (`identical` assertion).
- **Tag-only search** (empty query, active tags) → shows all songs carrying those tags. Tested.
- **Hungarian diacritics in tags** (`karácsony`, `bűnbánat`) → handled as plain strings; matching is
  `toLowerCase()` (no diacritic stripping needed for exact-tag membership).
- **Stale override** (song no longer in corpus) → harmless; merge only touches songs by number.

## Outstanding / deferred
- **Visual/on-device UAT** — appearance of chips, browser, and the editor sheet; navigation feel
  (tag → search; editor Save reflecting on the list). Pending morning review.
- Inline read-only tag chips on the song view were omitted (kept the view uncluttered) — tags are
  viewed/edited via the app-bar editor and the browser. Trivial to add if desired.
- Tag-filter uses AND only (no in-UI AND/OR toggle); `filterByTags` already supports OR if wanted.
- See PHASE9-REPORT "Decisions for the morning" for judgment calls.
