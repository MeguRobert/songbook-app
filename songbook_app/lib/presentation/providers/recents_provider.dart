import '../../data/models/song_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/song.dart';
import 'providers.dart';
import 'song_provider.dart';

/// Notifier for the recently-viewed songs list (most-recent first).
///
/// Holds song numbers; the resolved [recentSongsProvider] joins them against
/// the loaded song list. Mirrors [FavoritesNotifier]'s load-on-create pattern.
class RecentsNotifier extends StateNotifier<List<SongId>> {
  final Ref _ref;

  RecentsNotifier(this._ref) : super(const []) {
    _load();
  }

  void _load() {
    state = _ref.read(recentsRepositoryProvider).getRecentSongIds();
  }

  /// Records [songId] as most-recently viewed and refreshes state.
  Future<void> record(SongId songId, {DateTime? now}) async {
    await _ref.read(recentsRepositoryProvider).record(songId, now: now);
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
    StateNotifierProvider<RecentsNotifier, List<SongId>>((ref) {
  return RecentsNotifier(ref);
});

/// The most recently viewed song, or null when history is empty.
final lastViewedSongProvider = Provider<SongId?>((ref) {
  final recents = ref.watch(recentsProvider);
  return recents.isEmpty ? null : recents.first;
});

/// Recently-viewed songs resolved to [Song] objects, preserving recents order
/// and skipping any numbers no longer present in the catalog.
final recentSongsProvider = FutureProvider<List<Song>>((ref) async {
  final ids = ref.watch(recentsProvider);
  if (ids.isEmpty) return const [];
  final songs = await ref.watch(songsProvider.future);
  final byId = {for (final s in songs) s.id: s};
  return ids
      .where(byId.containsKey)
      .map((id) => byId[id]!)
      .toList();
});
