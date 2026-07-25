# Phase 8 Verification: Setlists & Playlists

**Phase goal:** Allow users to create ordered song lists for specific services or events.
**Verified:** 2026-06-13 (codeable slice; visual UAT pending Robert — no device/browser overnight).
**Branch:** `claude/phase-8-setlists` (local only, never pushed).

## Success Criteria → Evidence

### Criterion 1 — User can create a named setlist and add songs to it ✅ (code + tests)

- **Data:** `SetlistRepository.createSetlist(name)` creates a named, empty setlist with a stable id;
  `addSong(id, n)` appends idempotently. `songbook_app/lib/data/repositories/setlist_repository.dart`.
- **UI:** `SetlistsScreen` FAB → name dialog → `setlistsProvider.notifier.create(name)`.
  `SetlistDetailScreen` "Add songs" bottom sheet toggles `addSong`/`removeSong`.
- **Tests:**
  - `test/data/repositories/setlist_repository_test.dart` — create / addSong (append + idempotent).
  - `test/presentation/providers/setlist_provider_test.dart` — `create adds a setlist to state`,
    `addSong / removeSong / reorder reflect in state`.
  - `test/presentation/screens/setlists_screen_test.dart` — `creating a setlist adds it to the list`
    (FAB → enter name → Save → appears with "0 songs").

### Criterion 2 — Songs in a setlist can be reordered ✅ (code + tests)

- **Data:** `SetlistRepository.reorderSongs(id, ordered)` replaces the order with the exact requested
  list (updatedAt bumped).
- **UI:** `SetlistDetailScreen` uses `ReorderableListView.builder`; `onReorder` computes the new order
  and calls `setlistsProvider.notifier.reorder(...)`, which persists.
- **Tests:** repository `reorderSongs applies the exact requested order`; provider
  `addSong / removeSong / reorder reflect in state` asserts the post-reorder order `[151, 42]`.
- **Pending (visual):** drag-handle interaction confirmed on device.

### Criterion 3 — Setlist provides "next song" navigation during a service ✅ (code + tests)

- **Logic:** `SetlistPlaybackNotifier` (`setlist_provider.dart`) — `start/next/previous/jumpTo/stop`
  with `hasNext/hasPrevious/position/total/currentSongNumber`. No wrap at the ends.
- **UI:** `SetlistDetailScreen` Play action → `setlistPlaybackProvider.notifier.start(setlist)` then
  opens the first song. `SetlistNavBar` (song view `bottomNavigationBar`) shows Previous / "name ·
  pos/total" / Next / Close; Next/Previous step the cursor and `pushReplacement` to the adjacent song.
  The song view's `initState` calls `jumpTo()` to keep the cursor aligned with the song shown.
- **Tests:** `test/presentation/providers/setlist_playback_test.dart` — start at first song, next walks
  forward and returns null at the end (no wrap), previous walks back and returns null at the start,
  jumpTo clamps, empty setlist ignored, stop clears.
- **Pending (visual):** on-device confirmation that Next/Previous swaps the rendered song and the
  position label updates.

### Criterion 4 — Setlists persist across app restarts ✅ (code + tests)

- **Storage:** `LocalDataSource.getSetlists()/saveSetlists()` persist the whole list as one
  JSON-encoded string under the `setlists` SharedPreferences key (mirrors favorites).
- **Tests (simulated restart):**
  - repository `persistence across instances` — a fresh `LocalDataSource`/`SetlistRepository` over
    the same prefs reads the setlist (and its song order) back.
  - provider `persistence end-to-end` — a fresh `ProviderContainer` over the same prefs reads setlists
    back with the correct song order.

## Quality Gates

- **`flutter analyze`:** 8 issues, all pre-existing `info` RadioListTile deprecations in
  settings_screen.dart. **No new issues** introduced by Phase 8.
- **`flutter test`:** **53/53 pass** (23 baseline + 30 new across model/repository/provider/playback/
  widget).

## What's NOT covered (deferred)

- **Visual UAT** — no device/emulator/browser available in the overnight run. Drag-to-reorder, the
  add-songs sheet, and the in-service Next/Previous flow have automated coverage of their logic but
  have not been seen rendered. 5-minute UAT script in `PHASE8-REPORT-2026-06-13.md`.
- **Cross-device sync** — out of scope (local-first; cloud sync is Phase 10).
- **Setlist export/share** — out of scope (Phase 11).

## Conclusion

All four Phase 8 success criteria are met at the code + automated-test level on branch
`claude/phase-8-setlists`. Visual/on-device UAT is the only remaining item and is recorded as pending.
