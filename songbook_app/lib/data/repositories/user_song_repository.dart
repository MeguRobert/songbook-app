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
  ///
  /// The guard is a real one rather than an `assert`, because an assert is
  /// compiled out of a release build and this is exactly the case where the
  /// fallthrough is silent and permanent. [LocalDataSource.upsertUserSong] keys
  /// on [Song.id], and a song with no [Song.explicitId] answers that with
  /// `SongId.hymnal(number)` — which matches no stored user song, so the "update"
  /// appends a second copy, filed under an id that collides with the bundled
  /// hymn of the same number.
  ///
  /// It throws rather than minting an id, because minting one would do the same
  /// damage under a nicer name: [update] means *replace the song already
  /// stored*, and a song with no id has never been stored, so there is nothing
  /// to replace. Adding one is [add]'s job, and it is the caller — who knows
  /// whether this is a correction or a new song — that has to say which.
  Future<bool> update(Song song) {
    if (song.explicitId == null) {
      throw ArgumentError.value(
        song.title,
        'song',
        'cannot update a song with no stored id',
      );
    }
    return _localDataSource.upsertUserSong(song);
  }

  /// Deletes the user song with [songId], and everything that pointed at it.
  ///
  /// Returns false if there was no such song — but the cleanup runs either way,
  /// because a reference can outlive its song (an interrupted delete) and every
  /// step of it is idempotent.
  ///
  /// The cleanup is not optional. A user song's id is never reissued, so a
  /// favourite, setlist entry, tag override or per-song setting left behind
  /// points at something that can never resolve again — and since each of those
  /// silently skips ids it cannot find, the leftovers are invisible rather than
  /// harmless. [add] writes a per-song view config itself, which makes this the
  /// symmetric half of it.
  Future<bool> delete(SongId songId) async {
    final removed = await _localDataSource.deleteUserSong(songId);
    await _localDataSource.purgeSongReferences(songId);
    await _settings.clearSongSettings(songId);
    return removed;
  }

  /// Whether any user songs exist.
  bool get isEmpty => getAll().isEmpty;
}
