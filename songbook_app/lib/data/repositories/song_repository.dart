import '../datasources/local/local_datasource.dart';
import '../datasources/remote/remote_song_datasource.dart';
import '../models/song.dart';

/// Repository for song data access.
///
/// The catalogue has two sources and the bundled one is the floor:
///
/// * `assets/data/songs.json` — always present, needs no network, no account and
///   no server. This is why the app works signed-out and offline, which is a
///   hard requirement rather than a nicety.
/// * Supabase — the shared catalogue: the canonical hymnal plus songs other
///   people have contributed and an admin has approved.
///
/// The server is layered *over* the bundle, never in place of it. If the network
/// is gone, or the free-tier project has paused after a week idle (it answers
/// HTTP 540), or the fetch simply takes too long, the bundle answers and the app
/// behaves exactly as it did before any of this existed. A user with no
/// connection should not be able to tell that a backend was added.
class SongRepository {
  final LocalDataSource _localDataSource;

  /// Null in tests and in any build with no backend configured, which keeps this
  /// class usable without a Supabase client.
  final RemoteSongDataSource? _remoteDataSource;

  /// Merged catalogue, cached so a single app session makes one network attempt
  /// rather than one per screen.
  List<Song>? _merged;

  SongRepository(this._localDataSource, [this._remoteDataSource]);

  /// Gets all songs: the bundled hymnal, with the server's catalogue merged over it.
  Future<List<Song>> getAllSongs() async {
    if (_merged != null) return _merged!;

    final bundled = await _localDataSource.loadSongs();

    if (_remoteDataSource == null) {
      _merged = bundled;
      return _merged!;
    }

    List<Song> remote;
    try {
      remote = await _remoteDataSource.fetchSongs();
    } catch (_) {
      // Offline, paused project, timeout, DNS failure — all the same answer:
      // serve the bundle. Deliberately not cached as the merged result, so the
      // next refresh() gets another chance at the server.
      return bundled;
    }

    _merged = _mergeById(bundled, remote);
    return _merged!;
  }

  /// Later entries win. Keyed on [Song.id], so a server copy of hymnal song 90
  /// replaces the bundled one rather than appearing twice — the ids are equal
  /// because both derive from `hymnal:<number>`.
  List<Song> _mergeById(List<Song> bundled, List<Song> remote) {
    final byId = <String, Song>{};
    for (final song in bundled) {
      byId[song.id.value] = song;
    }
    for (final song in remote) {
      byId[song.id.value] = song;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    return merged;
  }

  /// Gets a song by its hymnal number.
  Future<Song?> getSongByNumber(int number) async {
    final songs = await getAllSongs();
    for (final song in songs) {
      if (song.number == number) return song;
    }
    return null;
  }

  /// Gets songs by a list of numbers (for favorites, etc.)
  Future<List<Song>> getSongsByNumbers(List<int> numbers) async {
    final songs = await getAllSongs();
    final numberSet = numbers.toSet();
    return songs.where((s) => numberSet.contains(s.number)).toList();
  }

  /// Gets the total number of songs
  Future<int> getSongCount() async {
    final songs = await getAllSongs();
    return songs.length;
  }

  /// Refreshes the song cache, dropping both the bundled and merged copies so
  /// the next read re-reads the asset and re-attempts the server.
  void refresh() {
    _merged = null;
    _localDataSource.clearSongCache();
  }
}
