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
| S6 | MED-HIGH | Favorites screen repeats the drag-handle overlap class fixed in setlists, **and** its `onReorder` throws the result away (`reorderFavorites` exists, zero callers; `favoriteSongsProvider` ignores `sortOrder`) | `favorites_screen.dart:58-68` | ⏳ DECISION |
| S7 | MED | Per-song view config wired end-to-end but **no UI caller** — `saveViewConfigForSong` has zero callers, so in-song preset choices persist nowhere. `clearViewConfigForSong` also can't work (`copyWith(activeViewConfig: null)` is a no-op via `?? this.activeViewConfig`). 04-03-PLAN.md:136 asserted the preset chips call it — false. | `song_provider.dart:165-182` | ⏳ DECISION |
| S8 | MED | Entering search from the tag browser AND-filters against a stale, invisible query (`searchProvider` is global, never reset on screen entry) | `search_screen.dart:20-36` | ⏳ |
| S9 | MED | Open search results don't refresh after a tag edit (`read` not `watch` on `songsProvider`) | `search_provider.dart:101` | ⏳ |
| S10 | MED | Setlist playback bar is global to every song view and never auto-stops — Back out, open an unrelated song, the bar still reads "2 / 5" and Next jumps into the setlist | `song_view_screen.dart:304`, `setlist_nav_bar.dart:17-18` | ⏳ DECISION |
| S11 | MED-LOW | Auto-scroll keeps running under presentation mode (no `TickerMode` gating) → returning lands somewhere unexpected | `song_view_screen.dart:207` | ⏳ |
| S12 | MED-LOW | TRANSPOSE + CAPO stay live in Lyrics-only view where they change nothing visible | `song_controls_sheet.dart:139-205` | ⏳ |
| S13 | LOW | First frame of a newly opened song renders with the *previous* song's transpose/zoom/preset (`addPostFrameCallback`) | `song_view_screen.dart:67-73` | ⏳ |
| S14 | LOW | One corrupt record silently wipes an entire collection (`catch (_) { return [] }` around whole-list `map`) — all favorites / setlists / recents / tag overrides | `local_datasource.dart:64,117,141,182` | ⏳ |
| S17 | LOW | ~15 orphaned exports never called from `lib/` (incl. `getDefaultTranspose` loaded but never applied, and the whole `widgets/transpose_controls.dart`) | various | ⏳ cleanup |
| S20 | INFO | No `autoDispose` anywhere; `songByNumberProvider` caches every song opened for the process lifetime | — | ⏳ |

**No key collisions found.** `favorites`, `setlists`, `song_tag_overrides`, `recent_songs`
are distinct; everything else is namespaced under `settings_`. Repositories decode fresh
instances on every read, so `setlistByIdProvider`'s value-equality fix works as designed.

## E2E flow verdicts (as audited, before the fixes above)

| Flow | Verdict |
|---|---|
| (a) book → filter → open → transpose → presentation | Broken on web by S1. Chain otherwise sound. **Note: transposition does not reach presentation mode at all** (lyrics-only slides) — confirm intended. |
| (b) create setlist → add → reorder → play next/prev | Works, rough edges: each Next resets preset/transpose (S13), bar never auto-stops (S10), reorder could drop unknown numbers (S18). |
| (c) search by text and tag → open → edit tags → counts update | Counts *do* update correctly. Broken by S3, S4, S8, S9. |
| (d) open songs → recents rail → Continue | **Works.** |
| (e) start auto-scroll → switch preset → navigate away | Broken by S5, S2, S1. |
