import 'dart:math';

import '../datasources/local/local_datasource.dart';
import '../datasources/remote/remote_sync_datasource.dart';
import '../models/song_id.dart';
import '../models/setlist.dart';

/// Repository for managing setlists (named, ordered song lists).
///
/// All mutators operate on a fresh copy of the persisted list, replace the
/// target entry, and persist the whole list. Operations on an unknown id are
/// no-ops returning `false` (silent-fallback convention — no exceptions).
///
/// The device is the source of truth and every read below is local, so the app
/// stays fully usable signed-out and offline. The account's `user_setlists`
/// rows are the shared copy layered over it, and with no [RemoteSyncDataSource]
/// — no account, no backend, or the cross-device flag off — this class is the
/// one that shipped before sync existed.
///
/// **A setlist merges as a whole record, last write wins.** It is a *named,
/// ordered list*, and there is no correct merge of two of them: a union of the
/// song ids produces an order nobody chose and cannot express a removal;
/// merging field by field yields a list with one device's name and the other's
/// songs, which neither device ever had; a real ordered-list CRDT is a project
/// rather than a change. So if you add a song on the phone and rename the same
/// setlist on the tablet, **one of those two edits is discarded** — the one
/// whose [Setlist.updatedAt] is earlier. Stated plainly because it is a real
/// cost, and recorded with its alternatives in
/// `docs/plans/2026-08-27-cross-device-sync-design.md`.
class SetlistRepository {
  final LocalDataSource _localDataSource;

  /// Null in tests, in any build with no backend, and in every build that has
  /// not set `--dart-define=CROSS_DEVICE_SYNC=true`.
  final RemoteSyncDataSource? _remote;

  SetlistRepository(this._localDataSource, [this._remote]);

  /// Whether this build carries setlists between devices at all.
  bool get syncsAcrossDevices => _remote != null;

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
  /// leaves already-stored setlists addressable exactly as before. The same
  /// randomness is what lets two *devices* create setlists independently and
  /// have both survive the merge instead of one silently replacing the other.
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
    await _push([SyncedSetlist.of(setlist)]);
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
    final deleted = getById(id);
    setlists.removeWhere((s) => s.id == id);
    if (setlists.length == before) return false;

    final saved = await _localDataSource.saveSetlists(setlists);
    if (_remote == null || deleted == null) return saved;

    // A deletion has to be a stored fact. Without the tombstone the other
    // device's copy simply restores the setlist on the next sync, and there is
    // no way to delete anything at all.
    final removedAt = DateTime.now();
    final removals = _localDataSource.getSetlistRemovals();
    removals[id] = removedAt;
    await _localDataSource.saveSetlistRemovals(removals);

    await _push([
      SyncedSetlist.of(deleted.copyWith(updatedAt: removedAt), removed: true),
    ]);
    return saved;
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

    // `updatedAt` was always maintained here; sync did not add it. That is why
    // the merge key for a setlist is a field with a history of being correct
    // rather than a new one that has to be kept in step.
    final updated =
        transform(setlists[index]).copyWith(updatedAt: DateTime.now());
    setlists[index] = updated;

    final saved = await _localDataSource.saveSetlists(setlists);
    await _push([SyncedSetlist.of(updated)]);
    return saved;
  }

  // --- Cross-device sync ---

  /// Merges the account's setlists with this device's, in both directions.
  ///
  /// Full state every time, no watermark — a person has a handful of setlists,
  /// so there is no cursor to get wrong and running this twice does nothing the
  /// second time. Does nothing when sync is off or nobody is signed in, and
  /// gives up silently when the server cannot be reached.
  ///
  /// On a first sign-in with setlists on both sides, **both shelves survive**.
  /// Setlist ids are minted from a timestamp plus randomness, so two devices
  /// cannot collide, and two setlists that merely share a *name* are two
  /// setlists: merging by name would silently combine two different lists,
  /// which is the failure this design exists to avoid.
  Future<void> sync() async {
    final remote = _remote;
    if (remote == null) return;

    final owner = remote.currentUserId;
    if (owner == null) return;

    if (_localDataSource.getSyncOwner() != owner) {
      // A different account on this device. Keep the setlists — they are the
      // user's — and drop the tombstones, so signing in as somebody else can
      // add setlists to their account and can never delete any.
      await _localDataSource.saveSetlistRemovals(const {});
    }

    final List<SyncedSetlist> serverRows;
    try {
      serverRows = await remote.fetchSetlists();
    } catch (_) {
      return;
    }

    final claims = _localClaims();
    final wonByServer = <String>{};

    for (final row in serverRows) {
      final local = claims[row.id];
      // The server wins an exact tie, so two devices converge on the shared
      // copy rather than each keeping its own.
      if (local == null || !row.changedAt.isBefore(local.at)) {
        claims[row.id] = _SetlistClaim(
          id: row.id,
          at: row.changedAt,
          setlist: row.toSetlist(),
        );
        wonByServer.add(row.id);
      }
    }

    final toPush = [
      for (final entry in claims.entries)
        if (!wonByServer.contains(entry.key)) entry.value.toRecord(),
    ];

    await _localDataSource.saveSetlists([
      for (final claim in claims.values)
        if (claim.setlist != null) claim.setlist!,
    ]);

    await _localDataSource.saveSetlistRemovals({
      for (final claim in claims.values)
        if (claim.setlist == null) claim.id: claim.at,
    });

    await _localDataSource.setSyncOwner(owner);

    try {
      await remote.pushSetlists(toPush);
    } catch (_) {
      // The device already has the merged state; the next sync pushes again.
    }
  }

  /// This device's opinion about every setlist it has an opinion about.
  Map<String, _SetlistClaim> _localClaims() {
    final claims = <String, _SetlistClaim>{};

    for (final setlist in getSetlists()) {
      claims[setlist.id] = _SetlistClaim(
        id: setlist.id,
        at: setlist.updatedAt,
        setlist: setlist,
      );
    }

    _localDataSource.getSetlistRemovals().forEach((id, removedAt) {
      final existing = claims[id];
      if (existing != null && existing.at.isAfter(removedAt)) return;
      claims[id] = _SetlistClaim(id: id, at: removedAt, setlist: null);
    });

    return claims;
  }

  /// Best-effort. A failed push leaves a local record newer than the server's,
  /// which is what [sync] looks for, so nothing is lost and nothing needs a
  /// queue of its own.
  Future<void> _push(List<SyncedSetlist> records) async {
    final remote = _remote;
    if (remote == null) return;
    try {
      await remote.pushSetlists(records);
    } catch (_) {
      // Offline is normal here, not an error worth surfacing.
    }
  }
}

/// One side's opinion about one setlist: what it is, or that it is gone, and
/// when that was decided.
class _SetlistClaim {
  final String id;
  final DateTime at;

  /// Null means a tombstone.
  final Setlist? setlist;

  const _SetlistClaim({
    required this.id,
    required this.at,
    this.setlist,
  });

  SyncedSetlist toRecord() {
    final present = setlist;
    if (present != null) return SyncedSetlist.of(present);
    // A tombstone the device has held for a while remembers only that the
    // setlist is gone. Name and songs are not needed to say so, and are never
    // shown.
    return SyncedSetlist(
      id: id,
      name: '',
      songIds: const [],
      createdAt: at,
      changedAt: at,
      removed: true,
    );
  }
}
