import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/datasources/remote/remote_song_datasource.dart';
import 'data/datasources/remote/remote_sync_datasource.dart';
import 'data/datasources/remote/supabase_config.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/submission_repository.dart';
import 'presentation/providers/admin_provider.dart';
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
  RemoteSyncDataSource? remoteSync;
  AuthRepository? auth;
  SubmissionRepository? submissions;
  AdminRepository? admin;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    remoteSongs = RemoteSongDataSource(Supabase.instance.client);

    // THE CROSS-DEVICE SYNC FLAG, and the only place it is read.
    //
    // Off by default, so this build behaves exactly as the one before it: with
    // a null datasource, FavoritesRepository and SetlistRepository take the
    // local-only path they have always taken. Turn it on for a build with
    //   --dart-define=CROSS_DEVICE_SYNC=true
    // and see docs/plans/2026-08-27-cross-device-sync-design.md for what
    // changes on the day it goes on.
    remoteSync = SupabaseConfig.crossDeviceSyncEnabled
        ? RemoteSyncDataSource(Supabase.instance.client)
        : null;

    auth = AuthRepository(Supabase.instance.client.auth);
    submissions = SubmissionRepository(Supabase.instance.client);
    admin = AdminRepository(Supabase.instance.client);
  } catch (error, stack) {
    // Worth reporting in debug, not worth interrupting anyone's use of the app.
    debugPrint('Supabase init failed; using bundled catalogue only: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stack);
    remoteSongs = null;
    remoteSync = null;
    auth = null;
    submissions = null;
    admin = null;
  }

  // Run the app with Riverpod
  runApp(
    ProviderScope(
      overrides: [
        // Override SharedPreferences provider with initialized instance
        sharedPreferencesProvider.overrideWithValue(prefs),
        remoteSongDataSourceProvider.overrideWithValue(remoteSongs),
        remoteSyncDataSourceProvider.overrideWithValue(remoteSync),
        authRepositoryProvider.overrideWithValue(auth),
        submissionRepositoryProvider.overrideWithValue(submissions),
        adminRepositoryProvider.overrideWithValue(admin),
      ],
      child: const SongbookApp(),
    ),
  );
}

