import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/setlist.dart';
import '../../models/song_id.dart';
import 'supabase_config.dart';

/// One favourite as the account holds it: a membership decision and when it was
/// made.
///
/// [removed] true is a tombstone. It is a record like any other, because an
/// absent row cannot be told apart from a row this device has not heard of yet
/// — see `LocalDataSource._getRemovals` for the same argument on the other side
/// of the wire.
class SyncedFavorite {
  final SongId songId;

  /// Event time: when the person tapped the heart, not when the row was
  /// written. This is the only field the merge compares.
  final DateTime changedAt;

  final int sortOrder;
  final bool removed;

  const SyncedFavorite({
    required this.songId,
    required this.changedAt,
    this.sortOrder = 0,
    this.removed = false,
  });

  @override
  String toString() =>
      'SyncedFavorite($songId, ${removed ? 'removed' : 'present'} at $changedAt)';
}

/// One setlist as the account holds it — the whole setlist, in one record.
///
/// That is what makes the merge last-write-wins over the *record*: the name and
/// the order travel together, so no sync can produce a list with one device's
/// name and the other's songs, which is a list neither device ever had.
class SyncedSetlist {
  final String id;
  final String name;
  final List<SongId> songIds;
  final DateTime createdAt;

  /// The setlist's own `updatedAt`, which every mutator already maintains.
  final DateTime changedAt;

  final bool removed;

  const SyncedSetlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    required this.changedAt,
    this.removed = false,
  });

  /// The setlist this record describes, or null when it is a tombstone.
  Setlist? toSetlist() => removed
      ? null
      : Setlist(
          id: id,
          name: name,
          songIds: songIds,
          createdAt: createdAt,
          updatedAt: changedAt,
        );

  factory SyncedSetlist.of(Setlist setlist, {bool removed = false}) {
    return SyncedSetlist(
      id: setlist.id,
      name: setlist.name,
      songIds: removed ? const [] : setlist.songIds,
      createdAt: setlist.createdAt,
      changedAt: setlist.updatedAt,
      removed: removed,
    );
  }

  @override
  String toString() =>
      'SyncedSetlist($id, ${removed ? 'removed' : '${songIds.length} songs'} at $changedAt)';
}

/// The account's copy of the two collections that are supposed to follow it.
///
/// **This is a shared copy, not the source of truth.** The device is the source
/// of truth — Songbook works signed-out and offline as a hard requirement, so
/// `SharedPreferences` answers every read and this class exists only to let a
/// second device catch up. It is the same relationship `RemoteSongDataSource`
/// has with the bundled hymnal, and callers treat a throw the same way: as
/// "carry on with what is on the device", not as an error worth surfacing.
///
/// Nothing here filters by `user_id`. Row-level security already restricts every
/// statement to the caller's own rows (`supabase/migrations/
/// 20260827120000_user_favorites_and_setlists.sql`), and adding a client-side
/// filter would imply the server was not already doing it — the precise habit
/// that made the old Songbook app leak.
class RemoteSyncDataSource {
  final SupabaseClient _client;

  RemoteSyncDataSource(this._client);

  /// The account these rows belong to, or null when signed out.
  ///
  /// Read on every call rather than captured, because sign-out and sign-in
  /// happen underneath this object and a captured id would push one account's
  /// favourites into another's rows.
  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<SyncedFavorite>> fetchFavorites() async {
    final rows = await _client
        .from('user_favorites')
        .select('song_id, changed_at, sort_order, removed')
        .timeout(SupabaseConfig.fetchTimeout);

    final favorites = <SyncedFavorite>[];
    for (final row in rows) {
      final favorite = _tryParseFavorite(row);
      if (favorite != null) favorites.add(favorite);
    }
    return favorites;
  }

  Future<void> pushFavorites(List<SyncedFavorite> favorites) async {
    final userId = currentUserId;
    if (userId == null || favorites.isEmpty) return;

    await _client.from('user_favorites').upsert(
      [
        for (final favorite in favorites)
          {
            'user_id': userId,
            'song_id': favorite.songId.value,
            'changed_at': favorite.changedAt.toUtc().toIso8601String(),
            'sort_order': favorite.sortOrder,
            'removed': favorite.removed,
          },
      ],
      onConflict: 'user_id,song_id',
    ).timeout(SupabaseConfig.fetchTimeout);
  }

  Future<List<SyncedSetlist>> fetchSetlists() async {
    final rows = await _client
        .from('user_setlists')
        .select('id, name, song_ids, created_at, changed_at, removed')
        .timeout(SupabaseConfig.fetchTimeout);

    final setlists = <SyncedSetlist>[];
    for (final row in rows) {
      final setlist = _tryParseSetlist(row);
      if (setlist != null) setlists.add(setlist);
    }
    return setlists;
  }

  Future<void> pushSetlists(List<SyncedSetlist> setlists) async {
    final userId = currentUserId;
    if (userId == null || setlists.isEmpty) return;

    await _client.from('user_setlists').upsert(
      [
        for (final setlist in setlists)
          {
            'user_id': userId,
            'id': setlist.id,
            'name': setlist.name,
            'song_ids': [for (final id in setlist.songIds) id.value],
            'created_at': setlist.createdAt.toUtc().toIso8601String(),
            'changed_at': setlist.changedAt.toUtc().toIso8601String(),
            'removed': setlist.removed,
          },
      ],
      onConflict: 'user_id,id',
    ).timeout(SupabaseConfig.fetchTimeout);
  }

  /// Deliberately forgiving, exactly as `RemoteSongDataSource._tryParse` is: one
  /// row nobody can read must cost one favourite, not the whole collection —
  /// and here the cost of the alternative is higher, because a merge that saw
  /// an empty server would push the device's entire state over it.
  SyncedFavorite? _tryParseFavorite(Map<String, dynamic> row) {
    final songId = SongId.tryParse('${row['song_id']}');
    final changedAt = DateTime.tryParse('${row['changed_at']}');
    if (songId == null || changedAt == null) return null;

    return SyncedFavorite(
      songId: songId,
      changedAt: changedAt.toLocal(),
      sortOrder: row['sort_order'] is int ? row['sort_order'] as int : 0,
      removed: row['removed'] == true,
    );
  }

  SyncedSetlist? _tryParseSetlist(Map<String, dynamic> row) {
    final id = row['id'];
    final changedAt = DateTime.tryParse('${row['changed_at']}');
    if (id is! String || id.isEmpty || changedAt == null) return null;

    final songIds = <SongId>[];
    final rawIds = row['song_ids'];
    if (rawIds is List) {
      for (final raw in rawIds) {
        final songId = SongId.tryParse('$raw');
        // An id this build cannot parse is dropped rather than taking the
        // setlist with it. The order of what remains is preserved, which is
        // what a setlist actually is.
        if (songId != null) songIds.add(songId);
      }
    }

    return SyncedSetlist(
      id: id,
      name: row['name'] is String ? row['name'] as String : '',
      songIds: songIds,
      createdAt:
          DateTime.tryParse('${row['created_at']}')?.toLocal() ?? changedAt.toLocal(),
      changedAt: changedAt.toLocal(),
      removed: row['removed'] == true,
    );
  }
}
