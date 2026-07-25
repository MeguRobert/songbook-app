# Phase 8 — Setlists & Playlists — Overnight Report (2026-06-13)

> **Where this lives:** kept in-repo because the canonical overnight folder
> (`C:\Users\rober\.claude\overnight\`) may be sandbox-blocked. A copy is attempted there too.
> **Branch:** `claude/phase-8-setlists` (off `claude/phase-7-import-pipeline`). **Local only — never
> pushed, no PR.**

## TL;DR

Phase 8 is **code-complete**. Users can create named setlists, add/remove/reorder songs, and run a
setlist during a service stepping song-to-song with a Previous/Next bar. Everything persists across
restarts. `flutter analyze` is clean (8 pre-existing infos only) and **53/53 tests pass** (+30 new).
The only thing left is **visual/on-device UAT** (no device was available overnight) — 5-minute script
below.

## What was implemented

**08-01 — Data model + persistence**
- `Setlist` model (`data/models/setlist.dart` + hand-written `.g.dart`): `id`, `name`, ordered
  `List<int> songNumbers`, `createdAt`/`updatedAt`; `copyWith`, `length`/`isEmpty`, equality on `id`.
- `LocalDataSource.getSetlists()/saveSetlists()` — one JSON blob under the `setlists` key (mirrors
  favorites).
- `SetlistRepository` — `create / rename / delete / addSong (idempotent) / removeSong / reorderSongs /
  getById`. Unknown id → `false`, never throws.

**08-02 — UI + in-service playback**
- `setlist_provider.dart`: `SetlistsNotifier` (collection, persists via repo) + `setlistByIdProvider`
  + `SetlistPlaybackNotifier`/`setlistPlaybackProvider` (pure `start/next/previous/jumpTo/stop`
  navigation cursor). `setlistRepositoryProvider` added to `providers.dart`.
- `SetlistsScreen` (`/setlists`) — list + create (dialog) + rename/delete (popup + confirm) + empty
  state.
- `SetlistDetailScreen` (`/setlists/:id`) — `ReorderableListView` (drag to reorder, persisted),
  per-row remove, "Add songs" checkbox bottom sheet, Play action.
- `SetlistNavBar` — song-view `bottomNavigationBar`, visible only during playback: Previous /
  "name · pos/total" / Next / Close. Steps via `pushReplacement`; song view `initState` calls
  `jumpTo()` to keep the cursor synced.
- Routes `/setlists` + `/setlists/:id`; entry via a `queue_music` app-bar action on the song list.

## Commit list (8 commits, oldest → newest)

```
5f3e632 docs(08): plans for setlist data model + UI/playback
afdace8 feat(08-01): Setlist model with JSON serializer
988c8c0 feat(08-01): persist setlists + SetlistRepository CRUD/reorder
461669c test(08-01): Setlist model + repository unit tests (16 tests)
e19e17e feat(08-02): setlist collection + in-service playback providers
4777aa5 feat(08-02): setlists list + detail screens (reorder/add/remove/play)
23104e4 feat(08-02): in-service nav bar in song view, /setlists routes + entry point
812d009 test(08-02): setlist provider, playback, and screen tests
```
(Plus this report + SUMMARY/VERIFICATION/STATE/ROADMAP docs, committed separately.)

## Quality gates

- **`flutter analyze`** → `8 issues found`, all pre-existing `info`-level RadioListTile deprecations in
  `settings_screen.dart`. **No new issues** from Phase 8.
- **`flutter test`** → **`All tests passed!` (53/53)**. New: 5 model + 11 repository (08-01); 8 playback
  + 4 collection provider + 2 setlists-screen widget (08-02).

## Success criteria status (see 08-VERIFICATION.md for full mapping)

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Create a named setlist + add songs | ✅ code + tests (visual pending) |
| 2 | Reorder songs in a setlist | ✅ code + tests (drag UI visual pending) |
| 3 | "Next song" navigation during a service | ✅ code + tests (visual pending) |
| 4 | Setlists persist across restarts | ✅ code + tests (simulated-restart tests) |

## How to UAT in 5 minutes

Run the app (`cd songbook_app && flutter run`, or Chrome: `flutter run -d chrome`). Then:

1. **Create** — On the song list, tap the **♫ queue (Setlists)** icon in the app bar → tap the **+**
   FAB → name it "Sunday Morning" → Save. It should appear with "0 songs".
2. **Add songs** — Open "Sunday Morning" → tap the **+** FAB → check 3–4 songs in the sheet → close the
   sheet. They should appear in the detail list in the order added.
3. **Reorder** — Long-press a row's drag handle and drag it to a new position. Reopen the setlist (or
   hot-restart) and confirm the new order stuck (**persistence**).
4. **Remove** — Tap the ⊖ on a row; it disappears.
5. **Play (next-song nav)** — Tap the **▶ Play** action in the detail app bar. The first song opens with
   a bottom bar "Sunday Morning · 1/4". Tap **Next ▶** to advance (label → "2/4", song changes), **◀ Prev**
   to go back. **Close (✕)** hides the bar. Buttons disable at the ends (no wrap).
6. **Restart persistence** — Fully restart the app; your setlists and their order are still there.

Watch for: drag-handle responsiveness; the Next/Prev bar swapping the rendered song cleanly; the
position label staying correct if you navigate back manually.

## Decisions for the morning

1. **Entry point** — Setlists is a **song-list app-bar action** (parity with Books), not a 4th bottom-nav
   tab. If you'd prefer a dedicated tab, it's a small change to `ScaffoldWithNavBar` (both
   `_calculateSelectedIndex` and `_onItemTapped`) + a route move into the shell.
2. **Setlist id scheme** — `sl_${microsecondsSinceEpoch}`, generated locally. Fine for one device; when
   Phase 10 (cloud) lands, decide whether to keep these or remap to server ids on migration.
3. **Playback model** — kept entirely in a provider (not URL/query state), and Next/Prev use
   `pushReplacement`. This reuses `/song/:id` unchanged but means the OS back button during playback
   returns to wherever you launched from, not the previous setlist song. Confirm that's the desired
   back behavior, or we can make the nav bar own a back stack.
4. **Add-songs UX** — currently a flat checkbox list of *all* songs. Once the library grows (1000+),
   this needs search/filter inside the sheet (ties into Phase 9 Tags & Search).
5. **Reorder of large setlists** — `ReorderableListView` is fine for service-sized lists; no
   virtualization concerns at current scale.
6. **Next phase** — Phase 9 (Tags & Search) depends only on Phase 5 and would also improve the
   add-songs picker. Alternatively, close out v1.0 store submission (on-device + store work from
   Phase 6) before more v1.1 features. Your call.

## Constraints honored

- No push, no PR, no commits to `master`. Branch `claude/phase-8-setlists` stacked on phase-7.
- Followed CONVENTIONS.md (naming, JSON-serializable models, StateNotifier providers, silent-fallback
  error handling) and copied the 05-phase PLAN/SUMMARY style.
- No app run / no screenshots (no device) — visual UAT explicitly deferred.
