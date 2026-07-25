---
phase: 05-song-books
plan: 02
subsystem: presentation-ui
status: complete
tags: [flutter, riverpod, gorouter, navigation, ui]
dependencies:
  requires:
    - 05-01-book-data-model
  provides:
    - booksProvider / selectedBookProvider / filteredSongsProvider
    - BookBrowserScreen + /books route
    - book-filtered song list
  affects: []
tech-stack:
  added: []
  patterns:
    - StateNotifier<String?> persisted via SettingsRepository for selection state
    - FutureProvider chaining (filteredSongsProvider depends on songsProvider + selectedBookProvider)
    - Full-screen GoRoute outside the shell (mirrors search route)
key-files:
  created:
    - songbook_app/lib/presentation/providers/book_provider.dart
    - songbook_app/lib/presentation/screens/books/book_browser_screen.dart
    - songbook_app/test/presentation/providers/book_provider_test.dart
  modified:
    - songbook_app/lib/router/app_router.dart
    - songbook_app/lib/presentation/screens/song_list/song_list_screen.dart
key-decisions:
  - decision: Book browser is a /books screen opened from a song-list app-bar icon (not a 4th nav tab)
    rationale: Keeps the song list as home; lower-risk, fully functional; promoting to a nav tab is a reversible follow-up
    date: 2026-06-13
  - decision: Selected book persists across restart via SettingsRepository
    rationale: Treats book as the primary organization lens (per PROJECT.md key decision); resumes where the user left off
    date: 2026-06-13
  - decision: Search and favorites continue to span all books regardless of filter
    rationale: Find-anything search and a global favorites list are more useful than scoping them to the current book
    date: 2026-06-13
metrics:
  completed: 2026-06-13
  tasks: 5
  files: 5
---

# Phase 05 Plan 02: Book Browser UI — Summary

**One-liner:** A `/books` browser lets users pick a book (or All Songs); the home list filters to it,
the app bar reflects the active book, and the choice persists across restarts.

## What Was Built

**Providers** (`book_provider.dart`):
- `bookServiceProvider` (the pure BookService).
- `booksProvider` — derives the ordered book list (with counts) from all songs.
- `selectedBookProvider` (`SelectedBookNotifier extends StateNotifier<String?>`) — seeds from
  persisted prefs; `select()` / `clear()` persist via SettingsRepository.
- `filteredSongsProvider` — all songs filtered by the current selection (null = All Songs).

**BookBrowserScreen** (`/books`):
- "All Songs" entry + one tile per book (name, `N songs`, check mark on the active selection).
- Tapping an entry updates the selection and pops back to the list.
- Loading / error states mirror SongListScreen.

**SongListScreen integration:**
- Watches `filteredSongsProvider` + `selectedBookProvider`.
- App bar title = selected book name or "Songbook"; a `menu_book` icon (filled when filtered)
  opens the browser.
- Book-aware empty state with a "Show all songs" recovery button.

## Task Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Book providers | 369fcb8 |
| 2,3 | Book browser screen + /books route | 54481ff |
| 4 | Filter song list + book-aware app bar | dccf851 |
| 5 | Provider tests | b9f6a50 |

## Quality Gates

- `flutter analyze`: **8 issues, all pre-existing** (no new).
- `flutter test`: **18/18 pass** (added 6 book-provider tests).

## Deviations from Plan

None of substance. The book browser is a screen reached from the app bar (as planned); promoting it
to a dedicated nav tab is flagged as a morning decision rather than implemented.

## Notes / Concerns

- Visual UAT pending (no device overnight).
- A persisted book name that later disappears from the data shows an empty list with a recovery
  button — acceptable, but a future tidy-up could auto-clear unknown selections on load.
