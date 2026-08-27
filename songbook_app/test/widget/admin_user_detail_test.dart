import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/models/app_role.dart';
import 'package:songbook_app/data/models/managed_user.dart';
import 'package:songbook_app/data/repositories/admin_repository.dart';
import 'package:songbook_app/presentation/providers/admin_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/admin/admin_user_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

/// One account, and the two irreversible things that can be done to it.
///
/// This is the worst screen in the app to get wrong, so the tests are weighted
/// towards refusal rather than towards the happy path:
///
/// * **Neither destructive action is offered for your own account.** The Edge
///   Function refuses both, but a button that always fails is worse than no
///   button — it invites the tap and then explains itself in a snackbar. If this
///   ever regressed, an administrator could demote themselves out of the panel
///   and lock the project.
/// * **Deleting requires typing the address.** A red button is not enough for
///   something with no undo, and the mistake to guard against is not "deleted
///   the right row by accident" but "deleted the wrong row": the confirmation
///   has to be specific to *this* account, which is why the button stays dead
///   until the exact string is typed.
/// * **A refusal from the server has to arrive in its own words.** "There has to
///   be at least one administrator" and "that did not work" send an
///   administrator to completely different places.
///
/// Mounted on a real [GoRouter] rather than a bare [MaterialApp]: `_promptDelete`
/// takes `GoRouter.of(context)` and pops off the screen once the account is gone,
/// which cannot happen — or be asserted — without one.
class _MockAdmin extends Mock implements AdminRepository {}

ManagedUser account({
  String id = 'u2',
  String? email = 'bela@example.org',
  String? displayName = 'Béla Nagy',
  AppRole role = AppRole.member,
  bool emailConfirmed = true,
  bool guidelinesAccepted = true,
  bool dormant = false,
  SongTally songs = const SongTally(approved: 4, pending: 2, rejected: 1),
}) =>
    ManagedUser(
      id: id,
      email: email,
      displayName: displayName,
      role: role,
      emailConfirmed: emailConfirmed,
      lastSignInAt: dormant ? null : DateTime(2026, 8, 20, 9, 30),
      guidelinesAcceptedAt: guidelinesAccepted ? DateTime(2026, 7, 1) : null,
      songs: songs,
    );

User signedInUser(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.utc(2026).toIso8601String(),
    );

/// The router and the repository a mounted detail screen is driven through.
typedef Harness = ({GoRouter router, AdminRepository repository});

/// Mounts the detail screen for [userId] with the member list beneath it.
///
/// [signedInAs] is the id the panel thinks it belongs to — pass the same id as
/// the row being viewed to exercise the own-account branch.
Future<Harness> pumpDetail(
  WidgetTester tester, {
  List<ManagedUser>? users,
  Future<List<ManagedUser>> Function()? fetch,
  String userId = 'u2',
  String signedInAs = 'admin-1',
  bool settle = true,
}) async {
  final repository = _MockAdmin();
  when(() => repository.listUsers()).thenAnswer(
    (_) => fetch == null ? Future.value(users ?? [account()]) : fetch(),
  );
  when(() => repository.setRole(any(), any())).thenAnswer((_) async {});
  when(() => repository.deleteUser(any())).thenAnswer((_) async {});

  final router = GoRouter(
    initialLocation: '/admin/users/$userId',
    routes: [
      GoRoute(
        path: '/admin/users',
        builder: (_, __) => const Scaffold(body: Text('THE MEMBER LIST')),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                AdminUserDetailScreen(userId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      adminRepositoryProvider.overrideWithValue(repository),
      currentUserProvider.overrideWithValue(signedInUser(signedInAs)),
    ],
    child: localizedRouterApp(router),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (router: router, repository: repository);
}

String whereWeAre(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Finder inDialog(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(text),
    );

Future<void> openRolePicker(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Change'));
  await tester.pumpAndSettle();
}

/// Scrolls [label] into view.
///
/// The detail list is taller than a phone viewport, and the delete button is the
/// very last thing on it — so it is exactly what a `ListView` has not built yet,
/// and every `find.*` skips what is not built. Without this the assertions look
/// at an empty region and report the button missing when it is there.
Future<void> reveal(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// Scrolls to the end, so that "this is not on the screen" means the whole
/// screen and not merely the part of it that happens to be built.
Future<void> scrollToTheEnd(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -600));
  await tester.pumpAndSettle();
}

/// The delete button is `OutlinedButton.icon`, whose runtime type is a private
/// subclass — `find.byType(OutlinedButton)` matches on the exact type and finds
/// nothing. Tapping the label hits the same button.
Future<void> openDelete(WidgetTester tester) async {
  await reveal(tester, 'Delete this account');
  await tester.tap(find.text('Delete this account'));
  await tester.pumpAndSettle();
}

FilledButton deleteConfirmButton(WidgetTester tester) => tester
    .widget<FilledButton>(find.widgetWithText(FilledButton, 'Delete permanently'));

void main() {
  setUpAll(() => registerFallbackValue(AppRole.member));

  group('the account as it is shown', () {
    testWidgets('carries the facts a decision is made on', (tester) async {
      await pumpDetail(tester, users: [
        account(
          displayName: 'Béla Nagy',
          email: 'bela@example.org',
          role: AppRole.moderator,
          songs: const SongTally(approved: 4, pending: 2, rejected: 1),
        ),
      ]);

      expect(find.text('Béla Nagy'), findsOneWidget);
      expect(find.text('bela@example.org'), findsOneWidget);
      expect(find.text('Moderator'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.textContaining('4 approved'), findsOneWidget);
      expect(find.textContaining('2 waiting'), findsOneWidget);
      expect(find.textContaining('1 turned down'), findsOneWidget);
    });

    testWidgets('says when the address is unconfirmed and the rules unread',
        (tester) async {
      await pumpDetail(tester, users: [
        account(emailConfirmed: false, guidelinesAccepted: false),
      ]);

      expect(find.text('Not confirmed'), findsOneWidget);
      expect(find.text('Not accepted yet'), findsOneWidget);
    });

    testWidgets('says never signed in rather than printing a null date',
        (tester) async {
      await pumpDetail(tester, users: [account(dormant: true)]);

      expect(find.text('never signed in'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('a stale link says the account is gone, not that it is loading',
        (tester) async {
      // Reached after deleting this very row, or from a bookmark.
      await pumpDetail(tester, users: [account(id: 'u2')], userId: 'nobody');

      expect(find.text('This account no longer exists.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('is a spinner while the list loads', (tester) async {
      await pumpDetail(
        tester,
        fetch: () => Completer<List<ManagedUser>>().future,
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('This account no longer exists.'), findsNothing);
    });

    testWidgets('a failed load says so rather than claiming the account is gone',
        (tester) async {
      await pumpDetail(tester, fetch: () => Future.error(Exception('403')));

      // "Could not load" and "does not exist" are opposite instructions.
      expect(find.text('The member list could not be loaded.'), findsOneWidget);
      expect(find.text('This account no longer exists.'), findsNothing);
    });
  });

  group('your own account', () {
    testWidgets('offers no role change and no delete', (tester) async {
      await pumpDetail(
        tester,
        users: [account(id: 'me', displayName: 'Csaba Tóth')],
        userId: 'me',
        signedInAs: 'me',
      );
      await scrollToTheEnd(tester);

      // Not merely disabled — absent. A button that the server will always
      // refuse invites the tap and then apologises.
      expect(find.widgetWithText(TextButton, 'Change'), findsNothing);
      expect(find.text('Delete this account'), findsNothing);
      expect(
        find.text('You cannot change your own role or delete your own account.'),
        findsOneWidget,
      );
    });

    testWidgets('somebody else on the same screen keeps both actions',
        (tester) async {
      await pumpDetail(
        tester,
        users: [account(id: 'u2')],
        userId: 'u2',
        signedInAs: 'me',
      );
      await reveal(tester, 'Delete this account');

      expect(find.widgetWithText(TextButton, 'Change'), findsOneWidget);
      expect(find.text('Delete this account'), findsOneWidget);
    });
  });

  group('changing the role', () {
    testWidgets('the role picked is the role sent', (tester) async {
      final harness =
          await pumpDetail(tester, users: [account(role: AppRole.member)]);
      await openRolePicker(tester);

      await tester.tap(inDialog('Administrator'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      verify(() => harness.repository.setRole('u2', AppRole.administrator))
          .called(1);
    });

    testWidgets('picking the role they already have sends nothing',
        (tester) async {
      final harness =
          await pumpDetail(tester, users: [account(role: AppRole.moderator)]);
      await openRolePicker(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // A no-op write is not harmless here: it is an audited privilege change.
      verifyNever(() => harness.repository.setRole(any(), any()));
    });

    testWidgets('cancelling changes nothing', (tester) async {
      final harness =
          await pumpDetail(tester, users: [account(role: AppRole.member)]);
      await openRolePicker(tester);

      await tester.tap(inDialog('Administrator'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => harness.repository.setRole(any(), any()));
    });

    testWidgets('a refusal is reported in the words of the rule it broke',
        (tester) async {
      final harness = await pumpDetail(
          tester, users: [account(role: AppRole.administrator)]);
      when(() => harness.repository.setRole(any(), any())).thenThrow(
          const AdminFailure(AdminFailureCode.lastAdministrator));

      await openRolePicker(tester);
      await tester.tap(inDialog('Member'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // Not "that did not work" — this one tells the administrator what to do
      // instead, which is promote somebody first.
      expect(find.text('There has to be at least one administrator.'),
          findsOneWidget);
    });

    testWidgets('an unrecognised failure still says something', (tester) async {
      final harness = await pumpDetail(tester, users: [account()]);
      when(() => harness.repository.setRole(any(), any()))
          .thenThrow(Exception('boom'));

      await openRolePicker(tester);
      await tester.tap(inDialog('Moderator'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('That did not work.'), findsOneWidget);
    });
  });

  group('deleting the account', () {
    testWidgets('spells out what survives and what does not', (tester) async {
      await pumpDetail(tester, users: [account()]);
      await openDelete(tester);

      expect(find.text('This cannot be undone.'), findsOneWidget);
      // Somebody deleting a spammer wants the songs gone; somebody removing a
      // member who moved away needs to know the hymns stay.
      expect(
        find.textContaining('Songs already approved stay in the songbook'),
        findsOneWidget,
      );
    });

    testWidgets('the button is dead until the address is typed exactly',
        (tester) async {
      final harness =
          await pumpDetail(tester, users: [account(email: 'bela@example.org')]);
      await openDelete(tester);

      expect(find.text('Type bela@example.org to confirm.'), findsOneWidget);
      expect(deleteConfirmButton(tester).onPressed, isNull);

      // Close, but not this account. This is the mistake worth guarding: not
      // deleting the right row by accident, but deleting the wrong one.
      await tester.enterText(find.byType(TextField), 'bela@example.com');
      await tester.pumpAndSettle();
      expect(deleteConfirmButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'bela@example.org');
      await tester.pumpAndSettle();
      expect(deleteConfirmButton(tester).onPressed, isNotNull);

      verifyNever(() => harness.repository.deleteUser(any()));
    });

    testWidgets('surrounding whitespace still counts as the address',
        (tester) async {
      await pumpDetail(tester, users: [account(email: 'bela@example.org')]);
      await openDelete(tester);

      await tester.enterText(find.byType(TextField), '  bela@example.org  ');
      await tester.pumpAndSettle();

      expect(deleteConfirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('with no address on file, the id is what must be typed',
        (tester) async {
      await pumpDetail(
        tester,
        users: [account(id: 'u2', email: null, displayName: 'Béla Nagy')],
      );
      await openDelete(tester);

      // Never a blank confirmation box that anything satisfies.
      expect(find.text('Type u2 to confirm.'), findsOneWidget);
      expect(deleteConfirmButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'u2');
      await tester.pumpAndSettle();
      expect(deleteConfirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('confirming deletes this account and leaves the screen',
        (tester) async {
      final harness =
          await pumpDetail(tester, users: [account(id: 'u2')], userId: 'u2');
      await openDelete(tester);

      await tester.enterText(find.byType(TextField), 'bela@example.org');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
      await tester.pumpAndSettle();

      verify(() => harness.repository.deleteUser('u2')).called(1);
      // Off a detail screen for an account that no longer exists.
      expect(whereWeAre(harness.router), '/admin/users');
    });

    testWidgets('cancelling deletes nobody and stays put', (tester) async {
      final harness = await pumpDetail(tester, users: [account(id: 'u2')]);
      await openDelete(tester);

      await tester.enterText(find.byType(TextField), 'bela@example.org');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => harness.repository.deleteUser(any()));
      expect(whereWeAre(harness.router), '/admin/users/u2');
    });

    /// `_promptDelete` used to dispose its `TextEditingController` on the line
    /// after `await showDialog(...)` returned, while the exit transition was
    /// still rebuilding the `TextField`. Every dismissal threw
    /// `A TextEditingController was used after being disposed.` in a debug
    /// build, and left a listener on a disposed `ChangeNotifier` in a release
    /// one. `_DeleteDialog` owns it now; this pumps the transition out to prove
    /// it. Full write-up on the matching test in `moderation_queue_test.dart`.
    testWidgets('the delete dialog can be dismissed without a framework error',
        (tester) async {
      await pumpDetail(tester, users: [account()]);
      await openDelete(tester);

      await tester.enterText(find.byType(TextField), 'bela@example.org');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
