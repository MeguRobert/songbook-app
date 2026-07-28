import '../datasources/local/local_datasource.dart';
import '../models/song_id.dart';
import '../models/recent_song.dart';

/// Repository for the recently-viewed songs list.
class RecentsRepository {
  final LocalDataSource _localDataSource;

  RecentsRepository(this._localDataSource);

  /// Recently-viewed songs, most-recent first.
  List<RecentSong> getRecentSongs() => _localDataSource.getRecentSongs();

  /// Recently-viewed song ids, most-recent first.
  List<SongId> getRecentSongIds() =>
      getRecentSongs().map((r) => r.songId).toList();

  /// The most recently viewed song, or null if none.
  SongId? get lastViewed {
    final recents = getRecentSongs();
    return recents.isEmpty ? null : recents.first.songId;
  }

  /// Records [songId] as the most recently viewed.
  Future<bool> record(SongId songId, {DateTime? now}) =>
      _localDataSource.recordRecentSong(songId, now: now);

  /// Clears the recently-viewed list.
  Future<bool> clear() => _localDataSource.clearRecentSongs();
}
