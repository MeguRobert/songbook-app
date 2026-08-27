import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/app.dart';
import 'package:songbook_app/domain/services/crash_reporter.dart';
import 'package:songbook_app/presentation/providers/crash_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/widgets/scaffold_with_nav_bar.dart';
import 'package:songbook_app/router/app_router.dart';

import 'helpers.dart';

class _RecordingReporter extends CrashReporter {
  final List<CrashReport> received = [];

  @override
  Future<void> report(CrashReport report) async => received.add(report);
}

/// Fails the way a misconfigured table would.
class _ThrowingReporter extends CrashReporter {
  @override
  Future<void> report(CrashReport report) async =>
      throw StateError('permission denied for table error_reports');
}

/// A widget whose build throws, which is what a real one does when a null slips
/// through — the commonest thing this whole feature exists to catch.
class _BrokenScreen extends StatelessWidget {
  const _BrokenScreen();

  @override
  Widget build(BuildContext context) => throw StateError('broken on purpose');
}

void main() {
  /// Installs the handler main.dart installs, keeping the test framework's own
  /// so `takeException` still works.
  void installReporter(ThrottledCrashReporter crash) {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      unawaited(crash.record(
        details.exception,
        details.stack,
        library: details.library,
      ));
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  testWidgets('a widget that throws during build reaches the reporter',
      (tester) async {
    final sink = _RecordingReporter();
    final crash = ThrottledCrashReporter(
      sinks: [sink],
      context: CrashContext()
        ..route = '/song/91'
        ..appVersion = '1.1.0',
    );
    installReporter(crash);

    await tester.pumpWidget(localizedApp(const _BrokenScreen()));
    expect(tester.takeException(), isA<StateError>());
    await tester.pump();

    expect(sink.received, hasLength(1));
    final report = sink.received.single;
    expect(report.message, contains('broken on purpose'));
    expect(report.stack, isNotNull);
    expect(report.route, '/song/91',
        reason: 'a report that cannot say where it happened is barely a report');
    expect(report.appVersion, '1.1.0');
  });

  testWidgets('a sink that fails leaves the app exactly as it was',
      (tester) async {
    // The failure mode that would be worst: reporting turning one broken screen
    // into a broken app. The only exception the test sees must be the original.
    final crash = ThrottledCrashReporter(sinks: [_ThrowingReporter()]);
    installReporter(crash);

    await tester.pumpWidget(localizedApp(const _BrokenScreen()));
    expect(tester.takeException(), isA<StateError>());
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'the reporter must not add an exception of its own');
  });

  testWidgets('the router tells the reporter which screen the user is on',
      (tester) async {
    final context = CrashContext();

    SharedPreferences.setMockInitialValues({});
    final router = createAppRouter(onNavigate: context.noteRoute);
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider
            .overrideWithValue(await SharedPreferences.getInstance()),
        songsProvider.overrideWith((ref) async => [makeTestSong()]),
      ],
      child: localizedRouterApp(router),
    ));
    await tester.pumpAndSettle();

    expect(context.route, AppRoutes.home);

    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    expect(context.route, AppRoutes.settings,
        reason: 'the location has to follow the user, not stay at launch');
  });

  testWidgets('the app boots with no crash reporting configured at all',
      (tester) async {
    // The hard requirement this project keeps: no backend, no account, no
    // reporting — and the app still opens on the song list. Note the absence of
    // any crashContextProvider override; the default instance is what the router
    // writes into, and nothing reads it.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        songsProvider.overrideWith((ref) async => [makeTestSong()]),
      ],
      child: const SongbookApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(ScaffoldWithNavBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reporter is handed the language on screen', (tester) async {
    SharedPreferences.setMockInitialValues({'settings_locale': 'hu'});
    final prefs = await SharedPreferences.getInstance();
    final context = CrashContext();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        songsProvider.overrideWith((ref) async => [makeTestSong()]),
        crashContextProvider.overrideWithValue(context),
      ],
      child: const SongbookApp(),
    ));
    await tester.pumpAndSettle();

    expect(context.locale, 'hu',
        reason: 'a layout fault at a Hungarian string length is its own bug');
  });
}
