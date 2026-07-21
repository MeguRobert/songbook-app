# Phase 5: Song Books - Context

**Gathered:** 2026-07-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Organize songs by hymnal/book (Hallelujah, Reformed, Youth Worship, etc.) with a book browser for navigating large collections. Delivers: a books data model, a book browser UI, book-filtered song browsing, an "All songs" view across books, and the ability for the import pipeline to assign songs to books.

Out of scope for this phase: setlists (Phase 8), tags/thematic filtering (Phase 9), cloud/custom user songbooks (Phase 11). Book *browsing and organization* only.
</domain>

<decisions>
## Implementation Decisions

### Book browser & navigation
- **Entry point:** New "Books" tab in the bottom navigation, alongside Songs / Favorites / Search / Settings.
- **Book presentation:** Cover-style cards in a grid — each card shows a color/cover placeholder, book name, and song count (bookshelf feel).
- **In-book view:** When browsing inside a book, the song-list app bar shows the book name, with a clear affordance to switch back to the browser or to another book (show book context, not just a silent filter).

### Song identity across books
- **Numbers repeat per book:** Each hymnal restarts numbering from 1. A song's *location* is identified by (book + number) together — number alone is NOT unique across the app.
- **Songs can appear in multiple books:** The same underlying song may exist in several books, possibly under a different number in each.
- **Stable per-song identity required:** Because of the two points above, each song needs a stable identity independent of book+number. The existing `int number` can no longer serve as the app-wide song identity. This affects favorites and routing (both currently key off `number`) — planning must introduce a stable song id.
- **Favorites are per-song (shared):** Favoriting a song marks it as favorited everywhere it appears, across all books.
- **Transpose / view / presentation state is per-song (shared):** Saved per-song state is the same regardless of which book the song was opened from.

### Selection & filtering behavior
- **Default launch view:** Songs tab always defaults to the combined "All songs" list across all books. Narrowing to a book is a deliberate action via the Books tab.
- **"All songs" access:** Claude's discretion on the least-redundant mechanism (e.g. an "All songs" card in the Books browser and/or a clear-filter affordance in the in-book list).
- **Search scope:** Claude's discretion — decide based on the identity model and existing search UX. Given search must find a title anywhere and numbers now collide, a global search that labels each result with its book is the likely fit; confirm during planning.

### Book data & import
- **Book definitions:** A separate `books.json` manifest lists each book with id, display name, display order, and cover color. Songs reference a book by id.
- **Assignment model:** Each song carries a **list of `{book, number}` placements** — supports multi-book membership with a different number per book. This is the schema shape to design toward.
- **Existing data migration:** The ~8 songs currently in `songs.json` get assigned to a single placeholder/default book for now; real per-song book assignment happens during future import work.
- **Import pipeline:** New songs must be assignable to a book (via placements) during import. This phase ensures the schema and data support it; deep import-workflow improvements are Phase 7.

### Favorites screen
- **Grouped by book:** The Favorites screen sections favorites under book headers.

### Claude's Discretion
- Exact "All songs" re-entry mechanism (browser card vs. in-list clear button vs. both).
- Search scope resolution (global-with-labels vs. active-book), consistent with the identity model.
- Card grid layout details, cover-color assignment, and empty/loading states for the browser.
- How the stable song id is represented (generated id vs. derived) and the favorites/routing migration path.
</decisions>

<specifics>
## Specific Ideas

- Books should feel like a bookshelf — cover-style cards, not a plain settings list.
- The app should still feel unchanged for someone who just wants "all songs" — that's the default; books are an opt-in layer on top.
- Realistic hymnal semantics drive the model: numbers restart per book, and a song can live in more than one hymnal under different numbers.
</specifics>

<deferred>
## Deferred Ideas

- Setlists / ordered service lists — Phase 8 (depends on books existing).
- Thematic tags and advanced filtering — Phase 9.
- User-created custom songbooks and sharing — Phase 11 (needs cloud backend).
- Deep import-pipeline accuracy/batch improvements — Phase 7 (this phase only ensures books are assignable).
</deferred>

---

*Phase: 05-song-books*
*Context gathered: 2026-07-21*
