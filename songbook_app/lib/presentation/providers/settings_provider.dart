import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';
import 'providers.dart';

/// State for app settings
class SettingsState {
  final bool showChords;
  final double fontSize;
  final SongViewMode viewMode;
  final int defaultTranspose;

  const SettingsState({
    this.showChords = true,
    this.fontSize = 18.0,
    this.viewMode = SongViewMode.chords,
    this.defaultTranspose = 0,
  });

  SettingsState copyWith({
    bool? showChords,
    double? fontSize,
    SongViewMode? viewMode,
    int? defaultTranspose,
  }) {
    return SettingsState(
      showChords: showChords ?? this.showChords,
      fontSize: fontSize ?? this.fontSize,
      viewMode: viewMode ?? this.viewMode,
      defaultTranspose: defaultTranspose ?? this.defaultTranspose,
    );
  }
}

/// Notifier for app settings
class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final repository = _ref.read(settingsRepositoryProvider);
    state = SettingsState(
      showChords: repository.getShowChords(),
      fontSize: repository.getFontSize(),
      viewMode: repository.getViewMode(),
      defaultTranspose: repository.getDefaultTranspose(),
    );
  }

  Future<void> setShowChords(bool show) async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.setShowChords(show);
    state = state.copyWith(showChords: show);
  }

  Future<void> setFontSize(double size) async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.setFontSize(size);
    state = state.copyWith(fontSize: size);
  }

  Future<void> setViewMode(SongViewMode mode) async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.setViewMode(mode);
    state = state.copyWith(viewMode: mode);
  }

  Future<void> setDefaultTranspose(int semitones) async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.setDefaultTranspose(semitones);
    state = state.copyWith(defaultTranspose: semitones);
  }

  Future<void> toggleViewMode() async {
    final newMode = state.viewMode == SongViewMode.chords
        ? SongViewMode.sheet
        : SongViewMode.chords;
    await setViewMode(newMode);
  }

  void increaseFontSize() {
    if (state.fontSize < 32) {
      setFontSize(state.fontSize + 2);
    }
  }

  void decreaseFontSize() {
    if (state.fontSize > 12) {
      setFontSize(state.fontSize - 2);
    }
  }
}

/// Provider for settings state
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

/// Provider for show chords setting
final showChordsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).showChords;
});

/// Provider for font size setting
final fontSizeProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).fontSize;
});

/// Provider for view mode setting
final viewModeProvider = Provider<SongViewMode>((ref) {
  return ref.watch(settingsProvider).viewMode;
});
