import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import 'providers.dart';

/// Provider for all songs
final songsProvider = FutureProvider<List<Song>>((ref) async {
  final repository = ref.watch(songRepositoryProvider);
  return repository.getAllSongs();
});

/// Provider for a single song by number
final songByNumberProvider = FutureProvider.family<Song?, int>((ref, number) async {
  final repository = ref.watch(songRepositoryProvider);
  return repository.getSongByNumber(number);
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

  const SongViewState({
    required this.songNumber,
    this.transposeAmount = 0,
  });

  SongViewState copyWith({
    int? songNumber,
    int? transposeAmount,
  }) {
    return SongViewState(
      songNumber: songNumber ?? this.songNumber,
      transposeAmount: transposeAmount ?? this.transposeAmount,
    );
  }
}

/// Notifier for the current song view state
class SongViewNotifier extends StateNotifier<SongViewState?> {
  SongViewNotifier() : super(null);

  void openSong(int songNumber) {
    state = SongViewState(songNumber: songNumber);
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
      // Wrap from +12 to -11 (circular two-octave range)
      if (newAmount > 12) newAmount = -11;
      state = state!.copyWith(transposeAmount: newAmount);
    }
  }

  void transposeDown() {
    if (state != null) {
      int newAmount = state!.transposeAmount - 1;
      // Wrap from -11 to +12 (circular two-octave range)
      if (newAmount < -11) newAmount = 12;
      state = state!.copyWith(transposeAmount: newAmount);
    }
  }

  void resetTranspose() {
    if (state != null) {
      state = state!.copyWith(transposeAmount: 0);
    }
  }
}

/// Provider for the current song view state
final songViewProvider =
    StateNotifierProvider<SongViewNotifier, SongViewState?>((ref) {
  return SongViewNotifier();
});

/// Provider for the transpose amount of the current song
final transposeProvider = Provider<int>((ref) {
  final viewState = ref.watch(songViewProvider);
  return viewState?.transposeAmount ?? 0;
});
