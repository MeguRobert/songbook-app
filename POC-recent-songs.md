# POC — Recently-viewed + "Continue where you left off"

**Branch:** `claude/poc-recent-songs` (off `claude/phase-8-setlists`)

## What it does

Tracks the songs you open and surfaces them so you can jump straight back — no re-searching the same
~20 songs every service.

- **Recording:** opening any song records it as most-recently-viewed (de-duplicated, capped at 20).
- **Home "Recently viewed" rail:** a horizontal strip of cards at the top of the song list, newest
  first. Tapping a card reopens the song.
- **Continue:** the first (most recent) card is highlighted (primary color, ▶ icon, "Continue · #N")
  — the one-tap "pick up where you left off" affordance.
- **Clear:** a "Clear" button on the rail empties the history.
- **Persists** across app restarts via SharedPreferences.

## How to try it

1. `git switch claude/poc-recent-songs` and run the app (`flutter run` from `songbook_app/`).
2. On first launch the Home list looks normal (no history yet → no rail).
3. Open a few songs (tap into #1, back, #42, back, #7, back).
4. The Home list now shows a **Recently viewed** rail on top: `Continue · #7` highlighted first, then
   `#42`, `#1`. Tap any card to reopen.
5. Reopen #1 → it jumps to the front of the rail (no duplicate).
6. Kill and relaunch the app → the rail is still there (persisted). Tap **Clear** to reset.

## How it's built (fits existing architecture)

- `lib/data/models/recent_song.dart` — tiny `{songNumber, viewedAt}` model with hand-written JSON
  (no codegen, keeps the POC dependency-free).
- `lib/data/datasources/local/local_datasource.dart` — `getRecentSongs` / `recordRecentSong`
  (dedup + move-to-front + cap at `recentsLimit`) / `clearRecentSongs`, stored as a JSON blob under
  `recent_songs`. Mirrors the favorites/setlists storage pattern. `now` is injectable for tests.
- `lib/data/repositories/recents_repository.dart` — thin wrapper (mirrors `FavoritesRepository`),
  exposes `lastViewed`.
- `lib/presentation/providers/recents_provider.dart` — `RecentsNotifier` (StateNotifier<List<int>>,
  load-on-create like `FavoritesNotifier`), `lastViewedSongProvider`, and `recentSongsProvider`
  (resolves numbers → `Song` objects in recents order).
- `song_view_screen.dart` — records the song in `initState`'s post-frame callback.
- `song_list/widgets/recent_songs_rail.dart` — the rail UI; renders nothing when history is empty.

## What's stubbed / not done

- **No relative timestamps shown** ("2h ago"). `viewedAt` is stored and available, just not displayed.
- **Favorites/Setlist parity:** the rail is Home-only. A dedicated "History" screen or a settings
  toggle to disable tracking isn't built.
- **Resolution test:** `recentSongsProvider` (number → `Song`) isn't unit-tested because loading the
  bundled `songs.json` asset isn't wired into the test harness here; the recents *ordering/dedup/cap*
  logic is fully covered. The rail itself is verified visually.
- **No max-age eviction** (only a count cap).

## Tests

- `test/data/repositories/recents_repository_test.dart` (6): empty start, most-recent-first ordering,
  dedup-moves-to-front, cap at limit, clear, cross-instance persistence.
- `test/presentation/providers/recents_provider_test.dart` (2): notifier record/state + lastViewed,
  clear.

`flutter analyze`: clean (only the 8 pre-existing RadioListTile infos). Full suite: 61 passing.

## Effort to finish

~½ day: relative-time labels, optional History screen + "disable tracking" setting, and a widget test
that drives the rail against the loaded catalog.
