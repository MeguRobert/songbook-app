import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/datasources/remote/remote_sync_datasource.dart';
import 'package:songbook_app/data/models/setlist.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/repositories/favorites_repository.dart';
import 'package:songbook_app/data/repositories/setlist_repository.dart';

/// An account's rows, in memory.
///
/// Hand-written rather than mocked because every interesting assertion here is
/// about what was *pushed* and what the two sides did with each other's
/// timestamps, and a fake that applies a push the way the real upsert does lets
/// a test sync twice and check that the second one is a no-op.
class FakeSyncDataSource implements RemoteSyncDataSource {
  FakeSyncDataSource({this.currentUserId = 'account-1'});

  @override
  String? currentUserId;

  List<SyncedFavorite> serverFavorites = [];
  List<SyncedSetlist> serverSetlists = [];

  final List<List<SyncedFavorite>> favoritePushes = [];
  final List<List<SyncedSetlist>> setlistPushes = [];

  bool failFetch = false;
  bool failPush = false;

  @override
  Future<List<SyncedFavorite>> fetchFavorites() async {
    if (failFetch) throw Exception('offline');
    return List.of(serverFavorites);
  }

  @override
  Future<void> pushFavorites(List<SyncedFavorite> favorites) async {
    // The real one returns before touching the network on an empty list, and a
    // fake that recorded the call anyway would make "syncing twice pushes
    // nothing" pass on a technicality.
    if (favorites.isEmpty) return;
    if (failPush) throw Exception('offline');
    favoritePushes.add(List.of(favorites));
    for (final favorite in favorites) {
      serverFavorites.removeWhere((row) => row.songId == favorite.songId);
      serverFavorites.add(favorite);
    }
  }

  @override
  Future<List<SyncedSetlist>> fetchSetlists() async {
    if (failFetch) throw Exception('offline');
    return List.of(serverSetlists);
  }

  @override
  Future<void> pushSetlists(List<SyncedSetlist> setlists) async {
    if (setlists.isEmpty) return;
    if (failPush) throw Exception('offline');
    setlistPushes.add(List.of(setlists));
    for (final setlist in setlists) {
      serverSetlists.removeWhere((row) => row.id == setlist.id);
      serverSetlists.add(setlist);
    }
  }

  /// The last push, flattened. Every test that looks at a push wants this.
  List<SyncedFavorite> get lastFavoritePush =>
      favoritePushes.isEmpty ? const [] : favoritePushes.last;

  List<SyncedSetlist> get lastSetlistPush =>
      setlistPushes.isEmpty ? const [] : setlistPushes.last;
}

DateTime at(int day, [int hour = 12]) => DateTime(2026, 8, day, hour);

String favoritesBlob(List<(SongId, DateTime, int)> entries) => json.encode([
      for (final (songId, addedAt, sortOrder) in entries)
        {
          'songId': songId.value,
          'addedAt': addedAt.toIso8601String(),
          'sortOrder': sortOrder,
        },
    ]);

String setlistsBlob(List<Setlist> setlists) =>
    json.encode([for (final s in setlists) s.toJson()]);

Setlist setlist(
  String id, {
  String name = 'Sunday',
  List<SongId> songIds = const [],
  DateTime? createdAt,
  DateTime? updatedAt,
}) =>
    Setlist(
      id: id,
      name: name,
      songIds: songIds,
      createdAt: createdAt ?? at(1),
      updatedAt: updatedAt ?? at(1),
    );

Future<LocalDataSource> localWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return LocalDataSource(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // The flag being off is the shipped state, so it is tested first and hardest.
  // -------------------------------------------------------------------------
  group('with no remote (the shipped default)', () {
    test('favourites report that they do not sync, and syncing does nothing',
        () async {
      final local = await localWith({});
      final repository = FavoritesRepository(local);

      expect(repository.syncsAcrossDevices, isFalse);
      await repository.sync();

      await repository.addFavorite(const SongId.hymnal(5));
      await repository.removeFavorite(const SongId.hymnal(5));

      expect(repository.getFavorites(), isEmpty);
      expect(local.getFavoriteRemovals(), isEmpty,
          reason: 'a build with the flag off writes no tombstones at all, so '
              'nothing new is stored and nothing new can be misread later');
      expect(local.getSyncOwner(), isNull);
    });

    test('setlists report that they do not sync, and syncing does nothing',
        () async {
      final local = await localWith({});
      final repository = SetlistRepository(local);

      expect(repository.syncsAcrossDevices, isFalse);
      await repository.sync();

      final created = await repository.createSetlist('Sunday');
      await repository.addSong(created.id, const SongId.hymnal(90));
      await repository.deleteSetlist(created.id);

      expect(repository.getSetlists(), isEmpty);
      expect(local.getSetlistRemovals(), isEmpty);
      expect(local.getSyncOwner(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Favourites: a set with tombstones.
  // -------------------------------------------------------------------------
  group('favourites merge', () {
    late LocalDataSource local;
    late FakeSyncDataSource remote;
    late FavoritesRepository repository;

    Future<void> withLocal(Map<String, Object> values) async {
      local = await localWith(values);
      remote = FakeSyncDataSource();
      repository = FavoritesRepository(local, remote);
    }

    test('first sign-in keeps BOTH sides', () async {
      await withLocal({
        'favorites': favoritesBlob([(const SongId.hymnal(5), at(1), 0)]),
      });
      remote.serverFavorites = [
        SyncedFavorite(songId: const SongId.hymnal(7), changedAt: at(2)),
      ];

      await repository.sync();

      expect(repository.getFavoriteSongIds(),
          containsAll([const SongId.hymnal(5), const SongId.hymnal(7)]),
          reason: 'discarding either side is the failure the whole design '
              'exists to avoid');
      expect(remote.lastFavoritePush.map((f) => f.songId),
          [const SongId.hymnal(5)],
          reason: 'the account had never heard of 5, so it is ours to push; 7 '
              'came from the account and is not pushed back');
      expect(local.getSyncOwner(), 'account-1');
    });

    test('an un-favourite made here survives the sync that follows it',
        () async {
      await withLocal({
        'favorites': favoritesBlob([(const SongId.hymnal(5), at(1), 0)]),
      });
      remote.serverFavorites = [
        SyncedFavorite(songId: const SongId.hymnal(5), changedAt: at(1)),
      ];

      await repository.removeFavorite(const SongId.hymnal(5));
      await repository.sync();

      expect(repository.isFavorite(const SongId.hymnal(5)), isFalse,
          reason: 'without a tombstone the account simply re-adds it, which is '
              'the un-favourite that will not stick');
      expect(remote.serverFavorites.single.removed, isTrue,
          reason: 'and the other device has to be told, or it re-adds it there');
    });

    test('a removal on the other device removes it here', () async {
      await withLocal({
        'favorites': favoritesBlob([(const SongId.hymnal(5), at(1), 0)]),
      });
      remote.serverFavorites = [
        SyncedFavorite(
            songId: const SongId.hymnal(5), changedAt: at(3), removed: true),
      ];

      await repository.sync();

      expect(repository.isFavorite(const SongId.hymnal(5)), isFalse);
      expect(local.getFavoriteRemovals().keys, ['hymnal:5'],
          reason: 'the removal is now this device\'s opinion too, and has to '
              'be stored as one so a third device hears about it');
    });

    test('re-favouriting after a removal beats the older tombstone', () async {
      await withLocal({});
      remote.serverFavorites = [
        SyncedFavorite(
            songId: const SongId.hymnal(5), changedAt: at(1), removed: true),
      ];

      await repository.addFavorite(const SongId.hymnal(5));
      await repository.sync();

      expect(repository.isFavorite(const SongId.hymnal(5)), isTrue,
          reason: 'the add is later than the removal, so it wins');
      expect(remote.serverFavorites.single.removed, isFalse);
    });

    test('adding a song back clears its tombstone', () async {
      await withLocal({
        'favorites': favoritesBlob([(const SongId.hymnal(5), at(1), 0)]),
      });

      await repository.removeFavorite(const SongId.hymnal(5));
      expect(local.getFavoriteRemovals().keys, ['hymnal:5']);

      await repository.addFavorite(const SongId.hymnal(5));

      expect(local.getFavoriteRemovals(), isEmpty,
          reason: 'a tombstone that outlives its reason is a second opinion '
              'about the same song, and the merge would then pick whichever '
              'timestamp happened to be later');
    });

    test('an exact tie goes to the account, so devices converge', () async {
      await withLocal({
        'favorites': favoritesBlob([(const SongId.hymnal(5), at(1), 9)]),
      });
      remote.serverFavorites = [
        SyncedFavorite(
            songId: const SongId.hymnal(5), changedAt: at(1), sortOrder: 2),
      ];

      await repository.sync();

      expect(repository.getFavorites().single.sortOrder, 2,
          reason: 'a tie is the same event coming home, so both sides already '
              'agree about membership; the rule only decides the order, and it '
              'resolves toward the shared copy');
      expect(remote.lastFavoritePush, isEmpty);
    });

    test('a favourite of a user song never leaves the device', () async {
      await withLocal({
        'favorites': favoritesBlob([
          (const SongId.hymnal(5), at(1), 0),
          (const SongId.user('l9f3a2'), at(1), 1),
        ]),
      });

      await repository.sync();

      expect(repository.getFavoriteSongIds(),
          containsAll([const SongId.hymnal(5), const SongId.user('l9f3a2')]),
          reason: 'the merge must not drop what it declined to carry');
      expect(remote.lastFavoritePush.map((f) => f.songId),
          [const SongId.hymnal(5)],
          reason: 'a user song lives on one device, so a row for it would be '
              'invisible everywhere else');
    });

    test('an unreachable account leaves the device exactly as it was',
        () async {
      await withLocal({
        'favorites': favoritesBlob([(const SongId.hymnal(5), at(1), 0)]),
      });
      remote.failFetch = true;

      await repository.sync();

      expect(repository.getFavoriteSongIds(), [const SongId.hymnal(5)]);
      expect(local.getSyncOwner(), isNull,
          reason: 'nothing was merged, so nothing may claim to have been');
    });

    test('a failed push loses nothing: the next sync carries it', () async {
      await withLocal({});
      remote.failPush = true;

      await repository.addFavorite(const SongId.hymnal(5));

      expect(repository.isFavorite(const SongId.hymnal(5)), isTrue,
          reason: 'the write is complete when the device has it');
      expect(remote.serverFavorites, isEmpty);

      remote.failPush = false;
      await repository.sync();

      expect(remote.serverFavorites.single.songId, const SongId.hymnal(5),
          reason: 'the local store is the outbox -- a record the server never '
              'received is a record newer than the server\'s');
    });

    test('syncing twice pushes nothing the second time', () async {
      await withLocal({
        'favorites': favoritesBlob([(const SongId.hymnal(5), at(1), 0)]),
      });

      await repository.sync();
      final pushesAfterFirst = remote.favoritePushes.length;
      await repository.sync();

      expect(remote.favoritePushes.length, pushesAfterFirst,
          reason: 'full-state sync has to be idempotent, or every app start '
              'rewrites every row');
    });

    test('a different account signing in can add but never remove', () async {
      await withLocal({
        'favorites': favoritesBlob([(const SongId.hymnal(5), at(1), 0)]),
      });

      // This device removed 90 while it belonged to somebody else.
      await local.saveFavoriteRemovals({'hymnal:90': at(9)});
      await local.setSyncOwner('somebody-else');

      remote.serverFavorites = [
        SyncedFavorite(songId: const SongId.hymnal(90), changedAt: at(2)),
      ];

      await repository.sync();

      expect(repository.isFavorite(const SongId.hymnal(90)), isTrue,
          reason: 'a tombstone made on another account\'s behalf must not '
              'delete this account\'s favourite -- a shared tablet is a real '
              'scenario, and the invariant is add-only across accounts');
      expect(repository.isFavorite(const SongId.hymnal(5)), isTrue,
          reason: 'and the device\'s own favourites are not discarded either');
      expect(local.getSyncOwner(), 'account-1');
    });

    test('nothing is pushed while signed out', () async {
      await withLocal({});
      remote.currentUserId = null;

      await repository.addFavorite(const SongId.hymnal(5));
      await repository.sync();

      expect(repository.isFavorite(const SongId.hymnal(5)), isTrue);
      expect(local.getSyncOwner(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Setlists: whole-record last-write-wins.
  // -------------------------------------------------------------------------
  group('setlists merge', () {
    late LocalDataSource local;
    late FakeSyncDataSource remote;
    late SetlistRepository repository;

    Future<void> withLocal(Map<String, Object> values) async {
      local = await localWith(values);
      remote = FakeSyncDataSource();
      repository = SetlistRepository(local, remote);
    }

    test('both devices\' shelves survive a first sign-in', () async {
      await withLocal({
        'setlists': setlistsBlob([setlist('sl_phone', name: 'Morning')]),
      });
      remote.serverSetlists = [
        SyncedSetlist(
          id: 'sl_tablet',
          name: 'Evening',
          songIds: const [SongId.hymnal(90)],
          createdAt: at(1),
          changedAt: at(2),
        ),
      ];

      await repository.sync();

      expect(repository.getSetlists().map((s) => s.id),
          containsAll(['sl_phone', 'sl_tablet']));
      expect(remote.lastSetlistPush.map((s) => s.id), ['sl_phone']);
    });

    test('two setlists with the same name are two setlists', () async {
      await withLocal({
        'setlists': setlistsBlob([setlist('sl_phone', name: 'Sunday Morning')]),
      });
      remote.serverSetlists = [
        SyncedSetlist(
          id: 'sl_tablet',
          name: 'Sunday Morning',
          songIds: const [],
          createdAt: at(1),
          changedAt: at(2),
        ),
      ];

      await repository.sync();

      expect(repository.getSetlists(), hasLength(2),
          reason: 'merging by name would silently combine two different lists, '
              'which is worse than showing the same name twice');
    });

    test('the later edit replaces the whole record, and the earlier is lost',
        () async {
      await withLocal({
        'setlists': setlistsBlob([
          setlist('sl_1',
              name: 'renamed here',
              songIds: const [SongId.hymnal(5)],
              updatedAt: at(1)),
        ]),
      });
      remote.serverSetlists = [
        SyncedSetlist(
          id: 'sl_1',
          name: 'Sunday',
          songIds: const [SongId.hymnal(90), SongId.hymnal(91)],
          createdAt: at(1),
          changedAt: at(2),
        ),
      ];

      await repository.sync();

      final merged = repository.getById('sl_1')!;
      expect(merged.name, 'Sunday');
      expect(merged.songIds, [const SongId.hymnal(90), const SongId.hymnal(91)]);
      // Said out loud, because it is the cost of this decision rather than an
      // accident of it: the local rename is GONE, not merged in.
      expect(merged.name, isNot('renamed here'));
    });

    test('an edit made here beats an older copy on the account', () async {
      await withLocal({
        'setlists': setlistsBlob([
          setlist('sl_1', name: 'newer', updatedAt: at(5)),
        ]),
      });
      remote.serverSetlists = [
        SyncedSetlist(
          id: 'sl_1',
          name: 'older',
          songIds: const [],
          createdAt: at(1),
          changedAt: at(2),
        ),
      ];

      await repository.sync();

      expect(repository.getById('sl_1')!.name, 'newer');
      expect(remote.serverSetlists.single.name, 'newer');
    });

    test('a delete made here survives the sync that follows it', () async {
      await withLocal({
        'setlists': setlistsBlob([setlist('sl_1', updatedAt: at(1))]),
      });
      remote.serverSetlists = [
        SyncedSetlist(
          id: 'sl_1',
          name: 'Sunday',
          songIds: const [],
          createdAt: at(1),
          changedAt: at(1),
        ),
      ];

      await repository.deleteSetlist('sl_1');
      await repository.sync();

      expect(repository.getSetlists(), isEmpty);
      expect(remote.serverSetlists.single.removed, isTrue);
    });

    test('a delete on the other device removes it here', () async {
      await withLocal({
        'setlists': setlistsBlob([setlist('sl_1', updatedAt: at(1))]),
      });
      remote.serverSetlists = [
        SyncedSetlist(
          id: 'sl_1',
          name: 'Sunday',
          songIds: const [],
          createdAt: at(1),
          changedAt: at(4),
          removed: true,
        ),
      ];

      await repository.sync();

      expect(repository.getSetlists(), isEmpty);
      expect(local.getSetlistRemovals().keys, ['sl_1']);
    });

    test('a setlist edited after a delete comes back', () async {
      await withLocal({
        'setlists': setlistsBlob([setlist('sl_1', updatedAt: at(6))]),
      });
      remote.serverSetlists = [
        SyncedSetlist(
          id: 'sl_1',
          name: 'Sunday',
          songIds: const [],
          createdAt: at(1),
          changedAt: at(2),
          removed: true,
        ),
      ];

      await repository.sync();

      expect(repository.getById('sl_1'), isNotNull,
          reason: 'delete and edit are two claims about one record, and the '
              'later one wins in both directions');
    });

    test('every mutator reaches the account', () async {
      await withLocal({});

      final created = await repository.createSetlist('Sunday');
      await repository.addSong(created.id, const SongId.hymnal(90));
      await repository.renameSetlist(created.id, 'Sunday Morning');
      await repository.reorderSongs(created.id, const [SongId.hymnal(90)]);

      final row = remote.serverSetlists.single;
      expect(row.id, created.id);
      expect(row.name, 'Sunday Morning');
      expect(row.songIds, [const SongId.hymnal(90)]);
      expect(row.removed, isFalse);
    });

    test('a setlist carries its user songs verbatim', () async {
      await withLocal({});
      final created = await repository.createSetlist('Sunday');
      await repository.addSong(created.id, const SongId.user('l9f3a2'));

      expect(remote.serverSetlists.single.songIds,
          [const SongId.user('l9f3a2')],
          reason: 'dropping a member out of an ordered list corrupts the list; '
              'a device that cannot resolve the id already skips it when it '
              'renders');
    });

    test('an unreachable account leaves the device exactly as it was',
        () async {
      await withLocal({
        'setlists': setlistsBlob([setlist('sl_1', name: 'Morning')]),
      });
      remote.failFetch = true;

      await repository.sync();

      expect(repository.getById('sl_1')!.name, 'Morning');
      expect(local.getSyncOwner(), isNull);
    });

    test('a failed push loses nothing: the next sync carries it', () async {
      await withLocal({});
      remote.failPush = true;

      final created = await repository.createSetlist('Sunday');

      expect(repository.getById(created.id), isNotNull);
      expect(remote.serverSetlists, isEmpty);

      remote.failPush = false;
      await repository.sync();

      expect(remote.serverSetlists.single.id, created.id);
    });

    test('a different account signing in can add but never delete', () async {
      await withLocal({
        'setlists': setlistsBlob([setlist('sl_mine', name: 'Mine')]),
      });
      await local.saveSetlistRemovals({'sl_theirs': at(9)});
      await local.setSyncOwner('somebody-else');

      remote.serverSetlists = [
        SyncedSetlist(
          id: 'sl_theirs',
          name: 'Theirs',
          songIds: const [],
          createdAt: at(1),
          changedAt: at(2),
        ),
      ];

      await repository.sync();

      expect(repository.getSetlists().map((s) => s.id),
          containsAll(['sl_mine', 'sl_theirs']),
          reason: 'a tombstone made while the device belonged to another '
              'account must not delete this account\'s setlist');
    });
  });
}
