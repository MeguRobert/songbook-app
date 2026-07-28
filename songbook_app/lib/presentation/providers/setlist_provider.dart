import '../../data/models/song_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/setlist.dart';
import 'providers.dart';

// --- Setlist collection ---

/// Notifier holding the full list of setlists.
///
/// Each mutator delegates to [SetlistRepository] (which persists) and then
/// reloads state from the repository so the in-memory list always reflects what
/// is stored.
class SetlistsNotifier extends StateNotifier<List<Setlist>> {
  final Ref _ref;

  SetlistsNotifier(this._ref) : super(const []) {
    _load();
  }

  void _load() {
    state = _ref.read(setlistRepositoryProvider).getSetlists();
  }

  /// Creates a new named setlist and returns it.
  Future<Setlist> create(String name) async {
    final created =
        await _ref.read(setlistRepositoryProvider).createSetlist(name);
    _load();
    return created;
  }

  Future<void> rename(String id, String newName) async {
    await _ref.read(setlistRepositoryProvider).renameSetlist(id, newName);
    _load();
  }

  Future<void> delete(String id) async {
    await _ref.read(setlistRepositoryProvider).deleteSetlist(id);
    _load();
  }

  Future<void> addSong(String id, SongId songId) async {
    await _ref.read(setlistRepositoryProvider).addSong(id, songId);
    _load();
  }

  Future<void> removeSong(String id, SongId songId) async {
    await _ref.read(setlistRepositoryProvider).removeSong(id, songId);
    _load();
  }

  Future<void> reorder(String id, List<SongId> orderedSongIds) async {
    await _ref
        .read(setlistRepositoryProvider)
        .reorderSongs(id, orderedSongIds);
    _load();
  }
}

/// Provider for the list of setlists.
final setlistsProvider =
    StateNotifierProvider<SetlistsNotifier, List<Setlist>>((ref) {
  return SetlistsNotifier(ref);
});

/// Provider for a single setlist by id (null if it does not exist).
final setlistByIdProvider = Provider.family<Setlist?, String>((ref, id) {
  final setlists = ref.watch(setlistsProvider);
  for (final s in setlists) {
    if (s.id == id) return s;
  }
  return null;
});

// --- In-service playback ---

/// Immutable cursor over a setlist being played during a service.
class SetlistPlaybackState {
  final String setlistId;
  final String name;
  final List<SongId> songIds;
  final int currentIndex;

  const SetlistPlaybackState({
    required this.setlistId,
    required this.name,
    required this.songIds,
    required this.currentIndex,
  });

  /// The song at the current position, or null if the list is empty.
  SongId? get currentSongId =>
      (currentIndex >= 0 && currentIndex < songIds.length)
          ? songIds[currentIndex]
          : null;

  bool get hasNext => currentIndex < songIds.length - 1;

  bool get hasPrevious => currentIndex > 0;

  /// Total number of songs in the setlist.
  int get total => songIds.length;

  /// 1-based position for display (e.g., "2 / 5").
  int get position => currentIndex + 1;

  SetlistPlaybackState copyWith({int? currentIndex}) {
    return SetlistPlaybackState(
      setlistId: setlistId,
      name: name,
      songIds: songIds,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

/// Notifier for the in-service playback cursor (null = not playing).
///
/// Navigation math (next/previous/jumpTo) is pure so it can be unit-tested
/// without any UI.
class SetlistPlaybackNotifier extends StateNotifier<SetlistPlaybackState?> {
  SetlistPlaybackNotifier() : super(null);

  /// Starts playback of [setlist] at [index]. Empty setlists are ignored
  /// (state stays null). The index is clamped to a valid range.
  void start(Setlist setlist, {int index = 0}) {
    if (setlist.songIds.isEmpty) return;
    final clamped = index.clamp(0, setlist.songIds.length - 1);
    state = SetlistPlaybackState(
      setlistId: setlist.id,
      name: setlist.name,
      songIds: List<SongId>.from(setlist.songIds),
      currentIndex: clamped,
    );
  }

  /// Advances to the next song; returns its number, or null if at the end.
  SongId? next() {
    final current = state;
    if (current == null || !current.hasNext) return null;
    final updated = current.copyWith(currentIndex: current.currentIndex + 1);
    state = updated;
    return updated.currentSongId;
  }

  /// Steps back to the previous song; returns its number, or null if at start.
  SongId? previous() {
    final current = state;
    if (current == null || !current.hasPrevious) return null;
    final updated = current.copyWith(currentIndex: current.currentIndex - 1);
    state = updated;
    return updated.currentSongId;
  }

  /// Jumps to [index] (clamped). Used to keep the cursor in sync when the song
  /// view opens a specific song. No-op if not playing.
  void jumpTo(int index) {
    final current = state;
    if (current == null || current.songIds.isEmpty) return;
    final clamped = index.clamp(0, current.songIds.length - 1);
    if (clamped != current.currentIndex) {
      state = current.copyWith(currentIndex: clamped);
    }
  }

  /// Stops playback.
  void stop() {
    state = null;
  }
}

/// Provider for the in-service playback cursor (null = not playing).
final setlistPlaybackProvider =
    StateNotifierProvider<SetlistPlaybackNotifier, SetlistPlaybackState?>(
        (ref) {
  return SetlistPlaybackNotifier();
});
