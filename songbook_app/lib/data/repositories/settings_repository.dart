import '../../core/theme/app_theme.dart';
import '../datasources/local/local_datasource.dart';
import '../models/view_config.dart';

/// Keys for settings storage
class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const defaultTranspose = 'default_transpose';
  static const showChords = 'show_chords';
  static const fontSize = 'font_size';
  static const viewConfig = 'view_config';
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

  // --- Transpose ---

  int getDefaultTranspose() {
    return _localDataSource.getIntSetting(SettingsKeys.defaultTranspose) ?? 0;
  }

  Future<bool> setDefaultTranspose(int semitones) {
    return _localDataSource.setIntSetting(
      SettingsKeys.defaultTranspose,
      semitones,
    );
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

  ViewConfig? getSongViewConfig(int songNumber) {
    final key = 'song_view_config_$songNumber';
    final value = _localDataSource.getStringSetting(key);
    if (value == null) return null;
    return ViewConfig.fromStorageString(value);
  }

  Future<bool> setSongViewConfig(int songNumber, ViewConfig config) {
    final key = 'song_view_config_$songNumber';
    return _localDataSource.setStringSetting(key, config.toStorageString());
  }

  Future<bool> clearSongViewConfig(int songNumber) {
    final key = 'song_view_config_$songNumber';
    return _localDataSource.removeStringSetting(key);
  }
}
