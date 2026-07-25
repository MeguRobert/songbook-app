import '../datasources/local/local_datasource.dart';
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

  /// Creates a new empty setlist with the given name and returns it.
  Future<Setlist> createSetlist(String name) async {
    final now = DateTime.now();
    final setlist = Setlist(
      id: 'sl_${now.microsecondsSinceEpoch}',
      name: name,
      songNumbers: const [],
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
  Future<bool> addSong(String id, int songNumber) {
    return _update(id, (s) {
      if (s.songNumbers.contains(songNumber)) return s;
      return s.copyWith(songNumbers: [...s.songNumbers, songNumber]);
    });
  }

  /// Removes a song from a setlist (no-op if not present).
  Future<bool> removeSong(String id, int songNumber) {
    return _update(
      id,
      (s) => s.copyWith(
        songNumbers: s.songNumbers.where((n) => n != songNumber).toList(),
      ),
    );
  }

  /// Replaces the song order with the provided ordered list.
  Future<bool> reorderSongs(String id, List<int> orderedSongNumbers) {
    return _update(
      id,
      (s) => s.copyWith(songNumbers: List<int>.from(orderedSongNumbers)),
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
