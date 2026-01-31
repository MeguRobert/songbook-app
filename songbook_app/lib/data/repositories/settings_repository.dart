import '../../core/theme/app_theme.dart';
import '../datasources/local/local_datasource.dart';

/// Keys for settings storage
class SettingsKeys {
  static const themeMode = 'theme_mode';
  static const defaultTranspose = 'default_transpose';
  static const showChords = 'show_chords';
  static const fontSize = 'font_size';
  static const viewMode = 'view_mode'; // 'chords' or 'sheet'
}

/// View mode for song display
enum SongViewMode {
  chords,
  sheet,
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

  // --- View Mode ---

  SongViewMode getViewMode() {
    final value = _localDataSource.getStringSetting(SettingsKeys.viewMode);
    return SongViewMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => SongViewMode.chords,
    );
  }

  Future<bool> setViewMode(SongViewMode mode) {
    return _localDataSource.setStringSetting(SettingsKeys.viewMode, mode.name);
  }
}
