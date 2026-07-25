import '../datasources/local/local_datasource.dart';

/// Repository for user-editable per-song tag overrides.
///
/// Bundled tags live on [Song.tags] (read-only assets); this repository stores
/// the user's edits as overrides keyed by song number. A thin wrapper over
/// [LocalDataSource] (mirrors [FavoritesRepository]).
class TagRepository {
  final LocalDataSource _localDataSource;

  TagRepository(this._localDataSource);

  /// All per-song tag overrides keyed by song number.
  Map<int, List<String>> getOverrides() {
    return _localDataSource.getTagOverrides();
  }

  /// Replaces the tags for [songNumber] with [tags].
  Future<bool> setTags(int songNumber, List<String> tags) {
    return _localDataSource.setSongTags(songNumber, tags);
  }

  /// Clears the override for [songNumber] (reverting to bundled tags).
  Future<bool> clearOverride(int songNumber) {
    return _localDataSource.clearSongTags(songNumber);
  }

  /// Whether [songNumber] has a user override.
  bool hasOverride(int songNumber) {
    return getOverrides().containsKey(songNumber);
  }
}
