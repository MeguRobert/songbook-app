import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/view_config.dart';
import 'providers.dart';

/// State for app settings
class SettingsState {
  final double fontSize;
  final ViewConfig viewConfig;
  final int defaultTranspose;

  const SettingsState({
    this.fontSize = 18.0,
    this.viewConfig = const ViewConfig(),
    this.defaultTranspose = 0,
  });

  SettingsState copyWith({
    double? fontSize,
    ViewConfig? viewConfig,
    int? defaultTranspose,
  }) {
    return SettingsState(
      fontSize: fontSize ?? this.fontSize,
      viewConfig: viewConfig ?? this.viewConfig,
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
      fontSize: repository.getFontSize(),
      viewConfig: repository.getViewConfig(),
      defaultTranspose: repository.getDefaultTranspose(),
    );
  }

  Future<void> setFontSize(double size) async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.setFontSize(size);
    state = state.copyWith(fontSize: size);
  }

  Future<void> setViewConfig(ViewConfig config) async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.setViewConfig(config);
    state = state.copyWith(viewConfig: config);
  }

  Future<void> toggleNotation() async {
    final newConfig = state.viewConfig.copyWith(
      showNotation: !state.viewConfig.showNotation,
    );
    await setViewConfig(newConfig);
  }

  Future<void> toggleChords() async {
    final newConfig = state.viewConfig.copyWith(
      showChords: !state.viewConfig.showChords,
    );
    await setViewConfig(newConfig);
  }

  Future<void> setPreset(ViewConfig preset) async {
    await setViewConfig(preset);
  }

  Future<void> setDefaultTranspose(int semitones) async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.setDefaultTranspose(semitones);
    state = state.copyWith(defaultTranspose: semitones);
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

/// Provider for font size setting
final fontSizeProvider = Provider<double>((ref) {
  return ref.watch(settingsProvider).fontSize;
});

/// Provider for view config setting
final viewConfigProvider = Provider<ViewConfig>((ref) {
  return ref.watch(settingsProvider).viewConfig;
});
