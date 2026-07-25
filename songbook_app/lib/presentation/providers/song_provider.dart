import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import '../../data/models/view_config.dart';
import 'providers.dart';
import 'settings_provider.dart';
import 'tag_provider.dart';

/// Provider for all songs, with user tag overrides applied.
///
/// Single source of truth: by merging persisted tag overrides here, the song
/// list, search, favorites, and the tag browser all observe edited tags.
/// With no overrides the merge returns the bundled list unchanged.
final songsProvider = FutureProvider<List<Song>>((ref) async {
  final repository = ref.watch(songRepositoryProvider);
  final songs = await repository.getAllSongs();
  final overrides = ref.watch(tagOverridesProvider);
  final searchService = ref.watch(searchServiceProvider);
  return searchService.applyTagOverrides(songs, overrides);
});

/// Provider for a single song by number, with user tag overrides applied.
///
/// Derived from [songsProvider] rather than hitting the repository directly, so
/// this shares the same merged view as the list, search and tag browser AND is
/// invalidated when tags change. Reading the repository here meant the in-song
/// tag editor was seeded with the BUNDLED tags: reopening it after an edit
/// showed stale tags and saving silently discarded the earlier edit.
final songByNumberProvider =
    FutureProvider.family<Song?, int>((ref, number) async {
  final songs = await ref.watch(songsProvider.future);
  for (final song in songs) {
    if (song.number == number) return song;
  }
  return null;
});

/// Provider for the total song count
final songCountProvider = FutureProvider<int>((ref) async {
  final songs = await ref.watch(songsProvider.future);
  return songs.length;
});

/// State class for current song view
class SongViewState {
  final int songNumber;
  final int transposeAmount;
  final double textScale;
  final ViewConfig? activeViewConfig;

  const SongViewState({
    required this.songNumber,
    this.transposeAmount = 0,
    this.textScale = 1.0,
    this.activeViewConfig,
  });

  SongViewState copyWith({
    int? songNumber,
    int? transposeAmount,
    double? textScale,
    ViewConfig? activeViewConfig,
  }) {
    return SongViewState(
      songNumber: songNumber ?? this.songNumber,
      transposeAmount: transposeAmount ?? this.transposeAmount,
      textScale: textScale ?? this.textScale,
      activeViewConfig: activeViewConfig ?? this.activeViewConfig,
    );
  }
}

/// Notifier for the current song view state
class SongViewNotifier extends StateNotifier<SongViewState?> {
  final Ref _ref;

  SongViewNotifier(this._ref) : super(null);

  void openSong(int songNumber) {
    // Check for per-song view config override
    final repository = _ref.read(settingsRepositoryProvider);
    final songViewConfig = repository.getSongViewConfig(songNumber);

    state = SongViewState(
      songNumber: songNumber,
      activeViewConfig: songViewConfig,
    );
  }

  void closeSong() {
    state = null;
  }

  void setTranspose(int semitones) {
    if (state != null) {
      state = state!.copyWith(transposeAmount: semitones);
    }
  }

  void transposeUp() {
    if (state != null) {
      int newAmount = state!.transposeAmount + 1;
      // Wrap from +5 to -6 (symmetric 12-semitone range)
      if (newAmount > 5) newAmount = -6;
      state = state!.copyWith(transposeAmount: newAmount);
    }
  }

  void transposeDown() {
    if (state != null) {
      int newAmount = state!.transposeAmount - 1;
      // Wrap from -6 to +5 (symmetric 12-semitone range)
      if (newAmount < -6) newAmount = 5;
      state = state!.copyWith(transposeAmount: newAmount);
    }
  }

  void resetTranspose() {
    if (state != null) {
      state = state!.copyWith(transposeAmount: 0);
    }
  }

  void increaseTextScale() {
    if (state != null) {
      final newScale = (state!.textScale + 0.1).clamp(0.5, 2.0);
      state = state!.copyWith(textScale: newScale);
    }
  }

  void decreaseTextScale() {
    if (state != null) {
      final newScale = (state!.textScale - 0.1).clamp(0.5, 2.0);
      state = state!.copyWith(textScale: newScale);
    }
  }

  void resetTextScale() {
    if (state != null) {
      state = state!.copyWith(textScale: 1.0);
    }
  }

  void setTextScale(double scale) {
    if (state != null) {
      state = state!.copyWith(textScale: scale.clamp(0.5, 2.0));
    }
  }

  // --- View Config Management ---

  /// Gets the effective view config (per-song override or global default)
  ViewConfig getEffectiveConfig() {
    if (state?.activeViewConfig != null) {
      return state!.activeViewConfig!;
    }
    return _ref.read(viewConfigProvider);
  }

  /// Sets a temporary active view config (does not persist)
  void setActiveViewConfig(ViewConfig config) {
    if (state != null) {
      state = state!.copyWith(activeViewConfig: config);
    }
  }

  /// Sets a preset (creates temporary override)
  void setPreset(ViewConfig preset) {
    if (state != null) {
      setActiveViewConfig(preset);
    }
  }

  /// Saves the current active view config as a per-song override
  Future<void> saveViewConfigForSong() async {
    if (state?.activeViewConfig != null) {
      final repository = _ref.read(settingsRepositoryProvider);
      await repository.setSongViewConfig(
        state!.songNumber,
        state!.activeViewConfig!,
      );
    }
  }

  /// Clears the per-song override and reverts to global default
  Future<void> clearViewConfigForSong() async {
    if (state != null) {
      final repository = _ref.read(settingsRepositoryProvider);
      await repository.clearSongViewConfig(state!.songNumber);
      state = state!.copyWith(activeViewConfig: null);
    }
  }
}

/// Provider for the current song view state
final songViewProvider =
    StateNotifierProvider<SongViewNotifier, SongViewState?>((ref) {
  return SongViewNotifier(ref);
});

/// Provider for the transpose amount of the current song
final transposeProvider = Provider<int>((ref) {
  final viewState = ref.watch(songViewProvider);
  return viewState?.transposeAmount ?? 0;
});

/// Provider for the text scale of the current song view
final textScaleProvider = Provider<double>((ref) {
  final viewState = ref.watch(songViewProvider);
  return viewState?.textScale ?? 1.0;
});

/// Provider for the effective view config (per-song override or global default)
final effectiveViewConfigProvider = Provider<ViewConfig>((ref) {
  final songState = ref.watch(songViewProvider);
  if (songState?.activeViewConfig != null) {
    return songState!.activeViewConfig!;
  }
  return ref.watch(viewConfigProvider);
});
