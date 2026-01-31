import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/theme_provider.dart';
import 'router/app_router.dart';

/// Main application widget
class SongbookApp extends ConsumerWidget {
  const SongbookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(flutterThemeModeProvider);

    return MaterialApp.router(
      title: 'Songbook',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: createLightTheme(),
      darkTheme: createDarkTheme(),
      themeMode: themeMode,

      // Router configuration
      routerConfig: router,
    );
  }
}
