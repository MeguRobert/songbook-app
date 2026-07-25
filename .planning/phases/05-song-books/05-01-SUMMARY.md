---
phase: 05-song-books
plan: 01
subsystem: data-model
status: complete
tags: [flutter, dart, json-serializable, riverpod, data-model, python-tooling]
dependencies:
  requires: []
  provides:
    - Song.book optional field
    - Book value model
    - BookService grouping/filtering logic
    - selected-book persistence (SettingsRepository)
    - convert_hymn.py --book import support
  affects:
    - 05-02-book-browser-ui
tech-stack:
  added: []
  patterns:
    - Derived value object (Book) computed from songs, not stored as a registry
    - Pure stateless domain service (BookService) mirroring SearchService
    - SharedPreferences string-setting reuse for selected-book persistence
key-files:
  created:
    - songbook_app/lib/data/models/book.dart
    - songbook_app/lib/domain/services/book_service.dart
    - songbook_app/test/domain/services/book_service_test.dart
  modified:
    - songbook_app/lib/data/models/song.dart
    - songbook_app/lib/data/models/song.g.dart
    - songbook_app/lib/data/repositories/settings_repository.dart
    - songbook_app/assets/data/songs.json
    - tools/convert_hymn.py
    - .claude/skills/add-song.md (untracked — .claude is gitignored)
key-decisions:
  - decision: book is a flat optional String on Song, books derived dynamically
    rationale: Consistent with existing `tags: List<String>` pattern; no separate registry to keep in sync; local-first
    date: 2026-06-13
  - decision: Songs ≤150 = "Zsoltárok", >150 = "Dicséretek"
    rationale: Matches the real two-section structure of the Hungarian Reformed hymnal (Református énekeskönyv); gives a genuine multi-book demo without fabricating data
    date: 2026-06-13
  - decision: Ungrouped songs bucket labelled "Other", always sorted last
    rationale: Books with no assignment stay discoverable; "All Songs" still shows them
    date: 2026-06-13
metrics:
  completed: 2026-06-13
  tasks: 7
  files: 9
---

# Phase 05 Plan 01: Book Data Model & Import — Summary

**One-liner:** Songs can now belong to a book; a pure BookService groups/filters them, the bundled
songs are assigned to Zsoltárok/Dicséretek, and the import pipeline accepts `--book`.

## What Was Built

**Song model** — added optional `String? book` (nullable, JSON round-trips via regenerated
`song.g.dart`), `bool get hasBook` getter, and `copyWith` support. Equality stays keyed on `number`.

**Book value model** (`book.dart`) — immutable `{name, songCount}` with equality; a derived UI
object, not persisted.

**BookService** (`book_service.dart`) — stateless, pure logic:
- `booksFromSongs()` groups songs into `Book`s with counts, ordered by lowest song number
  (Zsoltárok before Dicséretek), with the `Other` bucket always last.
- `filterByBook(songs, name)` — `null` → all songs; `'Other'` → unbooked songs; else exact match.
- `bookNames()` convenience.

**Selected-book persistence** — `SettingsRepository.getSelectedBook()/setSelectedBook()/clearSelectedBook()`
using the existing `settings_`-prefixed string-setting plumbing (key `selected_book`).

**Bundled data** — all 8 songs assigned a `book` (1/42/90 → Zsoltárok; 151/200/256/300/350 →
Dicséretek). Inserted as single lines after each title — diff is +8/-0, no reformatting.

**Import pipeline** — `convert_hymn.py` gains `--book/-b`; `update_songs_json(..., book=None)` writes
`song['book']` when provided. `add-song.md` documents the parameter and a usage example.

## Task Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Add `book` field to Song + regenerate serializer | 14a0a73 |
| 2,3,7 | Book model + BookService + unit tests | a7c5ad5 |
| 4 | Selected-book persistence | f44aa0a |
| 5 | Assign books in songs.json | 9871b79 |
| 6 | Import `--book` support | efe6ac4 |

## Quality Gates

- `flutter analyze`: **8 issues, all pre-existing** `info`-level RadioListTile deprecations in
  settings_screen.dart (baseline unchanged — no new issues).
- `flutter test`: **12/12 pass** (11 new BookService tests + existing placeholder).

## Deviations from Plan

- songs.json: avoided a full `json.dump` re-serialization (it expanded inline arrays and produced a
  noisy +128/-30 diff). Reverted and inserted the 8 `book` lines via targeted text replacement for a
  clean +8/-0 diff.
- `add-song.md` lives under `.claude/`, which is gitignored — the edit is on disk for Robert but not
  committed. `convert_hymn.py` (the functional change for criterion #5) is committed.

## Next Plan Readiness

Ready for 05-02 (book browser UI): Book/BookService/persistence all in place and tested. The UI plan
will add `book_provider.dart`, `BookBrowserScreen`, a `/books` route, and song-list filtering.
