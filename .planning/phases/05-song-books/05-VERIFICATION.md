# Phase 05 Verification: Song Books

**Date:** 2026-06-13 (overnight, unattended)
**Branch:** `claude/phase-5-song-books`
**Verifier:** Claude (Opus 4.8) — goal-backward analysis against ROADMAP success criteria.

> **Visual UAT is PENDING Robert's morning review.** No device/emulator/browser was available
> overnight, so this verification covers code-level evidence (file:line + tests + analyze) only.
> See "How to UAT in 5 minutes" in the overnight report for click-through steps.

## Quality Gates

| Gate | Result |
|------|--------|
| `flutter analyze` | 8 issues — all pre-existing `info` RadioListTile deprecations in `settings_screen.dart`. **No new issues** from Phase 5 code. |
| `flutter test` | **18/18 pass** (11 BookService + 6 book providers + 1 existing placeholder). |

## Success Criteria → Evidence

### Criterion 1 — Songs are grouped by book/hymnal in the data model ✅
- `Song.book` optional field: `songbook_app/lib/data/models/song.dart:131-133` (+ `hasBook` getter
  `:166-167`, serializer `song.g.dart:62,77`).
- `BookService.booksFromSongs()` derives the ordered book list with counts:
  `songbook_app/lib/domain/services/book_service.dart:20-50`.
- Bundled data assigned: `songbook_app/assets/data/songs.json` — 8 songs across `Zsoltárok` (1/42/90)
  and `Dicséretek` (151/200/256/300/350).
- Tests: `test/domain/services/book_service_test.dart` (grouping, counts, ordering, null/empty edges).

### Criterion 2 — Book browser lets users select which book to browse ✅
- `BookBrowserScreen`: `songbook_app/lib/presentation/screens/books/book_browser_screen.dart`
  — lists "All Songs" + each `Book` (name, count, check mark on active selection).
- Route `/books`: `songbook_app/lib/router/app_router.dart:20` (`AppRoutes.books`), GoRoute `:82-87`.
- Entry point: book icon in song list app bar → `context.push(AppRoutes.books)`
  (`song_list_screen.dart:22-31`).
- `booksProvider` feeds the browser: `songbook_app/lib/presentation/providers/book_provider.dart:14-17`.

### Criterion 3 — Song list filters to show songs from the selected book ✅
- `filteredSongsProvider` filters by selection:
  `songbook_app/lib/presentation/providers/book_provider.dart:53-58`.
- Song list watches it: `song_list_screen.dart:16` and renders the filtered list.
- App bar reflects the active book (title = book name; filled `menu_book` icon when active):
  `song_list_screen.dart:20-31`.
- Tests: `test/presentation/providers/book_provider_test.dart` — "selecting a book filters the list
  and persists the choice", "selecting the Other bucket returns only unbooked songs".

### Criterion 4 — "All songs" view still available across all books ✅
- "All Songs" entry in the browser clears the filter:
  `book_browser_screen.dart` (All Songs ListTile → `selectedBookProvider.notifier.clear()`).
- `filterByBook(songs, null)` returns all songs: `book_service.dart:54`.
- Empty book → "Show all songs" recovery button: `song_list_screen.dart` `_EmptyState`.
- Search continues to search **all** songs (not the filtered set) by design:
  `search_provider.dart:55` reads `songsProvider`.
- Tests: "returns all songs when no book is selected", "clear() restores all songs and removes the pref".

### Criterion 5 — New songs can be assigned to a book during import ✅
- `convert_hymn.py` `--book/-b` arg + `update_songs_json(..., book=...)`:
  `tools/convert_hymn.py` (writes `song['book']` when provided; leaves existing book if omitted).
- Verified `python convert_hymn.py --help` lists `--book`.
- `.claude/skills/add-song.md` documents the parameter + usage example (on disk; `.claude` is
  gitignored so not committed).

## Bonus: Persistence across restart
- Selected book persists via `SettingsRepository` (`selected_book` key):
  `settings_repository.dart` (get/set/clear). `SelectedBookNotifier` seeds initial state from prefs:
  `book_provider.dart:25-27`.
- Test: "selectedBookProvider initial state reads a pre-seeded selected book from prefs".

## Edge cases reviewed
- **Songs with no book** → grouped under "Other", always present in All Songs (tested).
- **Empty-string book** → treated as unbooked / "Other" (tested via `hasBook`).
- **Empty book selection** → friendly empty state with "Show all songs" recovery.
- **Stale persisted book name** (book no longer present): `filterByBook` returns empty → recoverable
  via the empty-state button. App bar would show the stale name until cleared (minor; acceptable).
- **Favorites & search** span all books (unaffected by the filter) — intentional.

## Outstanding / deferred
- Visual UAT (appearance, navigation feel) — pending morning review.
- See the overnight report's "Decisions for the morning" for judgment calls (book naming, browser
  placement vs. nav tab, search scoping).
