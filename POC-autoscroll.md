# POC — Auto-scroll (hands-free performance)

**Branch:** `claude/poc-autoscroll` (off `claude/phase-8-setlists`)

## What it does

Lets a musician scroll through a song hands-free during performance. The chord/lyrics view scrolls
smoothly and continuously at a chosen speed; speed is remembered per song.

- **App-bar play/pause** (▶/⏸ circle icon) starts/stops scrolling without opening any menu — the
  one-tap hands-free toggle. Hidden in sheet-music mode (see Stubbed).
- **Speed slider** in the song controls sheet (the `tune` FAB) under a new **AUTO-SCROLL** section,
  with walk/run icons at the ends. Range 12–120 logical px/s.
- **Per-song memory:** the chosen speed is persisted to SharedPreferences keyed by song number, so
  each song reopens at the speed you last used.
- **Auto-stop at the end:** scrolling pauses itself when the bottom of the song is reached.

## How to try it

1. `git switch claude/poc-autoscroll` and run the app (`flutter run` from `songbook_app/`).
2. Open any song (e.g. #1) in the default chord/lyrics view.
3. Tap the **▶ play-circle** icon in the app bar → the lyrics scroll smoothly. Tap again (now **⏸**)
   to stop.
4. Open the **tune** FAB → **AUTO-SCROLL** section → drag the slider; scrolling speed changes live
   and "Speed remembered per song" is shown. Close the sheet and scroll continues.
5. Go back, reopen the same song → the slider/speed is restored to your last choice. Open a
   different song → it has its own remembered speed (defaults to 40 px/s).

## How it's built (fits existing architecture)

- `lib/presentation/providers/autoscroll_provider.dart` — `AutoScrollState{isPlaying, speed}` +
  `AutoScrollNotifier` (StateNotifier, same pattern as `SongViewNotifier`). `init(songNumber)`
  restores persisted speed on song open; `setSpeed` clamps and persists.
- `lib/data/repositories/settings_repository.dart` — `getAutoScrollSpeed`/`setAutoScrollSpeed`
  (per-song int key `autoscroll_speed_<n>`, default 40), consistent with existing per-song view-config
  persistence.
- `song_view_screen.dart` — now a `SingleTickerProviderStateMixin`; owns a `ScrollController` + a
  `Ticker`. `ref.listen` on `isPlaying` starts/stops the ticker; each frame advances the controller by
  `speed × dt` and auto-pauses at `maxScrollExtent`.
- `chord_view.dart` — accepts an optional external `ScrollController` (null = unchanged behavior).
- `song_controls_sheet.dart` — new AUTO-SCROLL section (play/pause + slider).

## What's stubbed / not done

- **Sheet-music view:** auto-scroll drives only the chord/lyrics `ChordView`. `SheetMusicView` is a
  separate widget with its own layout, so the play control is hidden in sheet-music mode. Wiring the
  same controller into it is the main follow-up.
- **Presentation mode:** the full-screen `/presentation` route is untouched — arguably the most
  valuable place for auto-scroll. Follow-up.
- **Speed units:** slider is raw px/s. A nicer UX would calibrate to "lines/minute" or a 1–10 dial.
- **No tempo sync / smart speed** (e.g. derive from song length or BPM). Manual speed only.
- **Pinch-zoom interaction:** the body's pinch-to-zoom text gesture and auto-scroll coexist (scroll is
  programmatic) but haven't been stress-tested together on a device.

## Tests

`test/presentation/providers/autoscroll_provider_test.dart` (5 tests): default state, play/pause/
toggle, speed clamping, per-song persistence round-trip, and init-resets-to-paused. The frame-by-frame
scroll math in `_onAutoScrollTick` is widget-level and was not unit-tested (POC scope).

`flutter analyze`: clean (only the 8 pre-existing RadioListTile deprecation infos). Full suite: 58 passing.

## Effort to finish

~1–1.5 days: wire the controller into sheet-music + presentation mode, calibrate speed UX, add a
device pass for gesture interplay, and a widget test for the scrolling itself.
