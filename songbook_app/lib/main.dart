import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/datasources/remote/remote_song_datasource.dart';
import 'data/datasources/remote/supabase_config.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/submission_repository.dart';
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
  AuthRepository? auth;
  SubmissionRepository? submissions;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    remoteSongs = RemoteSongDataSource(Supabase.instance.client);
    auth = AuthRepository(Supabase.instance.client.auth);
    submissions = SubmissionRepository(Supabase.instance.client);
  } catch (error, stack) {
    // Worth reporting in debug, not worth interrupting anyone's use of the app.
    debugPrint('Supabase init failed; using bundled catalogue only: $error');
    if (kDebugMode) debugPrintStack(stackTrace: stack);
    remoteSongs = null;
    auth = null;
    submissions = null;
  }

  // One-time setup by link: ?photoEndpoint=... configures photo import.
  //
  // The setting lives in the browser's own storage, so it cannot be set for a
  // device from anywhere else — and typing a URL like
  // http://192.168.0.102:8790/extract on a phone keyboard is both tedious and
  // easy to get subtly wrong. Opening one link instead does it exactly.
  //
  // Read before runApp so the app never starts in the unconfigured state and
  // then flips. The parameter must sit BEFORE the fragment
  // (`http://host/?photoEndpoint=...#/`) because routing is hash-based and
  // Uri.base does not see query parameters that follow a `#`.
  await _applySetupLink(prefs);

  // Run the app with Riverpod
  runApp(
    ProviderScope(
      overrides: [
        // Override SharedPreferences provider with initialized instance
        sharedPreferencesProvider.overrideWithValue(prefs),
        remoteSongDataSourceProvider.overrideWithValue(remoteSongs),
        authRepositoryProvider.overrideWithValue(auth),
        submissionRepositoryProvider.overrideWithValue(submissions),
      ],
      child: const SongbookApp(),
    ),
  );
}

/// Applies `?photoEndpoint=` from the launch URL, if present.
///
/// Validated the same way [SettingsRepository] validates it, so a mistyped link
/// is ignored rather than stored as a value that silently reads back as "not
/// configured". Silent on success: this runs before any UI exists.
///
/// **Only somewhere on your own network.** This exists for one reason — typing
/// `http://192.168.0.102:8790/extract` on a phone keyboard is tedious and easy
/// to get subtly wrong — and that reason is entirely served by private
/// addresses. Accepting any host meant a link to the real app silently and
/// permanently pointed photo uploads at whatever the link said, which is not a
/// setup convenience but a way to be handed somebody's photographs. A public
/// service is typed into Settings, where it is visible and deliberate.
Future<void> _applySetupLink(SharedPreferences prefs) async {
  if (!kIsWeb) return;
  final raw = Uri.base.queryParameters['photoEndpoint']?.trim();
  if (raw == null || raw.isEmpty) return;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return;
  if (uri.scheme != 'http' && uri.scheme != 'https') return;
  if (!_isLocalHost(uri.host)) return;
  // The same key SettingsRepository reads, via the same settings_ prefix
  // LocalDataSource applies.
  await prefs.setString('settings_photo_import_endpoint', uri.toString());
}

/// Whether [host] is this machine or the network it is on.
///
/// The private ranges plus loopback, matched on the literal address: a *name*
/// is not checked, because a name anybody can register can resolve wherever
/// they like, and resolving it here would be trusting DNS with the answer.
bool _isLocalHost(String host) {
  final lower = host.toLowerCase();
  if (lower == 'localhost' || lower == '::1' || lower == '[::1]') return true;
  final octets = lower.split('.');
  if (octets.length != 4) return false;
  final numbers = [for (final o in octets) int.tryParse(o)];
  if (numbers.any((n) => n == null || n < 0 || n > 255)) return false;
  final [first, second, ...] = numbers.cast<int>();
  if (first == 127 || first == 10) return true;
  if (first == 192 && second == 168) return true;
  if (first == 172 && second >= 16 && second <= 31) return true;
  return false;
}
