import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'providers.dart';

/// Notifier for theme management
class ThemeNotifier extends StateNotifier<AppThemeMode> {
  final Ref _ref;

  ThemeNotifier(this._ref) : super(AppThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() {
    final repository = _ref.read(settingsRepositoryProvider);
    state = repository.getThemeMode();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final repository = _ref.read(settingsRepositoryProvider);
    await repository.setThemeMode(mode);
    state = mode;
  }

  Future<void> toggleTheme() async {
    final newMode = switch (state) {
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.system,
      AppThemeMode.system => AppThemeMode.light,
    };
    await setThemeMode(newMode);
  }
}

/// Provider for theme mode
final themeModeProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier(ref);
});

/// Provider for Flutter ThemeMode
final flutterThemeModeProvider = Provider<ThemeMode>((ref) {
  final appThemeMode = ref.watch(themeModeProvider);
  return switch (appThemeMode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
});
