import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import 'providers.dart';
import 'song_provider.dart';

/// Notifier for the recently-viewed songs list (most-recent first).
///
/// Holds song numbers; the resolved [recentSongsProvider] joins them against
/// the loaded song list. Mirrors [FavoritesNotifier]'s load-on-create pattern.
class RecentsNotifier extends StateNotifier<List<int>> {
  final Ref _ref;

  RecentsNotifier(this._ref) : super(const []) {
    _load();
  }

  void _load() {
    state = _ref.read(recentsRepositoryProvider).getRecentSongNumbers();
  }

  /// Records [songNumber] as most-recently viewed and refreshes state.
  Future<void> record(int songNumber, {DateTime? now}) async {
    await _ref.read(recentsRepositoryProvider).record(songNumber, now: now);
    _load();
  }

  /// Clears the entire recents list.
  Future<void> clear() async {
    await _ref.read(recentsRepositoryProvider).clear();
    state = const [];
  }
}

/// Provider for the recently-viewed song numbers (most-recent first).
final recentsProvider =
    StateNotifierProvider<RecentsNotifier, List<int>>((ref) {
  return RecentsNotifier(ref);
});

/// The most recently viewed song number, or null when history is empty.
final lastViewedSongProvider = Provider<int?>((ref) {
  final recents = ref.watch(recentsProvider);
  return recents.isEmpty ? null : recents.first;
});

/// Recently-viewed songs resolved to [Song] objects, preserving recents order
/// and skipping any numbers no longer present in the catalog.
final recentSongsProvider = FutureProvider<List<Song>>((ref) async {
  final numbers = ref.watch(recentsProvider);
  if (numbers.isEmpty) return const [];
  final songs = await ref.watch(songsProvider.future);
  final byNumber = {for (final s in songs) s.number: s};
  return numbers
      .where(byNumber.containsKey)
      .map((n) => byNumber[n]!)
      .toList();
});
