import 'dart:math';

import '../datasources/local/local_datasource.dart';
import '../models/song_id.dart';
import '../models/setlist.dart';

/// Repository for managing setlists (named, ordered song lists).
///
/// All mutators operate on a fresh copy of the persisted list, replace the
/// target entry, and persist the whole list. Operations on an unknown id are
/// no-ops returning `false` (silent-fallback convention — no exceptions).
class SetlistRepository {
  final LocalDataSource _localDataSource;

  SetlistRepository(this._localDataSource);

  /// Gets all setlists.
  List<Setlist> getSetlists() {
    return _localDataSource.getSetlists();
  }

  /// Gets a setlist by id, or null if it does not exist.
  Setlist? getById(String id) {
    final setlists = getSetlists();
    try {
      return setlists.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Upper bound for the random half of a setlist id.
  ///
  /// `1 << 30`, not `1 << 32`: dart2js masks integer shifts to 32 bits, so a
  /// larger bound is not the number it looks like there and `nextInt` rejects
  /// it — in the browser only, with every VM test passing. Same constraint, and
  /// same reason, as `SongId.newUserSong`.
  static const _randomBound = 1 << 30;

  static final _random = Random();

  /// Creates a new empty setlist with the given name and returns it.
  ///
  /// The id is a timestamp *plus randomness*. The timestamp alone was not
  /// unique: `DateTime.now()` has roughly millisecond resolution on Windows, so
  /// two setlists created a few microseconds apart shared an id 94 times out of
  /// 100 — and since every mutator resolves by `indexWhere`, the second one was
  /// simply unreachable. Renaming it, adding a song to it or deleting it all
  /// operated on the first, and `deleteSetlist` removed both.
  ///
  /// Ids are opaque strings that nothing parses, so lengthening the format
  /// leaves already-stored setlists addressable exactly as before.
  Future<Setlist> createSetlist(String name) async {
    final now = DateTime.now();
    final suffix =
        _random.nextInt(_randomBound).toRadixString(36).padLeft(6, '0');
    final setlist = Setlist(
      id: 'sl_${now.microsecondsSinceEpoch}_$suffix',
      name: name,
      songIds: const [],
      createdAt: now,
      updatedAt: now,
    );

    final setlists = getSetlists()..add(setlist);
    await _localDataSource.saveSetlists(setlists);
    return setlist;
  }

  /// Renames a setlist. Returns false if the id is not found.
  Future<bool> renameSetlist(String id, String newName) {
    return _update(id, (s) => s.copyWith(name: newName));
  }

  /// Deletes a setlist. Returns false if the id is not found.
  Future<bool> deleteSetlist(String id) async {
    final setlists = getSetlists();
    final before = setlists.length;
    setlists.removeWhere((s) => s.id == id);
    if (setlists.length == before) return false;
    return _localDataSource.saveSetlists(setlists);
  }

  /// Appends a song to a setlist if not already present (idempotent).
  Future<bool> addSong(String id, SongId songId) {
    return _update(id, (s) {
      if (s.songIds.contains(songId)) return s;
      return s.copyWith(songIds: [...s.songIds, songId]);
    });
  }

  /// Removes a song from a setlist (no-op if not present).
  Future<bool> removeSong(String id, SongId songId) {
    return _update(
      id,
      (s) => s.copyWith(
        songIds: s.songIds.where((n) => n != songId).toList(),
      ),
    );
  }

  /// Replaces the song order with the provided ordered list.
  Future<bool> reorderSongs(String id, List<SongId> orderedSongIds) {
    return _update(
      id,
      (s) => s.copyWith(songIds: List<SongId>.from(orderedSongIds)),
    );
  }

  /// Applies [transform] to the setlist with [id], bumps updatedAt, and
  /// persists. Returns false if the id is not found.
  Future<bool> _update(String id, Setlist Function(Setlist) transform) async {
    final setlists = getSetlists();
    final index = setlists.indexWhere((s) => s.id == id);
    if (index == -1) return false;

    setlists[index] =
        transform(setlists[index]).copyWith(updatedAt: DateTime.now());
    return _localDataSource.saveSetlists(setlists);
  }
}
