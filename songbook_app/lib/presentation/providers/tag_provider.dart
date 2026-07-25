import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tag.dart';
import 'providers.dart';
import 'song_provider.dart';

/// Notifier for user-editable per-song tag overrides.
///
/// Seeded from [TagRepository] so edits survive restarts. Every mutation
/// persists then replaces the state map, which [songsProvider] watches — so an
/// edit anywhere propagates to the song list, search, and the tag browser.
class TagOverridesNotifier extends StateNotifier<Map<int, List<String>>> {
  final Ref _ref;

  TagOverridesNotifier(this._ref)
      : super(_ref.read(tagRepositoryProvider).getOverrides());

  /// Replaces the tags for [songNumber]. An empty list clears the override.
  Future<void> setTags(int songNumber, List<String> tags) async {
    if (tags.isEmpty) {
      await clearOverride(songNumber);
      return;
    }
    final repository = _ref.read(tagRepositoryProvider);
    await repository.setTags(songNumber, tags);
    state = {...state, songNumber: List<String>.from(tags)};
  }

  /// Adds [tag] to [currentTags] for [songNumber] (trimmed; blank and
  /// case-insensitive duplicates are ignored).
  Future<void> addTag(
    int songNumber,
    String tag,
    List<String> currentTags,
  ) async {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return;
    final exists =
        currentTags.any((t) => t.toLowerCase() == trimmed.toLowerCase());
    if (exists) return;
    await setTags(songNumber, [...currentTags, trimmed]);
  }

  /// Removes [tag] (case-insensitive) from [currentTags] for [songNumber].
  Future<void> removeTag(
    int songNumber,
    String tag,
    List<String> currentTags,
  ) async {
    final next = currentTags
        .where((t) => t.toLowerCase() != tag.toLowerCase())
        .toList();
    await setTags(songNumber, next);
  }

  /// Clears the override for [songNumber], reverting to bundled tags.
  Future<void> clearOverride(int songNumber) async {
    final repository = _ref.read(tagRepositoryProvider);
    await repository.clearOverride(songNumber);
    final next = {...state}..remove(songNumber);
    state = next;
  }
}

/// Provider for per-song tag overrides (keyed by song number).
final tagOverridesProvider =
    StateNotifierProvider<TagOverridesNotifier, Map<int, List<String>>>((ref) {
  return TagOverridesNotifier(ref);
});

/// Provider for the list of tags derived from the effective songs (with counts).
///
/// Reads [songsProvider] (already override-merged), so counts reflect edits.
final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  final songs = await ref.watch(songsProvider.future);
  return ref.watch(searchServiceProvider).tagsWithCounts(songs);
});
