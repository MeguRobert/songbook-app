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

  SettingsRepository(this._localDataSource);

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
