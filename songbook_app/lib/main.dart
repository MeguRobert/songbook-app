import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/datasources/remote/remote_song_datasource.dart';
import 'data/datasources/remote/supabase_config.dart';
import 'data/datasources/remote/supabase_crash_reporter.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/submission_repository.dart';
import 'domain/services/crash_reporter.dart';
import 'presentation/providers/admin_provider.dart';
import 'presentation/providers/crash_provider.dart';
import 'presentation/providers/providers.dart';

void main() {
  // The reporter is built first, before anything at all can fail.
  //
  // It starts with the console sink alone, which is the sink that needs no
  // backend, no network and no configuration. The Supabase sink is appended
  // later and only if `Supabase.initialize` succeeded — so a build with no
  // backend, a paused free-tier project, or a phone with no signal still
  // reports, just to a place only the person holding the phone can see. That
  // is the same "degrade, never fail to start" rule the catalogue follows.
  final crash = ThrottledCrashReporter(sinks: const [ConsoleCrashReporter()]);
  crash.context.platform = describePlatform();

  // Everything runs inside the guarded zone, `ensureInitialized` included.
  //
  // Flutter requires the binding to be initialised in the SAME zone as
  // `runApp`; splitting them produces the "Zone mismatch" assertion at startup.
  // So main's whole body moved in here rather than the `runApp` call alone.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Errors Flutter catches itself: a build, layout or paint that threw.
      // `presentError` first, so the red screen and the console output are
      // exactly what they were before this existed — the report is added to
      // the existing behaviour, it does not replace it.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(crash.record(
          details.exception,
          details.stack,
          library: details.library,
        ));
      };

      // Errors from the engine side that no Dart frame is left to catch —
      // a failed platform-channel reply, a callback from a gesture that has
      // already been torn down. Returning true means "handled", which stops
      // the default behaviour of killing the isolate.
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(crash.record(error, stack));
        return true;
      };

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

      // Which build this is. Wrapped because on web this reads `version.json`
      // over the network, and a report from an unknown version still beats no
      // report at all.
      try {
        final info = await PackageInfo.fromPlatform();
        crash.context.appVersion = info.version;
        crash.context.buildNumber = info.buildNumber;
      } catch (error, stack) {
        debugPrint('Could not read the package version: $error');
        if (kDebugMode) debugPrintStack(stackTrace: stack);
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
      AuthRepository? auth;
      SubmissionRepository? submissions;
      AdminRepository? admin;
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.publishableKey,
        );
        remoteSongs = RemoteSongDataSource(Supabase.instance.client);
        auth = AuthRepository(Supabase.instance.client.auth);
        submissions = SubmissionRepository(Supabase.instance.client);
        admin = AdminRepository(Supabase.instance.client);

        // Now, and only now, crashes can reach somebody who is not holding
        // the phone.
        crash.addSink(SupabaseCrashReporter(Supabase.instance.client));
      } catch (error, stack) {
        // Worth reporting in debug, not worth interrupting anyone's use of the app.
        debugPrint('Supabase init failed; using bundled catalogue only: $error');
        if (kDebugMode) debugPrintStack(stackTrace: stack);
        remoteSongs = null;
        auth = null;
        submissions = null;
        admin = null;

        // Deliberately NOT reported through `crash`: the only sink that could
        // carry it is the one that just failed to exist, and the console sink
        // would print what the line above already printed.
      }

      // Run the app with Riverpod
      runApp(
        ProviderScope(
          overrides: [
            // Override SharedPreferences provider with initialized instance
            sharedPreferencesProvider.overrideWithValue(prefs),
            remoteSongDataSourceProvider.overrideWithValue(remoteSongs),
            authRepositoryProvider.overrideWithValue(auth),
            submissionRepositoryProvider.overrideWithValue(submissions),
            adminRepositoryProvider.overrideWithValue(admin),
            // The router writes the current location into this, and the reporter
            // reads it. Same object on both sides, so a report names the screen.
            crashContextProvider.overrideWithValue(crash.context),
          ],
          child: const SongbookApp(),
        ),
      );
    },
    // Anything asynchronous that nothing else caught — a Future that failed
    // with no `catchError`, a timer callback that threw. This is the last net,
    // and before it existed such an error reached the console of a browser
    // nobody was looking at.
    (error, stack) => unawaited(crash.record(error, stack)),
  );
}
