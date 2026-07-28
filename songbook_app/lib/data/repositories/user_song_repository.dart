import '../datasources/local/local_datasource.dart';
import '../models/song.dart';
import '../models/song_id.dart';
import '../models/view_config.dart';
import 'settings_repository.dart';

/// Songs the user added themselves, stored on the device.
///
/// The bundled catalogue (`assets/data/songs.json`) is a read-only asset, so
/// user songs cannot simply be appended to it. They are persisted separately
/// and merged into the catalogue at read time by `songsProvider`.
///
/// Overwhelmingly these are not compositions — they are songs that already
/// exist somewhere (a chord site, a book that was never digitised) being
/// transcribed. They therefore keep whatever number their source gives them,
/// inside their own songbook, and are identified by a generated [SongId] so a
/// number shared with a hymnal cannot collide.
class UserSongRepository {
  final LocalDataSource _localDataSource;
  final SettingsRepository _settings;

  UserSongRepository(this._localDataSource, this._settings);

  /// All user songs, in the order they were added.
  List<Song> getAll() => _localDataSource.getUserSongs();

  /// The user song with [songId], or null.
  Song? getById(SongId songId) {
    for (final song in getAll()) {
      if (song.id == songId) return song;
    }
    return null;
  }

  /// Adds [song], assigning it a fresh id if it does not already carry one.
  ///
  /// Returns the stored song, which is what callers should use from then on —
  /// the id it was given is how every favourite, setlist and tag will refer
  /// to it.
  Future<Song> add(Song song) async {
    final stored = song.explicitId == null
        ? song.copyWith(explicitId: SongId.newUserSong())
        : song;
    await _localDataSource.upsertUserSong(stored);

    // Give it a per-song view it can actually honour. The global default is
    // sheet music, and an imported song has none — without this every one
    // opened on the "no sheet music available" placeholder and had to be
    // switched by hand, every time. Written as a per-song override rather than
    // patched in at render time so the controls sheet agrees with the screen
    // instead of highlighting a preset that is not in effect.
    if (!stored.hasNotation && !stored.hasSheetMusic) {
      await _settings.setSongViewConfig(stored.id, const ViewConfig.chords());
    }
    return stored;
  }

  /// Replaces an existing user song. The song must already carry an id.
  Future<bool> update(Song song) {
    assert(song.explicitId != null, 'Cannot update a song with no stored id');
    return _localDataSource.upsertUserSong(song);
  }

  /// Deletes the user song with [songId]. False if there was none.
  Future<bool> delete(SongId songId) => _localDataSource.deleteUserSong(songId);

  /// Whether any user songs exist.
  bool get isEmpty => getAll().isEmpty;
}
