import '../datasources/local/local_datasource.dart';
import '../models/song_id.dart';

/// Repository for user-editable per-song tag overrides.
///
/// Bundled tags live on [Song.tags] (read-only assets); this repository stores
/// the user's edits as overrides keyed by song id. A thin wrapper over
/// [LocalDataSource] (mirrors [FavoritesRepository]).
class TagRepository {
  final LocalDataSource _localDataSource;

  TagRepository(this._localDataSource);

  /// All per-song tag overrides keyed by song id.
  Map<SongId, List<String>> getOverrides() {
    return _localDataSource.getTagOverrides();
  }

  /// Replaces the tags for [songId] with [tags].
  Future<bool> setTags(SongId songId, List<String> tags) {
    return _localDataSource.setSongTags(songId, tags);
  }

  /// Clears the override for [songId] (reverting to bundled tags).
  Future<bool> clearOverride(SongId songId) {
    return _localDataSource.clearSongTags(songId);
  }

  /// Whether [songId] has a user override.
  bool hasOverride(SongId songId) {
    return getOverrides().containsKey(songId);
  }
}
