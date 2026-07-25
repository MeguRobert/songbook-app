# Phase 9 — Tags & Search — Overnight Report (2026-06-13)

> **Canonical copy lives in-repo** (the sandbox may not be able to write
> `C:\Users\rober\.claude\overnight\`). If a copy exists there too, this in-repo file is the source
> of truth.

**Branch:** `claude/phase-9-tags-search` (off `claude/phase-8-setlists`). **Local only — never pushed,
no PR.** This is the last phase of the v1.1 milestone.

## What was implemented (code-complete)

Phase 9 adds thematic tagging + tag-aware search on top of the data the app already shipped (songs
already had a `tags` field and the search service already scored tag matches). The work made tags
**editable**, **browsable**, and **filterable**, with a single reactive source of truth.

**Data + logic (09-01)**
- `Tag` value object (name + count), derived like `Book`.
- Extended `SearchService` (no new parallel service): `tagsWithCounts`, multi-tag `filterByTags`
  (AND/OR, case-insensitive), and a pure `applyTagOverrides` merge.
- Per-song **tag-override persistence** — bundled `songs.json` is read-only, so user edits are stored
  as a `song_tag_overrides` JSON blob keyed by song number (`LocalDataSource` + `TagRepository`).
- `tagOverridesProvider` (set/add/remove/clear, seeded from prefs) + `tagsProvider` (counts).
- **`songsProvider` now applies overrides** — so the song list, search, favorites, and the tag
  browser all observe edited tags. With no edits it returns the bundled list unchanged.

**UI (09-02)**
- **Tag filtering in search** — `SearchState.activeTags`, removable chips + "Clear tags", AND
  semantics, combinable with the text query; tag-only (no query) shows all songs with those tags.
- **Tag browser** at `/tags` — every tag with its song count; tap → `/search?tag=<name>`. Reached via
  a new `sell_outlined` action in the song-list app bar (next to Books).
- **In-song tag editor** — `label_outline` app-bar action opens a bottom sheet: remove via chips, add
  via a text field (trim + dedupe), quick-add suggestions, **Save** / **Reset to default**.

## Commits (this phase)

```
8c819d8 docs(09): plans for tags & search (data layer + UI)
5b3add7 feat(09-01): Tag value model + SearchService tag aggregation/filtering/override merge
a9c77df feat(09-01): per-song tag override persistence + reactive tag providers
f300da6 test(09-01): tag logic, override persistence, and provider reactivity
78fc2d5 feat(09-02): tag filtering in search (chips + AND) and /search?tag= seeding
f8d910b feat(09-02): tag browser screen + /tags route + song-list entry point
8c1d237 feat(09-02): in-song tag editor sheet (add/remove, persisted)
91d17aa test(09-02): search tag-filtering and tag browser screen
```
(Plus the docs commit for summaries/verification/state — see `git log` after this report.)

## Quality gates

- **`flutter analyze`** → 8 issues, **all pre-existing** `info` RadioListTile deprecations in
  `settings_screen.dart`. No new issues from Phase 9.
- **`flutter test`** → **81/81 pass** (15 new Phase 9 tests; 66 pre-existing; no regressions from the
  override-aware `songsProvider`).

Each ROADMAP success criterion is mapped to file:line + tests in `09-VERIFICATION.md`.

## How to UAT in 5 minutes

`cd songbook_app && flutter run` (Chrome/Windows/emulator — whatever's handy), then:

1. **Tag browser** — On the song list, tap the new tag icon (🏷 `sell_outlined`) in the app bar.
   Expect a "Tags" list: `praise`-style tags with counts (e.g. `zsoltár 5 songs`, `karácsony 1 song`).
2. **Filter by tag** — Tap a tag (e.g. `zsoltár`). You land on Search showing only songs with that
   tag, with a removable chip up top. Type into the search box to narrow within the tag (e.g. a
   title fragment). Tap the chip's ✕ or "Clear tags" to drop the filter.
3. **Edit tags on a song** — Open any song → tap the tag icon (`label_outline`) in the app bar.
   In the sheet: remove a chip, add a new tag (type + Enter or the ＋), or tap a suggestion. **Save**.
4. **See the edit propagate** — Back out to the Tags browser: your new tag appears with a count;
   open Search and filter by it — the song is there.
5. **Persistence** — Hot-restart (or relaunch). The edited tags are still there (stored in
   SharedPreferences). **Reset to default** in the editor reverts a song to its bundled tags.

## Decisions for the morning

1. **Tag editing model = full-set override.** Editing a song writes its *entire* tag list as an
   override (bundled tags untouched on disk; "Reset to default" removes the override). Simple and
   robust. Alternative (add/remove deltas) only matters if bundled tags later change under an
   existing override — not a concern for a bundled-asset app. **Keep unless you foresee live-updating
   bundled tags.**
2. **AND semantics for multiple tag filters** (stacking narrows). No in-UI AND/OR toggle.
   `filterByTags` already supports OR — say the word if you want a toggle.
3. **Tag browser is an app-bar action, not a 4th/5th nav tab** — parity with Books (Phase 5) and
   Setlists (Phase 8). The song-list app bar now has Setlists, Books, Tags, Search.
4. **Tag browser → search hand-off via `/search?tag=` query param** (deep-linkable) rather than a
   dedicated filtered-list screen — folds into the one search surface, per the brief ("extend search,
   don't duplicate").
5. **Tags not shown inline on the song view** — kept the reading view uncluttered; tags are
   viewed/edited via the app-bar editor and the browser. If you'd like a read-only chip row under the
   title, it's a ~10-line add.
6. **Tag display casing** — grouping/matching are case-insensitive but display preserves first-seen
   casing (so "Luther" stays "Luther"). Bundled tags are mostly lowercase Hungarian; user-added tags
   keep whatever you type.
7. **No songs.json changes** — all 8 bundled songs already had tags, so no data edits were needed.

## What's NOT done (needs you / a device)

- **Visual/on-device UAT** (the 5-minute script above). No device/browser overnight.
- Optional polish: inline tag chips on the song view, AND/OR toggle, tag rename/merge across songs.
- Same standing items as prior phases: store submission, OMR/OCR accuracy, Phase 5/8 visual UAT.

## Resume pointer

Phase 9 is the final v1.1 phase and is **code-complete**. After morning UAT, the natural next move is
`/gsd:audit-milestone` + `/gsd:complete-milestone` for v1.1 (or address the visual-UAT backlog across
Phases 5/8/9 in one device session). Do **not** start Phase 10 (v2.0 Cloud Backend) without a
milestone close.
