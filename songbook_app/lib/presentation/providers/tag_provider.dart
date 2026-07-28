import '../../data/models/song_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tag.dart';
import 'providers.dart';
import 'song_provider.dart';

/// Notifier for user-editable per-song tag overrides.
///
/// Seeded from [TagRepository] so edits survive restarts. Every mutation
/// persists then replaces the state map, which [songsProvider] watches — so an
/// edit anywhere propagates to the song list, search, and the tag browser.
class TagOverridesNotifier extends StateNotifier<Map<SongId, List<String>>> {
  final Ref _ref;

  TagOverridesNotifier(this._ref)
      : super(_ref.read(tagRepositoryProvider).getOverrides());

  /// Replaces the tags for [songId].
  ///
  /// An empty list persists an EMPTY override, which is deliberately distinct
  /// from having no override: it means "this song has no tags". Routing empty
  /// to [clearOverride] instead made bundled tags reappear, so a user could
  /// never remove a song's last tag. Reverting to the bundled tags is the
  /// separate, explicit [clearOverride] ("Reset to default" in the editor).
  Future<void> setTags(SongId songId, List<String> tags) async {
    final repository = _ref.read(tagRepositoryProvider);
    await repository.setTags(songId, tags);
    state = {...state, songId: List<String>.from(tags)};
  }

  /// Adds [tag] to [currentTags] for [songId] (trimmed; blank and
  /// case-insensitive duplicates are ignored).
  Future<void> addTag(
    SongId songId,
    String tag,
    List<String> currentTags,
  ) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    final exists =
        currentTags.any((t) => t.toLowerCase() == trimmed.toLowerCase());
    if (exists) return;
    await setTags(songId, [...currentTags, trimmed]);
  }

  /// Removes [tag] (case-insensitive) from [currentTags] for [songId].
  Future<void> removeTag(
    SongId songId,
    String tag,
    List<String> currentTags,
  ) async {
    final next = currentTags
        .where((t) => t.toLowerCase() != tag.toLowerCase())
        .toList();
    await setTags(songId, next);
  }

  /// Clears the override for [songId], reverting to bundled tags.
  Future<void> clearOverride(SongId songId) async {
    final repository = _ref.read(tagRepositoryProvider);
    await repository.clearOverride(songId);
    final next = {...state}..remove(songId);
    state = next;
  }
}

/// Provider for per-song tag overrides (keyed by song number).
final tagOverridesProvider =
    StateNotifierProvider<TagOverridesNotifier, Map<SongId, List<String>>>((ref) {
  return TagOverridesNotifier(ref);
});

/// Provider for the list of tags derived from the effective songs (with counts).
///
/// Reads [songsProvider] (already override-merged), so counts reflect edits.
final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final songs = await ref.watch(songsProvider.future);
  return ref.watch(searchServiceProvider).tagsWithCounts(songs);
});
