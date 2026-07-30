import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/locale_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'router/app_router.dart';

/// Main application widget
class SongbookApp extends ConsumerWidget {
  const SongbookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(flutterThemeModeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: createLightTheme(),
      darkTheme: createDarkTheme(),
      themeMode: themeMode,

      // Hungarian, Romanian and English. `locale` is null unless the user picked
      // one, which is how MaterialApp is told to follow the device — and Flutter
      // falls back to the template language for a device set to anything else.
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,

      // Router configuration
      routerConfig: router,
    );
  }
}
