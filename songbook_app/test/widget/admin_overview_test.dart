import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/models/app_role.dart';
import 'package:songbook_app/data/models/app_settings.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/managed_user.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/submission.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/data/repositories/admin_repository.dart';
import 'package:songbook_app/data/repositories/submission_repository.dart';
import 'package:songbook_app/presentation/providers/admin_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/admin/admin_overview_screen.dart';
import 'package:songbook_app/router/app_router.dart';

import 'helpers.dart';

/// The administration home: what needs attention, and where to go.
///
/// The screen is three tiles and a banner, and each of the three carries a
/// count somebody acts on. What makes it worth testing is the distinction the
/// screen goes out of its way to draw: **a count that has not loaded shows an
/// em dash, never a zero**. "Nothing is waiting" and "we could not find out"
/// are different facts, and only one of them means the moderator can go home.
///
/// The closed-submissions banner is the other reason. A closed door is easy to
/// set and easy to forget, and from every other seat in the project the symptom
/// — nobody can contribute — looks exactly like a bug. So the banner has to
/// appear when and only when the door is shut, and its shortcut has to land on
/// the screen that reopens it.
///
/// Mounted on a real [GoRouter] with the real [AppRoutes] constants, so a tile
/// pointing at a path nobody registered fails here rather than on a phone.
class _MockSubmissions extends Mock implements SubmissionRepository {}

class _MockAdmin extends Mock implements AdminRepository {}

Submission pendingSubmission(String id) => Submission(
      id: id,
      status: SubmissionStatus.pending,
      submittedByName: 'Anna',
      song: Song(
        number: 1,
        title: 'Az Úrra bízom életem',
        originalKey: 'G',
        explicitId: SongId.user(id),
        verses: const [
          Verse(number: 1, lines: [LyricLine(text: 'Az Úrra bízom életem')]),
        ],
      ),
    );

ManagedUser account(String id) => ManagedUser(
      id: id,
      email: '$id@example.org',
      role: AppRole.member,
      songs: const SongTally(),
    );

Future<void> pumpOverview(
  WidgetTester tester, {
  List<Submission>? queue,
  Future<List<Submission>> Function()? fetchQueue,
  List<ManagedUser>? users,
  AppSettings settings = const AppSettings(),
  bool settle = true,
}) async {
  final submissions = _MockSubmissions();
  when(() => submissions.pendingQueue()).thenAnswer(
    (_) => fetchQueue == null
        ? Future.value(queue ?? const [])
        : fetchQueue(),
  );

  final admin = _MockAdmin();
  when(() => admin.listUsers())
      .thenAnswer((_) async => users ?? const <ManagedUser>[]);
  when(() => admin.settings()).thenAnswer((_) async => settings);

  final router = GoRouter(
    initialLocation: AppRoutes.admin,
    routes: [
      GoRoute(
        path: AppRoutes.admin,
        builder: (_, __) => const AdminOverviewScreen(),
        routes: [
          // Relative paths, so these resolve to exactly the strings in
          // AppRoutes. A tile that pushes anything else lands on go_router's
          // error page and the destination assertion fails.
          GoRoute(
            path: 'queue',
            builder: (_, __) => const Scaffold(body: Text('THE QUEUE')),
          ),
          GoRoute(
            path: 'users',
            builder: (_, __) => const Scaffold(body: Text('THE MEMBER LIST')),
          ),
          GoRoute(
            path: 'settings',
            builder: (_, __) => const Scaffold(body: Text('THE SETTINGS')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      submissionRepositoryProvider.overrideWithValue(submissions),
      adminRepositoryProvider.overrideWithValue(admin),
    ],
    child: localizedRouterApp(router),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Enough frames for the futures that DO resolve, without waiting on the
    // one that never will.
    await tester.pump();
    await tester.pump();
  }
}

Future<void> tapTile(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  group('the counts', () {
    testWidgets('report what is waiting and how many accounts there are',
        (tester) async {
      await pumpOverview(
        tester,
        queue: [pendingSubmission('s1'), pendingSubmission('s2')],
        users: [account('u1'), account('u2'), account('u3')],
      );

      expect(find.text('2 waiting for review'), findsOneWidget);
      expect(find.text('3 accounts'), findsOneWidget);
    });

    testWidgets('an empty queue is reported as none, not as unknown',
        (tester) async {
      await pumpOverview(tester, queue: const [], users: [account('u1')]);

      expect(find.text('0 waiting for review'), findsOneWidget);
    });

    testWidgets('a count still loading is an em dash rather than a zero',
        (tester) async {
      await pumpOverview(
        tester,
        fetchQueue: () => Completer<List<Submission>>().future,
        users: [account('u1')],
        settle: false,
      );

      // The distinction the whole screen turns on: a moderator acts on "nothing
      // is waiting" and does not act on "we do not know yet".
      expect(find.text('— waiting for review'), findsOneWidget);
      expect(find.text('0 waiting for review'), findsNothing);
    });

    testWidgets('a count that failed to load is an em dash too',
        (tester) async {
      await pumpOverview(
        tester,
        fetchQueue: () => Future.error(Exception('offline')),
        users: [account('u1')],
      );

      // Worse than the loading case if it got this wrong: "0 waiting" after a
      // failed fetch says the queue is clear when nobody has looked.
      expect(find.text('— waiting for review'), findsOneWidget);
      expect(find.text('0 waiting for review'), findsNothing);
    });
  });

  group('the closed-submissions banner', () {
    testWidgets('is absent while the door is open', (tester) async {
      await pumpOverview(tester);

      expect(
        find.text('Submissions are closed. Nobody can offer a song.'),
        findsNothing,
      );
    });

    testWidgets('appears when nothing new is being accepted', (tester) async {
      await pumpOverview(
        tester,
        settings: const AppSettings(submissionsOpen: false),
      );

      expect(
        find.text('Submissions are closed. Nobody can offer a song.'),
        findsOneWidget,
      );
    });

    testWidgets('its shortcut lands on the screen that reopens the door',
        (tester) async {
      await pumpOverview(
        tester,
        settings: const AppSettings(submissionsOpen: false),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Open'));
      await tester.pumpAndSettle();

      // Arriving here at all is the assertion: the shortcut pushes
      // AppRoutes.adminSettings, and only the registered '/admin/settings'
      // renders this. A drifted constant would land on the error page.
      expect(find.text('THE SETTINGS'), findsOneWidget);
    });

    testWidgets('is not claimed while the settings are still unknown',
        (tester) async {
      // `appSettingsProvider` falls back to open when it cannot read the row, so
      // the banner must not appear on a bare loading frame either — an
      // administrator would go and "reopen" a door that was never shut.
      await pumpOverview(tester, settle: false);

      expect(
        find.text('Submissions are closed. Nobody can offer a song.'),
        findsNothing,
      );
    });
  });

  group('the tiles', () {
    testWidgets('the queue tile opens the queue', (tester) async {
      await pumpOverview(tester);

      await tapTile(tester, 'Waiting for review');

      expect(find.text('THE QUEUE'), findsOneWidget);
    });

    testWidgets('the members tile opens the member list', (tester) async {
      await pumpOverview(tester);

      await tapTile(tester, 'Members');

      expect(find.text('THE MEMBER LIST'), findsOneWidget);
    });

    testWidgets('the settings tile opens the contribution settings',
        (tester) async {
      await pumpOverview(tester);

      await tapTile(tester, 'Contribution settings');

      expect(find.text('THE SETTINGS'), findsOneWidget);
    });
  });
}
