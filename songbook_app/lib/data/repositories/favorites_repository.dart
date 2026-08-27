import '../datasources/local/local_datasource.dart';
import '../datasources/remote/remote_sync_datasource.dart';
import '../models/song_id.dart';
import '../models/favorite.dart';
import '../models/song.dart';

/// Repository for managing favorite songs.
///
/// Two sources, and the device is the floor:
///
/// * `SharedPreferences` — always present, needs no network and no account.
///   Every read below goes here and nowhere else, which is what keeps the app
///   fully usable signed-out and offline. That is a hard requirement, not a
///   nicety.
/// * The account's `user_favorites` rows — the shared copy, so a favourite made
///   on the phone is there on the tablet.
///
/// The server is layered *over* the device, never in place of it, exactly as
/// `SongRepository` layers the Supabase catalogue over the bundled hymnal. With
/// no [RemoteSyncDataSource] — no account, no backend, or the cross-device flag
/// off — every method here is the one that shipped before sync existed.
///
/// **A write is complete when the device has it.** The push that follows is
/// best-effort and its failure is swallowed: offline is a normal state for this
/// app. Nothing is lost by that, because the local store is also the outbox —
/// a record the server never received is a record whose timestamp is newer than
/// the server's, and [sync] pushes it the next time it runs.
///
/// See `docs/plans/2026-08-27-cross-device-sync-design.md`.
class FavoritesRepository {
  final LocalDataSource _localDataSource;

  /// Null in tests, in any build with no backend, and in every build that has
  /// not set `--dart-define=CROSS_DEVICE_SYNC=true`.
  final RemoteSyncDataSource? _remote;

  FavoritesRepository(this._localDataSource, [this._remote]);

  /// Whether this build carries favourites between devices at all.
  ///
  /// Synchronous, so a caller can skip the whole sync path without starting an
  /// async operation that would do nothing.
  bool get syncsAcrossDevices => _remote != null;

  /// Gets all favorites in user-defined display order.
  ///
  /// Sorted by [Favorite.sortOrder] so a reorder actually shows up; the stored
  /// blob is in insertion order. Ties (e.g. entries written before reordering
  /// existed, all sortOrder 0) fall back to song id for a stable result.
  List<Favorite> getFavorites() {
    final favorites = _localDataSource.getFavorites();
    favorites.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.songId.compareTo(b.songId);
    });
    return favorites;
  }

  /// Gets favorite song ids
  List<SongId> getFavoriteSongIds() {
    return getFavorites().map((f) => f.songId).toList();
  }

  /// Adds a song to favorites
  Future<bool> addFavorite(SongId songId) async {
    final stored = await _localDataSource.addFavorite(songId);
    if (!_syncs(songId)) return stored;

    // The song is back, so the tombstone has done its job and must go. Leaving
    // it would make the next merge compare a live favourite against a removal
    // of the same song and pick whichever timestamp happened to be later.
    final removals = _localDataSource.getFavoriteRemovals();
    if (removals.remove(songId.value) != null) {
      await _localDataSource.saveFavoriteRemovals(removals);
    }

    await _push([songId]);
    return stored;
  }

  /// Removes a song from favorites
  Future<bool> removeFavorite(SongId songId) async {
    final removed = await _localDataSource.removeFavorite(songId);
    if (!_syncs(songId)) return removed;

    // Record the removal as a fact. Without it the other device's copy simply
    // re-adds the song on the next sync — the un-favourite that will not stick,
    // which is the whole reason a plain union of two sets is not a merge.
    final removals = _localDataSource.getFavoriteRemovals();
    removals[songId.value] = DateTime.now();
    await _localDataSource.saveFavoriteRemovals(removals);

    await _push([songId]);
    return removed;
  }

  /// Toggles the favorite status of a song
  Future<bool> toggleFavorite(SongId songId) async {
    if (isFavorite(songId)) {
      return removeFavorite(songId);
    } else {
      return addFavorite(songId);
    }
  }

  /// Checks if a song is a favorite
  bool isFavorite(SongId songId) {
    return _localDataSource.isFavorite(songId);
  }

  /// Gets the number of favorites
  int get favoriteCount => getFavorites().length;

  /// Reorders favorites
  Future<bool> reorderFavorites(List<SongId> orderedSongIds) async {
    final favorites = getFavorites();
    final updatedFavorites = <Favorite>[];

    for (int i = 0; i < orderedSongIds.length; i++) {
      final songId = orderedSongIds[i];
      final existing = favorites.firstWhere(
        (f) => f.songId == songId,
        orElse: () => Favorite(
          songId: songId,
          addedAt: DateTime.now(),
        ),
      );
      updatedFavorites.add(existing.copyWith(sortOrder: i));
    }

    final saved = await _localDataSource.saveFavorites(updatedFavorites);
    if (_remote == null) return saved;

    // A reorder changes no song's `addedAt`, so it carries no timestamp of its
    // own and cannot win a merge on its own. It propagates because it pushes
    // every row, and the receiving device takes the server's `sort_order` when
    // the timestamps tie. Two devices reordering while both offline: one order
    // wins, and it is the one that reached the server second. A favourites list
    // in an unexpected order is a disappointment; a favourite that will not stay
    // deleted is a defect, which is why only one of the two got real machinery.
    await _push(orderedSongIds);
    return saved;
  }

  /// Gets favorite songs sorted by order
  Future<List<Song>> getFavoriteSongs(
    Future<List<Song>> Function(List<SongId>) songLoader,
  ) async {
    final favorites = getFavorites();
    if (favorites.isEmpty) return [];

    // Sort by sortOrder
    favorites.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final songIds = favorites.map((f) => f.songId).toList();

    final songs = await songLoader(songIds);

    // Maintain the favorite order
    final songMap = {for (var s in songs) s.id: s};
    return songIds
        .where(songMap.containsKey)
        .map((id) => songMap[id]!)
        .toList();
  }

  // --- Cross-device sync ---

  /// Merges the account's favourites with this device's, in both directions.
  ///
  /// Full state every time, no watermark. A person has tens of favourites, so
  /// moving all of them is cheap — and it removes an entire category of bug:
  /// there is no "changed since" cursor to get wrong, no dirty flag to lose, and
  /// running this twice does nothing the second time.
  ///
  /// Does nothing at all when sync is off or nobody is signed in, and gives up
  /// silently when the server cannot be reached. Being offline is a normal state
  /// for this app, not an error worth surfacing.
  Future<void> sync() async {
    final remote = _remote;
    if (remote == null) return;

    final owner = remote.currentUserId;
    if (owner == null) return;

    if (_localDataSource.getSyncOwner() != owner) {
      // A different account has signed in on this device — a shared tablet, a
      // spouse checking something. The device's favourites are NOT discarded:
      // they are the user's, and discarding either side is the failure this
      // whole design exists to avoid. But the tombstones are, which buys the
      // one invariant worth having here: signing in as somebody else can add
      // favourites to their account and can never remove any.
      await _localDataSource.saveFavoriteRemovals(const {});
    }

    final List<SyncedFavorite> serverRows;
    try {
      serverRows = await remote.fetchFavorites();
    } catch (_) {
      return;
    }

    final claims = _localClaims();
    final wonByServer = <String>{};

    for (final row in serverRows) {
      // Only hymnal songs cross the wire; see [_syncs].
      if (!row.songId.isHymnal) continue;

      final key = row.songId.value;
      final local = claims[key];
      final server = _FavoriteClaim(
        songId: row.songId,
        present: !row.removed,
        at: row.changedAt,
        sortOrder: row.sortOrder,
      );

      // The server wins an exact tie. A tie means the same event coming back to
      // the device that made it, where both sides already agree about
      // membership — so the rule only decides `sortOrder`, and resolving toward
      // the shared copy is what makes two devices converge instead of each
      // keeping its own answer.
      if (local == null || !server.at.isBefore(local.at)) {
        claims[key] = server;
        wonByServer.add(key);
      }
    }

    // Everything the server did not answer for, or answered older than, is
    // ours to push. On a first sign-in that is the whole local collection,
    // which is exactly the "neither side is discarded" requirement.
    final toPush = [
      for (final entry in claims.entries)
        if (!wonByServer.contains(entry.key))
          SyncedFavorite(
            songId: entry.value.songId,
            changedAt: entry.value.at,
            sortOrder: entry.value.sortOrder,
            removed: !entry.value.present,
          ),
    ];

    await _localDataSource.saveFavorites([
      // Favourites of user songs pass through untouched — they never entered
      // the merge and must not be dropped by it.
      for (final favorite in _localDataSource.getFavorites())
        if (!favorite.songId.isHymnal) favorite,
      for (final claim in claims.values)
        if (claim.present)
          Favorite(
            songId: claim.songId,
            addedAt: claim.at,
            sortOrder: claim.sortOrder,
          ),
    ]);

    await _localDataSource.saveFavoriteRemovals({
      for (final claim in claims.values)
        if (!claim.present) claim.songId.value: claim.at,
    });

    await _localDataSource.setSyncOwner(owner);

    // Last, and best-effort. The local state above is already correct; if this
    // fails, those records are still newer than the server's and the next sync
    // pushes them again.
    try {
      await remote.pushFavorites(toPush);
    } catch (_) {
      // Offline, a paused project, a timeout. Not the user's problem.
    }
  }

  /// This device's opinion about every hymnal song it has an opinion about:
  /// present since `addedAt`, or removed at `removedAt`.
  Map<String, _FavoriteClaim> _localClaims() {
    final claims = <String, _FavoriteClaim>{};

    for (final favorite in _localDataSource.getFavorites()) {
      if (!favorite.songId.isHymnal) continue;
      claims[favorite.songId.value] = _FavoriteClaim(
        songId: favorite.songId,
        present: true,
        at: favorite.addedAt,
        sortOrder: favorite.sortOrder,
      );
    }

    _localDataSource.getFavoriteRemovals().forEach((key, removedAt) {
      final songId = SongId.tryParse(key);
      if (songId == null || !songId.isHymnal) return;

      // A live favourite and a tombstone for the same song should not coexist —
      // [addFavorite] clears the tombstone — but if they ever do, the later
      // statement is the device's actual opinion.
      final existing = claims[key];
      if (existing != null && existing.at.isAfter(removedAt)) return;

      claims[key] = _FavoriteClaim(
        songId: songId,
        present: false,
        at: removedAt,
        sortOrder: existing?.sortOrder ?? 0,
      );
    });

    return claims;
  }

  /// Whether this favourite is one that travels.
  ///
  /// A `user:` id names a song that lives on this device only, so a row for it
  /// would be invisible on every other device, and would come back from the
  /// server after the song itself was deleted (`purgeSongReferences` removes
  /// the favourite without leaving a tombstone, because a song that no longer
  /// exists is not an un-favourite). Setlists are different and do carry
  /// `user:` ids: dropping members out of an ordered list corrupts the list.
  bool _syncs(SongId songId) => _remote != null && songId.isHymnal;

  /// Pushes the device's current opinion about [songIds]. Best-effort.
  Future<void> _push(List<SongId> songIds) async {
    final remote = _remote;
    if (remote == null) return;

    final claims = _localClaims();
    final records = <SyncedFavorite>[];
    for (final songId in songIds) {
      final claim = claims[songId.value];
      if (claim == null) continue;
      records.add(SyncedFavorite(
        songId: claim.songId,
        changedAt: claim.at,
        sortOrder: claim.sortOrder,
        removed: !claim.present,
      ));
    }

    try {
      await remote.pushFavorites(records);
    } catch (_) {
      // The device already has the change, and sync() will carry it later.
    }
  }
}

/// One side's opinion about one song: in or out, and when that was decided.
class _FavoriteClaim {
  final SongId songId;
  final bool present;
  final DateTime at;
  final int sortOrder;

  const _FavoriteClaim({
    required this.songId,
    required this.present,
    required this.at,
    required this.sortOrder,
  });
}
