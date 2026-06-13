import '../datasources/local/local_datasource.dart';
import '../models/recent_song.dart';

/// Repository for the recently-viewed songs list.
class RecentsRepository {
  final LocalDataSource _localDataSource;

  RecentsRepository(this._localDataSource);

  /// Recently-viewed songs, most-recent first.
  List<RecentSong> getRecentSongs() => _localDataSource.getRecentSongs();

  /// Recently-viewed song numbers, most-recent first.
  List<int> getRecentSongNumbers() =>
      getRecentSongs().map((r) => r.songNumber).toList();

  /// The most recently viewed song number, or null if none.
  int? get lastViewed {
    final recents = getRecentSongs();
    return recents.isEmpty ? null : recents.first.songNumber;
  }

  /// Records [songNumber] as the most recently viewed.
  Future<bool> record(int songNumber, {DateTime? now}) =>
      _localDataSource.recordRecentSong(songNumber, now: now);

  /// Clears the recently-viewed list.
  Future<bool> clear() => _localDataSource.clearRecentSongs();
}
