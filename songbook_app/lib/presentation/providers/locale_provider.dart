import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'providers.dart';

/// The interface language the user chose, or null to follow the device.
///
/// Stored as the language code (`hu`, `ro`, `en`) or absent for "follow the
/// device". A nullable override rather than a third enum value, because "follow
/// the device" is the *absence* of a choice: encoding it as a value would mean
/// deciding what happens when the device is set to a language the app does not
/// have, and Flutter already answers that.
class LocaleNotifier extends StateNotifier<Locale?> {
  static const settingsKey = 'locale';

  final Ref _ref;

  LocaleNotifier(this._ref) : super(null) {
    final stored =
        _ref.read(localDataSourceProvider).getStringSetting(settingsKey);
    if (stored != null && stored.isNotEmpty) {
      state = _supported(stored);
    }
  }

  /// [code] as a Locale, or null if this build does not support it — a language
  /// removed from the ARB set must not leave the app stuck in it.
  static Locale? _supported(String code) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == code) return locale;
    }
    return null;
  }

  /// Sets the interface language, or passes null to follow the device again.
  Future<void> setLocale(Locale? locale) async {
    final source = _ref.read(localDataSourceProvider);
    if (locale == null) {
      await source.removeStringSetting(settingsKey);
    } else {
      await source.setStringSetting(settingsKey, locale.languageCode);
    }
    state = locale;
  }
}

/// The chosen interface language, or null for "follow the device".
///
/// Handed straight to `MaterialApp.locale`, where null means exactly that.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier(ref);
});
