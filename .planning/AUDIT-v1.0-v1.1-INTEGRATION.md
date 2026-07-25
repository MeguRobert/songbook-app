# Cross-Phase Integration Audit — v1.0 → v1.1

**Date:** 2026-07-25 · **Scope:** phases 1–9 + 3 shipped POCs on `master`
**Method:** code reading across every integration seam, plus throwaway probe tests that
empirically reproduced S1/S2. `flutter analyze` clean; suite green.

**Key point: no finding below is caught by analyze or the test suite** — every one lives
in a seam no test crosses. Phases 5–9 and the POCs were each built in isolation on
branches that predated phase 4's gap closure; these are the seams where they now meet.

## Status

| ID | Sev | Finding | Location | Status |
|----|-----|---------|----------|--------|
| S1 | CRITICAL | Merge spliced `dispose()`'s body into `_animateZoomTo` — one Ctrl+wheel zoom disposed the ticker + live ScrollController and marked the State defunct | `song_view_screen.dart:84-91` | ✅ FIXED `0991238` |
| S2 | CRITICAL | Real `dispose()` released only the zoom controller → ticker + ScrollController leaked; forever-ticking frame callback in release | `song_view_screen.dart:77-80` | ✅ FIXED `0991238` |
| S18 | HIGH (data loss) | Setlist reorder persists the *catalog-filtered* list, permanently deleting any entry not in songs.json | `setlist_detail_screen.dart:47-70` | ✅ FIXED |
| S3 | HIGH (data loss) | Tag editor seeded from un-merged `songByNumberProvider` → re-editing silently deletes earlier tag edits | `song_view_screen.dart:186`, `song_provider.dart:23-26` | ✅ FIXED |
| S4 | HIGH | Removing a song's last tag routes to `clearOverride`, resurrecting bundled tags — "no tags" unrepresentable | `tag_provider.dart:19-22` | ✅ FIXED |
| S5 | HIGH | Auto-scroll unstoppable: switching to Sheet Music hides both stop controls but leaves `isPlaying: true` and the ticker running | `song_view_screen.dart:168,190`, `song_controls_sheet.dart:257` | ✅ FIXED |
| S15 | LOW→trap | `RecentSong.==` ignores `viewedAt`; `Favorite.==` ignores `addedAt` **and `sortOrder`** — the exact class that broke `Setlist` | `recent_song.dart:34-41`, `favorite.dart:42-49` | ✅ FIXED (preemptive) |
| S16 | LOW | Auto-scroll speed slider writes SharedPreferences on every drag frame | `song_controls_sheet.dart:283` | ✅ FIXED |
| S19 | LOW | `TextEditingController` created per dialog, never disposed | `setlists_screen.dart:114` | ✅ FIXED |
| S6 | MED-HIGH | Favorites screen repeats the drag-handle overlap class fixed in setlists, **and** its `onReorder` throws the result away (`reorderFavorites` exists, zero callers; `favoriteSongsProvider` ignores `sortOrder`) | `favorites_screen.dart:58-68` | ✅ FIXED `584403a` |
| S7 | MED | Per-song view config wired end-to-end but **no UI caller** — `saveViewConfigForSong` has zero callers, so in-song preset choices persist nowhere. `clearViewConfigForSong` also can't work (`copyWith(activeViewConfig: null)` is a no-op via `?? this.activeViewConfig`). 04-03-PLAN.md:136 asserted the preset chips call it — false. | `song_provider.dart:165-182` | ✅ FIXED `584403a` |
| S8 | MED | Entering search from the tag browser AND-filters against a stale, invisible query (`searchProvider` is global, never reset on screen entry) | `search_screen.dart:20-36` | ✅ FIXED `584403a` |
| S9 | MED | Open search results don't refresh after a tag edit (`read` not `watch` on `songsProvider`) | `search_provider.dart:101` | ✅ FIXED |
| S10 | MED | Setlist playback bar is global to every song view and never auto-stops — Back out, open an unrelated song, the bar still reads "2 / 5" and Next jumps into the setlist | `song_view_screen.dart:304`, `setlist_nav_bar.dart:17-18` | ✅ FIXED `584403a` |
| S11 | MED-LOW | Returning from presentation mode teleports the song. **Premise corrected:** the ticker does NOT keep running — `Overlay` marks the covered entry `tickerEnabled:false` and `TickerMode` mutes it. But a muted `Ticker` keeps its start time, so the first tick back carries the whole absence as one `dt` (measured: 448 px for 10 s away). | `song_view_screen.dart:207` | ✅ FIXED |
| S12 | MED-LOW | TRANSPOSE + CAPO stay live in Lyrics-only view where they change nothing visible | `song_controls_sheet.dart:139-205` | ✅ FIXED |
| S13 | LOW | First frame of a newly opened song renders with the *previous* song's transpose/zoom/preset (`addPostFrameCallback`) | `song_view_screen.dart:67-73` | ✅ FIXED |
| S14 | LOW | One corrupt record silently wipes an entire collection (`catch (_) { return [] }` around whole-list `map`) — all favorites / setlists / recents / tag overrides | `local_datasource.dart:64,117,141,182` | ✅ FIXED (tag overrides were already per-entry safe) |
| S17 | LOW | ~15 orphaned exports never called from `lib/` (incl. `getDefaultTranspose` loaded but never applied, and the whole `widgets/transpose_controls.dart`) | various | ✅ PARTIALLY CLOSED — see below |
| S20 | INFO | No `autoDispose` anywhere; `songByNumberProvider` caches every song opened for the process lifetime | — | ✅ FIXED |

**No key collisions found.** `favorites`, `setlists`, `song_tag_overrides`, `recent_songs`
are distinct; everything else is namespaced under `settings_`. Repositories decode fresh
instances on every read, so `setlistByIdProvider`'s value-equality fix works as designed.

**All 20 findings are now closed.** Every one has a test that fails against the pre-fix
code, and S9, S11, S12 and S13 were additionally confirmed by driving the app in a browser.

## S17 — what was deleted, and what was deliberately kept

A full scan of `lib/` (public declarations with no other reference in `lib/`) surfaced far
more than the ~15 the audit estimated, but most are not dead code:

**Deleted:**
- `widgets/transpose_controls.dart` — 657 lines, five alternative transpose UIs from a
  design exploration (`TransposeControls`, `TransposeStyle`, `_TransposeSidePanel`). Zero
  references anywhere, including tests.
- The `defaultTranspose` setting — `SettingsKeys.defaultTranspose`, the repository
  getter/setter, the `SettingsState` field and `setDefaultTranspose`, plus their tests. It
  was loaded into state on every launch, applied nowhere, and had no Settings UI. Robert's
  call was delete rather than wire up: no roadmap criterion asks for a global default key.

**Kept, on purpose:**
- Tested-but-currently-uncalled service/repository API (`getSemitonesBetweenKeys`,
  `getSongsByNumbers`, `filterByTag`, `hasOverride`, `favoriteCount`, `wrapText`, …).
  Deleting these deletes their coverage to remove no runtime cost.
- Design-token catalogues (`app_typography`, `app_colors`, `engraving_constants`,
  `music_constants`). Unused entries in a token set are normal, not rot.
- `allTagsProvider`, which overlaps `tagsProvider` but returns a different shape.

## S11 — why the fix is a `dt` clamp and not `TickerMode` gating

The audit assumed the ticker kept running under presentation mode. It does not: `Overlay`
renders the entry below an opaque route with `tickerEnabled: false`, and `TickerMode` mutes
the ticker. A widget test asserts the scroll offset is unchanged across 10 s under a pushed
route. The damage came entirely from `Ticker` preserving its start time while muted.

The clamp is **250 ms**, deliberately far from a frame time. An earlier `1/30 s` clamp also
throttled genuinely slow rendering — a headless browser measured at 1.3 fps scrolled ~20×
too slowly, because at 768 ms per frame the clamp applies on *every* frame rather than only
after a gap. Nothing that is actually painting runs below 4 fps.

## E2E flow verdicts (as audited, before the fixes above)

| Flow | Verdict |
|---|---|
| (a) book → filter → open → transpose → presentation | Broken on web by S1. Chain otherwise sound. **Note: transposition does not reach presentation mode at all** (lyrics-only slides) — confirm intended. |
| (b) create setlist → add → reorder → play next/prev | Works, rough edges: each Next resets preset/transpose (S13), bar never auto-stops (S10), reorder could drop unknown numbers (S18). |
| (c) search by text and tag → open → edit tags → counts update | Counts *do* update correctly. Broken by S3, S4, S8, S9. |
| (d) open songs → recents rail → Continue | **Works.** |
| (e) start auto-scroll → switch preset → navigate away | Broken by S5, S2, S1. |
