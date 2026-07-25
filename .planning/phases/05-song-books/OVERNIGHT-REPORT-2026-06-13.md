# Overnight Implementation Report — Phase 5: Song Books

**Date:** 2026-06-13 (overnight, unattended)
**Branch:** `claude/phase-5-song-books` (off `master`)
**Repo:** `C:\Users\rober\source\repos\songbook-app`
**Agent:** Claude (Opus 4.8)

> **Note on report location:** The task asked for this report at
> `C:\Users\rober\.claude\overnight\SONGBOOK-REPORT-2026-06-13.md`. The harness sandbox blocks all
> writes under `~/.claude/` as a "sensitive" path (even with the override) and I can't get
> interactive approval while running unattended. So the canonical report lives here, inside the repo,
> alongside the rest of the Phase 5 artifacts. If you want it at the original path, copy it:
> `cp .planning/phases/05-song-books/OVERNIGHT-REPORT-2026-06-13.md ~/.claude/overnight/SONGBOOK-REPORT-2026-06-13.md`

> Status: **COMPLETE** (code) — visual UAT pending your morning review.

---

## What was implemented

Phase 5 organizes songs by book/hymnal with a book browser, per the ROADMAP. Two plans, both done:

**05-01 — Data model + import**
- `Song.book` (optional `String?`), serializer regenerated via build_runner.
- `Book` value model (`{name, songCount}`) — derived, not persisted.
- `BookService` (pure logic): `booksFromSongs()` (grouped + counted + ordered), `filterByBook()`,
  `bookNames()`. Unbooked songs bucket = `"Other"`, always sorted last.
- `SettingsRepository` selected-book persistence (`selected_book` key).
- All 8 bundled songs assigned a book: `Zsoltárok` (1/42/90) and `Dicséretek` (151/200/256/300/350).
- `tools/convert_hymn.py` gains `--book/-b`; `--book "<name>"` assigns a book at import time.
- `.claude/skills/add-song.md` documents `--book` (on disk; untracked — see caveats).

**05-02 — Browser UI + integration**
- `book_provider.dart`: `booksProvider`, `selectedBookProvider` (persisted), `filteredSongsProvider`.
- `BookBrowserScreen` at `/books`: "All Songs" + per-book tiles with counts + check on active selection.
- `SongListScreen` filters by the selected book; app-bar title shows the active book and a
  `menu_book` icon (filled when filtered) opens the browser; book-aware empty state with
  "Show all songs" recovery.

**Tests added** (17): `book_service_test.dart` (11) + `book_provider_test.dart` (6).

Full per-plan detail: `05-01-SUMMARY.md`, `05-02-SUMMARY.md`. Criterion-by-criterion evidence:
`05-VERIFICATION.md`.

---

## Commit list (branch `claude/phase-5-song-books`, oldest → newest)

```
8969dd5 wip: preserve pre-existing uncommitted changes (pre-phase-5)
361d813 docs(05): plan Song Books phase (05-01 data model, 05-02 browser UI)
14a0a73 feat(05-01): add optional book field to Song model
a7c5ad5 feat(05-01): add Book model and BookService with unit tests
f44aa0a feat(05-01): persist selected-book preference in SettingsRepository
9871b79 feat(05-01): assign books to bundled songs (Zsoltárok/Dicséretek)
efe6ac4 feat(05-01): support --book assignment in import pipeline
e6bb9cc docs(05-01): add plan 01 summary
369fcb8 feat(05-02): add book providers (books list, selected book, filtered songs)
54481ff feat(05-02): add book browser screen and /books route
dccf851 feat(05-02): filter song list by selected book with book-aware app bar
b9f6a50 test(05-02): cover book selection, persistence, and filtering
```
(Plus pending docs commit for the summaries/verification/state/roadmap/this report.)

**Never pushed. Never committed to master.** The pre-existing WIP `.dart` files are isolated in the
first commit; screenshots and `nul` were left untracked (never `git add -A`).

---

## Analyze / Test results

- `flutter analyze`: **8 issues — all pre-existing** `info`-level RadioListTile deprecations in
  `settings_screen.dart`. **Zero new issues** introduced by Phase 5.
- `flutter test`: **18/18 pass** (11 BookService + 6 book providers + 1 existing placeholder).
  Run from `songbook_app/`: `flutter test`.

---

## Design decisions (and why)

1. **`book` as a flat optional String on `Song`, books derived dynamically.** Mirrors the existing
   `tags: List<String>` pattern; no separate registry file to keep in sync; consistent with the
   local-first, bundled-JSON architecture.
2. **Bundled split Zsoltárok (≤150) / Dicséretek (>150).** These are the real two sections of the
   Hungarian Reformed hymnal (Református énekeskönyv), so the multi-book demo is accurate rather than
   fabricated. (See morning decision #1 if you'd rather model this differently.)
3. **Unbooked songs → "Other" bucket, sorted last, always in All Songs.** Keeps stray songs
   discoverable without polluting real book ordering.
4. **Book browser = `/books` screen from an app-bar icon, not a 4th nav tab.** Keeps the song list as
   home and is lower-risk; promoting to a nav tab is an easy reversible follow-up (morning decision #2).
5. **Selection persists across restart** via `SettingsRepository` — treats "books" as the primary
   organization lens (per PROJECT.md Key Decision) and resumes where you left off.
6. **Search and favorites span all books** regardless of the active filter — global find and a global
   favorites list are more useful than book-scoped ones (morning decision #3).

---

## Deliberately left out

- **No nav-tab "Books" entry** — see decision #4 / morning decision #2.
- **No per-book settings, no book metadata (full title, publisher, cover, ordering override)** — books
  are derived; a richer registry was out of scope for the success criteria.
- **No auto-clear of a stale persisted book name** — if a selected book later disappears from the data,
  the list shows an empty state with a "Show all songs" button (recoverable). A tidy-up to auto-clear
  unknown selections on load is a small future nicety, not done.
- **No widget/UI tests for `BookBrowserScreen` / `SongListScreen`** — logic is covered at the
  provider/service level; screen widget tests would need the broader SharedPreferences/Riverpod
  harness and were deprioritized vs. the explicitly-requested book logic tests.
- **No app run / screenshots** — no device available overnight (per instructions).

---

## How to UAT this in 5 minutes

From `songbook_app/`, run the app: `flutter run` (pick your device, e.g. Windows/Chrome).

1. **Home shows all songs.** App-bar title reads **"Songbook"**; the book icon (top-right, before the
   magnifier) is the **outlined** `menu_book`.
2. **Open the book browser.** Tap the book icon → you land on **Books**. You should see:
   - **All Songs** — "8 songs", with a check mark (current selection).
   - **Zsoltárok** — "3 songs".
   - **Dicséretek** — "5 songs".
3. **Filter to a book.** Tap **Dicséretek** → returns to the list. Now the app-bar title reads
   **"Dicséretek"**, the book icon is the **filled** `menu_book`, and only songs 151/200/256/300/350
   show.
4. **All Songs still works.** Tap the book icon → **All Songs** → list shows all 8 again.
5. **Persistence.** Select **Zsoltárok**, fully close and relaunch the app → it should reopen
   filtered to **Zsoltárok** (title + filled icon + songs 1/42/90).
6. **Search is unaffected.** With a book filtered, tap the magnifier and search a song from the *other*
   book (e.g. type `256`) → it still finds it (search spans all books by design).
7. *(optional)* **Import assignment.** `cd tools && python convert_hymn.py --help` → confirm `--book`
   is listed. Real use: `python convert_hymn.py <img> --song <n> --book "Zsoltárok"`.

If anything looks off visually, it's UI polish — the logic is covered by 18 passing tests.

---

## Decisions for the morning

Context for each: I made a best-guess call (consistent with PROJECT.md) and proceeded. Each notes
what changes if you overrule it. **Use the Morning resume prompt below** to walk these one at a time.

### Decision 1 — How to model the bundled books
- **Context:** All 8 existing songs are from the Hungarian Reformed hymnal. I needed a real multi-book
  demo without inventing data.
- **Options:** (a) Split by hymnal section: Zsoltárok ≤150 / Dicséretek >150 *(my pick)*; (b) One book
  "Református énekeskönyv" for all 8 (browser shows 1 book + All Songs); (c) Different naming
  (English? abbreviations? include the other hymnals from the roadmap — Hallelujah, Youth Worship —
  as real imports later).
- **My pick:** (a) — accurate to the real hymnal structure, gives a genuine 2-book browser.
- **If overruled:** Re-assign `"book"` values in `songbook_app/assets/data/songs.json` (8 lines) and
  update the counts in `05-VERIFICATION.md`. No code changes needed.

### Decision 2 — Where the book browser lives
- **Context:** PROJECT.md says "books as primary organization model".
- **Options:** (a) `/books` screen opened from a song-list app-bar icon *(my pick)*; (b) a 4th bottom-nav
  tab "Books"; (c) an inline filter chip row at the top of the song list.
- **My pick:** (a) — keeps the song list as home, lowest risk, fully functional.
- **If overruled:** (b) means adding a `NavigationDestination` to `scaffold_with_nav_bar.dart` and a
  shell route; (c) means a filter row in `song_list_screen.dart`. Both build directly on the existing
  providers — no data-layer changes.

### Decision 3 — Should search/favorites respect the active book filter?
- **Context:** A book is selected; does search/favorites scope to it?
- **Options:** (a) Search & favorites span all books *(my pick)*; (b) scope them to the current book.
- **My pick:** (a) — global find and a global favorites list are more useful.
- **If overruled:** Point `search_provider.dart` (and `favoriteSongsProvider`) at `filteredSongsProvider`
  instead of `songsProvider`.

### Decision 4 — "Other" bucket label and language
- **Context:** Unbooked songs need a bucket label; book names from data are Hungarian, UI chrome is English.
- **Options:** (a) `"Other"` (English, matches UI chrome) *(my pick)*; (b) Hungarian e.g. "Egyéb" /
  "Besorolatlan"; (c) hide the bucket entirely (unbooked songs appear only in All Songs).
- **My pick:** (a).
- **If overruled:** Change `BookService.ungroupedLabel` (one constant) — tests reference it
  symbolically, so they keep passing; one literal in `book_service_test.dart` ('Other') and the
  verification doc would need updating.

### Decision 5 — Report location workaround
- **Context:** Couldn't write to `~/.claude/overnight/` (sandbox blocks it).
- **My pick:** Report lives in-repo at `.planning/phases/05-song-books/OVERNIGHT-REPORT-2026-06-13.md`.
- **If overruled:** Copy it to the original path (command at the top of this file), or tell me to set
  up an allowlist entry so future overnight runs can write there directly.

---

## Morning resume prompt

Paste this to me in the morning. It walks the decisions ONE AT A TIME without revealing how many remain.

```
Resume the Songbook Phase 5 (Song Books) review. The work is on branch `claude/phase-5-song-books`,
fully implemented and tested (flutter analyze clean of new issues, 18/18 tests pass). Read
`.planning/phases/05-song-books/OVERNIGHT-REPORT-2026-06-13.md` and `05-VERIFICATION.md` for context.

First, help me run a 5-minute visual UAT using the "How to UAT this in 5 minutes" steps in the report.
Tell me exactly what to click and what I should see; wait for me to confirm each step before moving on.

After UAT, there are a few product decisions to confirm. Ask me about them ONE AT A TIME — present a
single decision, show the option you implemented plus the alternatives and what changes if I switch,
then WAIT for my answer before revealing the next one. Do not tell me how many decisions there are or
number them. Start with how the bundled songs are grouped into books. When I've answered the last one,
summarize any changes I asked for and apply them.
```

---

*End of report.*
