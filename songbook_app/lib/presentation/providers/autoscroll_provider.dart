import '../../data/models/song_id.dart';
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
  SongId? _songId;

  AutoScrollNotifier(this._ref) : super(const AutoScrollState());

  /// Loads the persisted speed for [songId] and resets to a paused state.
  void init(SongId songId) {
    _songId = songId;
    final repo = _ref.read(settingsRepositoryProvider);
    final saved = repo.getAutoScrollSpeed(songId).toDouble();
    state = AutoScrollState(isPlaying: false, speed: saved);
  }

  void play() => state = state.copyWith(isPlaying: true);

  void pause() => state = state.copyWith(isPlaying: false);

  void toggle() => state = state.copyWith(isPlaying: !state.isPlaying);

  /// Sets the scroll speed (clamped to the allowed range) WITHOUT persisting.
  ///
  /// Called on every slider frame, so it must stay cheap — use [commitSpeed]
  /// when the drag ends to write the value once.
  void setSpeed(double pixelsPerSecond) {
    state = state.copyWith(
      speed: pixelsPerSecond.clamp(
        AutoScrollState.minSpeed,
        AutoScrollState.maxSpeed,
      ),
    );
  }

  /// Persists the current speed for the current song so the choice is
  /// remembered next time. Call this when the slider drag ends.
  void commitSpeed([double? pixelsPerSecond]) {
    if (pixelsPerSecond != null) setSpeed(pixelsPerSecond);
    final song = _songId;
    if (song != null) {
      _ref
          .read(settingsRepositoryProvider)
          .setAutoScrollSpeed(song, state.speed.round());
    }
  }
}

/// Provider for the auto-scroll state of the current song view.
final autoScrollProvider =
    StateNotifierProvider<AutoScrollNotifier, AutoScrollState>((ref) {
  return AutoScrollNotifier(ref);
});
