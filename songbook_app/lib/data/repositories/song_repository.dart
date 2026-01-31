import '../datasources/local/local_datasource.dart';
import '../models/song.dart';

/// Repository for song data access
class SongRepository {
  final LocalDataSource _localDataSource;

  SongRepository(this._localDataSource);

  /// Gets all songs
  Future<List<Song>> getAllSongs() {
    return _localDataSource.loadSongs();
  }

  /// Gets a song by its number
  Future<Song?> getSongByNumber(int number) {
    return _localDataSource.getSongByNumber(number);
  }

  /// Gets songs by a list of numbers (for favorites, etc.)
  Future<List<Song>> getSongsByNumbers(List<int> numbers) async {
    final songs = await _localDataSource.loadSongs();
    final numberSet = numbers.toSet();
    return songs.where((s) => numberSet.contains(s.number)).toList();
  }

  /// Gets the total number of songs
  Future<int> getSongCount() async {
    final songs = await _localDataSource.loadSongs();
    return songs.length;
  }

  /// Refreshes the song cache
  void refresh() {
    _localDataSource.clearSongCache();
  }
}
