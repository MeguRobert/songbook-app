---
phase: 08-setlists
plan: 02
subsystem: presentation
status: complete
tags: [flutter, dart, riverpod, gorouter, ui, reorderable, playback]
dependencies:
  requires:
    - 08-01 (Setlist model + SetlistRepository)
  provides:
    - setlistRepositoryProvider
    - setlistsProvider (collection notifier) + setlistByIdProvider
    - setlistPlaybackProvider (in-service navigation cursor)
    - SetlistsScreen + SetlistDetailScreen + /setlists routes
    - SetlistNavBar wired into the song view
  affects: []
tech-stack:
  added: []
  patterns:
    - StateNotifier<List<T>> collection notifier reloading from repository after each mutate (mirrors FavoritesNotifier)
    - Pure StateNotifier playback cursor (testable navigation math, no UI)
    - Self-hiding bottomNavigationBar widget (SizedBox.shrink when inactive) for conditional chrome
    - pushReplacement for song-to-song stepping + jumpTo() to resync cursor on each open
key-files:
  created:
    - songbook_app/lib/presentation/providers/setlist_provider.dart
    - songbook_app/lib/presentation/screens/setlists/setlists_screen.dart
    - songbook_app/lib/presentation/screens/setlists/setlist_detail_screen.dart
    - songbook_app/lib/presentation/screens/song_view/widgets/setlist_nav_bar.dart
    - songbook_app/test/presentation/providers/setlist_provider_test.dart
    - songbook_app/test/presentation/providers/setlist_playback_test.dart
    - songbook_app/test/presentation/screens/setlists_screen_test.dart
  modified:
    - songbook_app/lib/presentation/providers/providers.dart
    - songbook_app/lib/presentation/screens/song_view/song_view_screen.dart
    - songbook_app/lib/router/app_router.dart
    - songbook_app/lib/presentation/screens/song_list/song_list_screen.dart
key-decisions:
  - decision: Playback cursor is a separate provider (setlistPlaybackProvider), not URL/query state
    rationale: Pure navigation math is unit-testable; the song view only reads it (loose coupling); no song-route signature change
    date: 2026-06-13
  - decision: Next/Previous use context.pushReplacement(songPath) + initState jumpTo() to resync
    rationale: Reuses the existing /song/:id screen unchanged; keeps the cursor correct even if the user navigates manually
    date: 2026-06-13
  - decision: SetlistNavBar self-hides (SizedBox.shrink) and is always set as bottomNavigationBar
    rationale: No conditional Scaffold logic in the song view; nav bar owns its own visibility guard
    date: 2026-06-13
  - decision: Setlists entry is a song-list app-bar action (Icons.queue_music), not a 4th nav tab
    rationale: Parity with how Books was added in Phase 5; keeps the bottom nav at 3 tabs
    date: 2026-06-13
  - decision: Add-songs uses a CheckboxListTile bottom sheet over the full song list
    rationale: Simple, discoverable, toggles addSong/removeSong directly against the live setlist
    date: 2026-06-13
metrics:
  completed: 2026-06-13
  tasks: 6
  files: 11
---

# Phase 08 Plan 02: Setlist UI & In-Service Playback — Summary

**One-liner:** Users can create/manage setlists and run one during a service — the song view shows a
Previous / position / Next bar that steps song-to-song.

## What Was Built

**Providers** (`setlist_provider.dart`, + `setlistRepositoryProvider` in providers.dart):
- `SetlistsNotifier extends StateNotifier<List<Setlist>>` — `create/rename/delete/addSong/removeSong/
  reorder`, each delegating to the repository then reloading from it (mirrors FavoritesNotifier).
- `setlistByIdProvider` — family lookup into the collection.
- `SetlistPlaybackState` + `SetlistPlaybackNotifier` — an in-service cursor (null = not playing) with
  pure `start/next/previous/jumpTo/stop` and `hasNext/hasPrevious/position/total/currentSongNumber`.

**SetlistsScreen** (`/setlists`) — lists setlists (name + song count), FAB to create (name dialog),
per-row popup menu to rename/delete (with a confirm dialog), empty state. Taps push the detail route.

**SetlistDetailScreen** (`/setlists/:id`) — resolves the setlist's song numbers against `songsProvider`
(preserving order, skipping unknowns); `ReorderableListView` with drag handles + per-row remove;
"Add songs" bottom sheet (CheckboxListTile over all songs, live checkmarks); a Play action that starts
playback and opens the first song. Reorder persists via `reorder()`.

**SetlistNavBar** (`song_view/widgets/`) — a `BottomAppBar` shown only during playback (self-hides
otherwise): Previous / "name · pos/total" / Next / Close. Next/Previous step the cursor and
`pushReplacement` to the adjacent song; Close stops playback. Wired as the song view's
`bottomNavigationBar`; the song view's `initState` calls `jumpTo()` to keep the cursor synced with the
song shown.

**Routing & entry** — `/setlists` and `/setlists/:id` GoRoutes (outside the shell, like /books);
a `queue_music` app-bar action on the song list opens Setlists.

## Task Commits

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Collection + playback providers | e19e17e |
| 2,3 | Setlists + detail screens | 4777aa5 |
| 4,5 | Nav bar in song view + routes + entry | 23104e4 |
| 6 | Provider + playback + widget tests | 812d009 |

## Quality Gates

- `flutter analyze`: **8 issues, all pre-existing** `info`-level RadioListTile deprecations in
  settings_screen.dart (baseline unchanged — no new issues).
- `flutter test`: **53/53 pass** (23 baseline + 16 from 08-01 + 14 new: 8 playback, 4 collection
  provider, 2 setlists-screen widget tests).

## Deviations from Plan

- ScaffoldWithNavBar was left untouched: the documented entry-point choice (app-bar action) was used,
  so no 4th nav tab was added.

## Manual UAT (pending — no device/browser overnight)

See `08-VERIFICATION.md` and the PHASE8-REPORT for a 5-minute UAT script. Visual confirmation of drag
reordering and the in-service Next/Previous flow is deferred to Robert.
