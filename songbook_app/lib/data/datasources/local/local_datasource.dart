import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/song.dart';
import '../../models/song_id.dart';
import '../../models/favorite.dart';
import '../../models/setlist.dart';

/// Local data source for songs and favorites
class LocalDataSource {
  static const _favoritesKey = 'favorites';
  static const _setlistsKey = 'setlists';
  static const _tagOverridesKey = 'song_tag_overrides';
  static const _recentSearchesKey = 'recent_searches';
  static const _userSongsKey = 'user_songs';
  static const _settingsPrefix = 'settings_';

  // Cross-device sync bookkeeping. NEW KEYS, deliberately: `favorites` and
  // `setlists` keep the exact JSON they have always held. Renaming a stored
  // field's key is how this app wiped users' favourites once already (see
  // `Favorite.songId`'s readValue fallback), so nothing that already exists is
  // reshaped to make room for these.
  //
  // A build with sync switched off never writes any of them, and a build that
  // reads them and finds nothing is in exactly the state a device is in the
  // first time it ever syncs.
  static const _favoriteRemovalsKey = 'favorites_removed';
  static const _setlistRemovalsKey = 'setlists_removed';
  static const _syncOwnerKey = 'sync_owner';

  final SharedPreferences _prefs;
  List<Song>? _cachedSongs;

  LocalDataSource(this._prefs);

  /// Loads songs from the bundled JSON asset
  Future<List<Song>> loadSongs() async {
    if (_cachedSongs != null) return _cachedSongs!;

    try {
      final jsonString = await rootBundle.loadString('assets/data/songs.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedSongs = jsonList.map((json) => Song.fromJson(json)).toList();
      _cachedSongs!.sort((a, b) => a.number.compareTo(b.number));
      return _cachedSongs!;
    } catch (e) {
      // Return empty list if file doesn't exist or is invalid
      _cachedSongs = [];
      return _cachedSongs!;
    }
  }

  /// Gets a song by number
  Future<Song?> getSongByNumber(int number) async {
    final songs = await loadSongs();
    try {
      return songs.firstWhere((s) => s.number == number);
    } catch (_) {
      return null;
    }
  }

  /// Clears the song cache (useful for testing or refresh)
  void clearSongCache() {
    _cachedSongs = null;
  }

  /// Decodes the JSON list stored at [key] into records, **skipping** any
  /// entry [fromJson] cannot read.
  ///
  /// Audit finding S14: the previous shape wrapped the whole `map` in one
  /// `try`, so a single malformed record made the entire collection read as
  /// empty — the user saw "no favourites" and the next write erased every
  /// intact record with it. Only a blob that will not decode as a JSON list at
  /// all is a total loss; everything else degrades one record at a time.
  List<T> _decodeRecords<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return [];

    final List<dynamic> jsonList;
    try {
      jsonList = json.decode(jsonString) as List<dynamic>;
    } catch (_) {
      return [];
    }

    final records = <T>[];
    for (final entry in jsonList) {
      try {
        records.add(fromJson(entry as Map<String, dynamic>));
      } catch (_) {
        continue; // drop just this record
      }
    }
    return records;
  }

  // --- Favorites ---

  /// Gets all favorites (unreadable records are skipped, see [_decodeRecords])
  List<Favorite> getFavorites() =>
      _decodeRecords(_favoritesKey, Favorite.fromJson);

  /// Saves favorites
  Future<bool> saveFavorites(List<Favorite> favorites) async {
    final jsonString = json.encode(favorites.map((f) => f.toJson()).toList());
    return _prefs.setString(_favoritesKey, jsonString);
  }

  /// Adds a song to favorites
  Future<bool> addFavorite(SongId songId) async {
    final favorites = getFavorites();
    if (favorites.any((f) => f.songId == songId)) {
      return true; // Already a favorite
    }

    final maxSortOrder = favorites.isEmpty
        ? 0
        : favorites.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b);

    favorites.add(Favorite(
      songId: songId,
      addedAt: DateTime.now(),
      sortOrder: maxSortOrder + 1,
    ));

    return saveFavorites(favorites);
  }

  /// Removes a song from favorites
  Future<bool> removeFavorite(SongId songId) async {
    final favorites = getFavorites();
    favorites.removeWhere((f) => f.songId == songId);
    return saveFavorites(favorites);
  }

  /// Checks if a song is a favorite
  bool isFavorite(SongId songId) {
    return getFavorites().any((f) => f.songId == songId);
  }

  // --- Setlists ---

  /// Gets all setlists (unreadable records are skipped, see [_decodeRecords])
  List<Setlist> getSetlists() =>
      _decodeRecords(_setlistsKey, Setlist.fromJson);

  /// Saves all setlists
  Future<bool> saveSetlists(List<Setlist> setlists) async {
    final jsonString = json.encode(setlists.map((s) => s.toJson()).toList());
    return _prefs.setString(_setlistsKey, jsonString);
  }

  // --- Removals (tombstones) ---

  /// When each removed record was removed, keyed by the record's identity —
  /// a [SongId] string for favourites, a setlist id for setlists.
  ///
  /// **A deletion has to be a stored fact, not an absent one.** Absence cannot
  /// be told apart from "this device has not heard of it yet": read as a
  /// removal it would delete everything a new device has yet to learn about,
  /// read as ignorance it would resurrect every favourite anyone has ever
  /// removed, on the next sync, forever.
  ///
  /// A map rather than a list of records: there is exactly one removal per
  /// identity, and a map says so without needing a rule about duplicates.
  Map<String, DateTime> _getRemovals(String key) {
    final jsonString = _prefs.getString(key);
    if (jsonString == null) return {};

    try {
      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      final result = <String, DateTime>{};
      decoded.forEach((identity, at) {
        if (at is! String) return;
        final removedAt = DateTime.tryParse(at);
        if (removedAt == null) return;
        result[identity] = removedAt;
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<bool> _saveRemovals(String key, Map<String, DateTime> removals) {
    final encodable = removals.map(
      (identity, at) => MapEntry(identity, at.toIso8601String()),
    );
    return _prefs.setString(key, json.encode(encodable));
  }

  /// Favourites this device has removed, and when. Keyed by [SongId.value].
  Map<String, DateTime> getFavoriteRemovals() =>
      _getRemovals(_favoriteRemovalsKey);

  Future<bool> saveFavoriteRemovals(Map<String, DateTime> removals) =>
      _saveRemovals(_favoriteRemovalsKey, removals);

  /// Setlists this device has deleted, and when. Keyed by setlist id.
  Map<String, DateTime> getSetlistRemovals() =>
      _getRemovals(_setlistRemovalsKey);

  Future<bool> saveSetlistRemovals(Map<String, DateTime> removals) =>
      _saveRemovals(_setlistRemovalsKey, removals);

  /// The account id these collections belong to, or null if they have never
  /// been synced.
  ///
  /// Read only to notice that a *different* account has signed in on this
  /// device — a shared tablet, or a spouse checking something. The collections
  /// are not thrown away when that happens (they are the user's, and this app
  /// works signed-out), but the tombstones are, which buys one invariant:
  /// signing in as someone else can add to their account and can never remove
  /// from it.
  String? getSyncOwner() => _prefs.getString(_syncOwnerKey);

  Future<bool> setSyncOwner(String userId) =>
      _prefs.setString(_syncOwnerKey, userId);

  // --- Tag Overrides ---

  /// Gets per-song tag overrides keyed by song.
  ///
  /// An override REPLACES the bundled tags for that song (uniformly handles
  /// add and remove). Returns an empty map if none stored or on decode error.
  ///
  /// Keys were bare song numbers before song ids existed. [SongId.tryParse]
  /// reads those as hymnal ids, so overrides stored by an older build survive
  /// the upgrade untouched; unparseable keys are dropped rather than failing
  /// the whole read, matching how [_decodeRecords] treats a bad record.
  Map<SongId, List<String>> getTagOverrides() {
    final jsonString = _prefs.getString(_tagOverridesKey);
    if (jsonString == null) return {};

    try {
      final Map<String, dynamic> decoded = json.decode(jsonString);
      final result = <SongId, List<String>>{};
      decoded.forEach((key, value) {
        final songId = SongId.tryParse(key);
        if (songId == null || value is! List) return;
        result[songId] = value.map((e) => e.toString()).toList();
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  /// Saves all per-song tag overrides as a single JSON blob.
  Future<bool> saveTagOverrides(Map<SongId, List<String>> overrides) async {
    final encodable =
        overrides.map((key, value) => MapEntry(key.value, value));
    return _prefs.setString(_tagOverridesKey, json.encode(encodable));
  }

  /// Sets the tag override for a single song.
  Future<bool> setSongTags(SongId songId, List<String> tags) async {
    final overrides = getTagOverrides();
    overrides[songId] = tags;
    return saveTagOverrides(overrides);
  }

  /// Clears the tag override for a single song (reverting to bundled tags).
  Future<bool> clearSongTags(SongId songId) async {
    final overrides = getTagOverrides();
    overrides.remove(songId);
    return saveTagOverrides(overrides);
  }
  // --- Recently searched ---

  /// Maximum number of remembered search queries.
  ///
  /// Short on purpose: this is shown in the space where a search field has just
  /// opened, and a long list there is another thing to read instead of the one
  /// thing you came to do.
  static const recentSearchesLimit = 8;

  /// Remembered search queries, most recent first.
  List<String> getRecentSearches() {
    final jsonString = _prefs.getString(_recentSearchesKey);
    if (jsonString == null) return [];
    try {
      final decoded = json.decode(jsonString) as List<dynamic>;
      return [
        for (final entry in decoded)
          if (entry is String && entry.trim().isNotEmpty) entry,
      ];
    } catch (_) {
      return [];
    }
  }

  /// Records [query] as the most recent search.
  ///
  /// De-duplicates case-insensitively — searching "Szarvas" after "szarvas"
  /// should move the one entry, not add a second that looks identical — and caps
  /// the list at [recentSearchesLimit].
  Future<bool> recordRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    final kept = getRecentSearches()
        .where((q) => q.toLowerCase() != lower)
        .toList()
      ..insert(0, trimmed);
    return _prefs.setString(
      _recentSearchesKey,
      json.encode(kept.take(recentSearchesLimit).toList()),
    );
  }

  Future<bool> clearRecentSearches() => _prefs.remove(_recentSearchesKey);

  // --- User songs ---

  /// Songs the user imported or wrote, in insertion order.
  ///
  /// These live alongside the bundled catalogue rather than inside it:
  /// `songs.json` is a read-only asset, so anything the user adds has to be
  /// stored separately and merged at read time. Unreadable records are skipped
  /// one at a time, never taking the whole collection with them
  /// (see [_decodeRecords]).
  List<Song> getUserSongs() => _decodeRecords(_userSongsKey, Song.fromJson);

  /// Replaces the whole user-song collection.
  Future<bool> saveUserSongs(List<Song> songs) {
    final jsonString = json.encode(songs.map((s) => s.toJson()).toList());
    return _prefs.setString(_userSongsKey, jsonString);
  }

  /// Inserts [song], or replaces the existing one with the same [Song.id].
  ///
  /// Keyed by id, not by number: two user songs may legitimately share a
  /// number when they sit in different songbooks.
  Future<bool> upsertUserSong(Song song) {
    final songs = getUserSongs();
    final index = songs.indexWhere((s) => s.id == song.id);
    if (index == -1) {
      songs.add(song);
    } else {
      songs[index] = song;
    }
    return saveUserSongs(songs);
  }

  /// Removes the user song with [songId]. Returns false if it was not there.
  Future<bool> deleteUserSong(SongId songId) async {
    final songs = getUserSongs();
    final before = songs.length;
    songs.removeWhere((s) => s.id == songId);
    if (songs.length == before) return false;
    return saveUserSongs(songs);
  }

  // --- Cross-collection cleanup ---

  /// Removes every stored reference to [songId] from the collections that point
  /// at songs: favourites, setlists and tag overrides.
  ///
  /// Nothing here fails loudly if a reference is absent — the whole thing is
  /// idempotent, which is what makes it safe to run after a delete that found
  /// nothing.
  ///
  /// This lives here rather than in each repository because this class owns all
  /// four blobs, and because the reason to do it is one reason: a user song's id
  /// is minted from a timestamp plus randomness and is never reissued, so a
  /// reference that outlives its song can never resolve again. Every one of
  /// these collections skips ids it cannot find, which makes the leftovers
  /// invisible rather than harmless.
  Future<void> purgeSongReferences(SongId songId) async {
    await removeFavorite(songId);
    await clearSongTags(songId);

    // Setlists keep their `updatedAt`: dropping a reference the user cannot see
    // any more is not an edit they made to the setlist.
    final setlists = getSetlists();
    var setlistsChanged = false;
    for (var i = 0; i < setlists.length; i++) {
      if (!setlists[i].songIds.contains(songId)) continue;
      setlists[i] = setlists[i].copyWith(
        songIds: setlists[i].songIds.where((id) => id != songId).toList(),
      );
      setlistsChanged = true;
    }
    if (setlistsChanged) await saveSetlists(setlists);

  }

  // --- Settings ---

  /// Gets a string setting
  String? getStringSetting(String key) {
    return _prefs.getString('$_settingsPrefix$key');
  }

  /// Sets a string setting
  Future<bool> setStringSetting(String key, String value) {
    return _prefs.setString('$_settingsPrefix$key', value);
  }

  /// Removes a string setting
  Future<bool> removeStringSetting(String key) {
    return _prefs.remove('$_settingsPrefix$key');
  }

  /// Gets an int setting
  int? getIntSetting(String key) {
    return _prefs.getInt('$_settingsPrefix$key');
  }

  /// Sets an int setting
  Future<bool> setIntSetting(String key, int value) {
    return _prefs.setInt('$_settingsPrefix$key', value);
  }

  /// Removes an int setting
  Future<bool> removeIntSetting(String key) {
    return _prefs.remove('$_settingsPrefix$key');
  }

  /// Gets a bool setting
  bool? getBoolSetting(String key) {
    return _prefs.getBool('$_settingsPrefix$key');
  }

  /// Sets a bool setting
  Future<bool> setBoolSetting(String key, bool value) {
    return _prefs.setBool('$_settingsPrefix$key', value);
  }
}
