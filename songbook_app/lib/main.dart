import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'presentation/providers/providers.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Hand selection gestures to Flutter instead of the browser.
  //
  // On web the browser's own context menu wins by default, so Flutter's
  // selection toolbar — the one carrying Copy — never appeared: you could
  // select the words of a song and then had no way to copy them. The browser
  // menu is no substitute, because the app paints to a canvas and there is no
  // DOM text under the cursor for it to offer.
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  // Run the app with Riverpod
  runApp(
    ProviderScope(
      overrides: [
        // Override SharedPreferences provider with initialized instance
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SongbookApp(),
    ),
  );
}
