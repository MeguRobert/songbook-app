import '../../core/theme/app_theme.dart';
import '../datasources/local/local_datasource.dart';
import '../models/song_id.dart';
import '../models/view_config.dart';

/// Keys for settings storage
class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const showChords = 'show_chords';
  static const fontSize = 'font_size';
  static const viewConfig = 'view_config';
  static const projectionMode = 'projection_mode';
  static const selectedBook = 'selected_book';

}

/// Repository for app settings
class SettingsRepository {
  final LocalDataSource _localDataSource;

  SettingsRepository(this._localDataSource, {this.photoImportEndpointOverride});

  // --- Theme ---

  AppThemeMode getThemeMode() {
    final value = _localDataSource.getStringSetting(SettingsKeys.themeMode);
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<bool> setThemeMode(AppThemeMode mode) {
    return _localDataSource.setStringSetting(SettingsKeys.themeMode, mode.name);
  }

  // --- Chords ---

  bool getShowChords() {
    return _localDataSource.getBoolSetting(SettingsKeys.showChords) ?? true;
  }

  Future<bool> setShowChords(bool show) {
    return _localDataSource.setBoolSetting(SettingsKeys.showChords, show);
  }

  // --- Font Size ---

  double getFontSize() {
    final size = _localDataSource.getIntSetting(SettingsKeys.fontSize);
    return size?.toDouble() ?? 18.0;
  }

  Future<bool> setFontSize(double size) {
    return _localDataSource.setIntSetting(SettingsKeys.fontSize, size.round());
  }

  // --- View Config ---

  ViewConfig getViewConfig() {
    final value = _localDataSource.getStringSetting(SettingsKeys.viewConfig);
    if (value == null) {
      return const ViewConfig(); // Default: all on
    }
    return ViewConfig.fromStorageString(value);
  }

  Future<bool> setViewConfig(ViewConfig config) {
    return _localDataSource.setStringSetting(
      SettingsKeys.viewConfig,
      config.toStorageString(),
    );
  }

  // --- Per-Song View Config ---

  /// Per-song settings are keyed by [SongId], not by number: a user song
  /// numbered 42 and hymnal 42 are different songs and must not share a
  /// preference.
  ///
  /// [legacyKey] is the pre-[SongId] key, a bare number. It is read as a
  /// fallback so a per-song preference set by an earlier build is not orphaned
  /// by the rename. Only hymnal songs can have one — nothing else existed.
  String _songKey(String prefix, SongId songId) => '${prefix}_${songId.value}';

  String? _legacySongKey(String prefix, SongId songId) {
    final number = songId.hymnalNumber;
    return number == null ? null : '${prefix}_$number';
  }

  String? _readSongSetting(String prefix, SongId songId) {
    final current =
        _localDataSource.getStringSetting(_songKey(prefix, songId));
    if (current != null) return current;
    final legacy = _legacySongKey(prefix, songId);
    return legacy == null ? null : _localDataSource.getStringSetting(legacy);
  }

  ViewConfig? getSongViewConfig(SongId songId) {
    final value = _readSongSetting('song_view_config', songId);
    if (value == null) return null;
    return ViewConfig.fromStorageString(value);
  }

  Future<bool> setSongViewConfig(SongId songId, ViewConfig config) {
    return _localDataSource.setStringSetting(
      _songKey('song_view_config', songId),
      config.toStorageString(),
    );
  }

  /// Clears the override, including any left under the pre-[SongId] key.
  ///
  /// Removing only the current key would let [getSongViewConfig]'s legacy
  /// fallback resurrect an override the user just cleared.
  Future<bool> clearSongViewConfig(SongId songId) async {
    final removed = await _localDataSource
        .removeStringSetting(_songKey('song_view_config', songId));
    final legacy = _legacySongKey('song_view_config', songId);
    if (legacy == null) return removed;
    final legacyRemoved = await _localDataSource.removeStringSetting(legacy);
    return removed || legacyRemoved;
  }

  // --- Photo import ---

  /// The sheet-music reader, or null when this build has none.
  ///
  /// Compiled in, and deliberately not configurable. Two reasons. Nobody
  /// reading a hymnal has any use for a service address — it is infrastructure,
  /// and it was the only setting in the app that pointed somewhere outside
  /// itself. And a settable address is an address that can be pointed
  /// somewhere hostile: it used to be writable from a URL parameter, and the
  /// notation request carries the signed-in user's Supabase access token, so
  /// the two together were a way to be handed somebody's account. Removing the
  /// setting removes that, rather than guarding it.
  ///
  /// Only the notation half needs an address at all. A photographed chord sheet
  /// is read on the device.
  ///
  /// Set with `--dart-define=PHOTO_IMPORT_ENDPOINT=...`; the deployed build
  /// passes the project's Cloud Run service (see
  /// `.github/workflows/deploy-pages.yml`). Empty everywhere else, which is
  /// what keeps a test from reaching for a network, and which the import screen
  /// explains rather than offering a dead button.
  ///
  /// Parsed here rather than at the call site so a bad `--dart-define` cannot
  /// surface as a crash mid-import: unparseable or non-http reads as "no
  /// reader", a state the UI already has to explain.
  Uri? getPhotoImportEndpoint() {
    final raw = _photoImportEndpoint.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    // `host.isNotEmpty`, not `hasAuthority`: `https://` has an authority
    // section — the `//` — with nothing in it, so hasAuthority is true and the
    // result is a Uri that cannot be requested.
    if (uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  /// Substituted by tests, which compile without any `--dart-define`.
  final String? photoImportEndpointOverride;

  String get _photoImportEndpoint =>
      photoImportEndpointOverride ?? _compiledEndpoint;

  static const _compiledEndpoint =
      String.fromEnvironment('PHOTO_IMPORT_ENDPOINT');

  // --- Projection Mode ---

  bool getProjectionMode() {
    return _localDataSource.getBoolSetting(SettingsKeys.projectionMode) ?? false;
  }

  Future<bool> setProjectionMode(bool enabled) {
    return _localDataSource.setBoolSetting(SettingsKeys.projectionMode, enabled);
  }

  // --- Selected Book ---

  /// Returns the currently selected book name, or null for the "All Songs" view.
  String? getSelectedBook() {
    return _localDataSource.getStringSetting(SettingsKeys.selectedBook);
  }

  Future<bool> setSelectedBook(String bookName) {
    return _localDataSource.setStringSetting(
      SettingsKeys.selectedBook,
      bookName,
    );
  }

  /// Clears the selected book, returning to the "All Songs" view.
  Future<bool> clearSelectedBook() {
    return _localDataSource.removeStringSetting(SettingsKeys.selectedBook);
  }

  // --- Auto-scroll speed (per song) ---

  /// Default auto-scroll speed in logical pixels per second.
  static const defaultAutoScrollSpeed = 40;

  /// Returns the saved auto-scroll speed (logical px/s) for [songId],
  /// falling back to [defaultAutoScrollSpeed] when none has been set.
  int getAutoScrollSpeed(SongId songId) {
    final current =
        _localDataSource.getIntSetting(_songKey('autoscroll_speed', songId));
    if (current != null) return current;
    final legacy = _legacySongKey('autoscroll_speed', songId);
    final fromLegacy =
        legacy == null ? null : _localDataSource.getIntSetting(legacy);
    return fromLegacy ?? defaultAutoScrollSpeed;
  }

  /// Persists the auto-scroll speed (logical px/s) for [songId].
  Future<bool> setAutoScrollSpeed(SongId songId, int pixelsPerSecond) {
    return _localDataSource.setIntSetting(
        _songKey('autoscroll_speed', songId), pixelsPerSecond);
  }

  // --- Deleting a song's preferences ---

  /// Removes every per-song preference for [songId].
  ///
  /// Called when a user song is deleted. `UserSongRepository.add` writes a view
  /// config for every imported song, so without this the app's own write
  /// outlives the song it described, under a key that can never be addressed
  /// again. The legacy keys go too, for the same reason
  /// [clearSongViewConfig] clears them: the getters fall back to them, so a key
  /// left behind resurrects a preference that should be gone.
  Future<void> clearSongSettings(SongId songId) async {
    await clearSongViewConfig(songId);
    await _localDataSource
        .removeIntSetting(_songKey('autoscroll_speed', songId));
    final legacySpeed = _legacySongKey('autoscroll_speed', songId);
    if (legacySpeed != null) {
      await _localDataSource.removeIntSetting(legacySpeed);
    }
  }
}
