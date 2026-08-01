import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/datasources/remote/remote_song_datasource.dart';
import 'data/datasources/remote/supabase_config.dart';
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

  // Bring up Supabase, but never let it stop the app from starting.
  //
  // The catalogue's floor is the bundled asset, so a failure here — offline,
  // a paused free-tier project, a misconfigured key — must degrade to
  // "bundled songs only" rather than a blank screen. Hence the try/catch and
  // the null datasource on failure.
  RemoteSongDataSource? remoteSongs;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    remoteSongs = RemoteSongDataSource(Supabase.instance.client);
  } catch (error, stack) {
    // Worth reporting in debug, not worth interrupting anyone's use of the app.
    debugPrint('Supabase init failed; using bundled catalogue only: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stack);
    remoteSongs = null;
  }

  // Run the app with Riverpod
  runApp(
    ProviderScope(
      overrides: [
        // Override SharedPreferences provider with initialized instance
        sharedPreferencesProvider.overrideWithValue(prefs),
        remoteSongDataSourceProvider.overrideWithValue(remoteSongs),
      ],
      child: const SongbookApp(),
    ),
  );
}
