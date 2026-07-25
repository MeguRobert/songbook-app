import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// State for hands-free auto-scrolling of the song view.
///
/// [speed] is the scroll rate in logical pixels per second. [isPlaying] drives
/// the ticker in the song view; the actual scrolling is performed there because
/// it needs a `ScrollController` + `Ticker` from the widget tree.
class AutoScrollState {
  /// Minimum and maximum user-selectable speeds (logical px/s).
  static const minSpeed = 12.0;
  static const maxSpeed = 120.0;

  final bool isPlaying;
  final double speed;

  const AutoScrollState({
    this.isPlaying = false,
    this.speed = 40.0,
  });

  AutoScrollState copyWith({bool? isPlaying, double? speed}) {
    return AutoScrollState(
      isPlaying: isPlaying ?? this.isPlaying,
      speed: speed ?? this.speed,
    );
  }
}

/// Notifier for the auto-scroll state of the currently viewed song.
///
/// Mirrors [SongViewNotifier]'s lifecycle: [init] is called when a song opens
/// so the persisted per-song speed is restored, and the cursor starts paused.
class AutoScrollNotifier extends StateNotifier<AutoScrollState> {
  final Ref _ref;
  int? _songNumber;

  AutoScrollNotifier(this._ref) : super(const AutoScrollState());

  /// Loads the persisted speed for [songNumber] and resets to a paused state.
  void init(int songNumber) {
    _songNumber = songNumber;
    final repo = _ref.read(settingsRepositoryProvider);
    final saved = repo.getAutoScrollSpeed(songNumber).toDouble();
    state = AutoScrollState(isPlaying: false, speed: saved);
  }

  void play() => state = state.copyWith(isPlaying: true);

  void pause() => state = state.copyWith(isPlaying: false);

  void toggle() => state = state.copyWith(isPlaying: !state.isPlaying);

  /// Sets the scroll speed (clamped to the allowed range) and persists it for
  /// the current song so the choice is remembered next time.
  void setSpeed(double pixelsPerSecond) {
    final clamped = pixelsPerSecond.clamp(
      AutoScrollState.minSpeed,
      AutoScrollState.maxSpeed,
    );
    state = state.copyWith(speed: clamped);
    final song = _songNumber;
    if (song != null) {
      _ref
          .read(settingsRepositoryProvider)
          .setAutoScrollSpeed(song, clamped.round());
    }
  }
}

/// Provider for the auto-scroll state of the current song view.
final autoScrollProvider =
    StateNotifierProvider<AutoScrollNotifier, AutoScrollState>((ref) {
  return AutoScrollNotifier(ref);
});
