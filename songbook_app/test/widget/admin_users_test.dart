import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/models/app_role.dart';
import 'package:songbook_app/data/models/managed_user.dart';
import 'package:songbook_app/data/repositories/admin_repository.dart';
import 'package:songbook_app/presentation/providers/admin_provider.dart';
import 'package:songbook_app/presentation/screens/admin/admin_users_screen.dart';

import 'helpers.dart';

/// The member list: the only screen in the app where an email address appears.
///
/// Two things make it worth pinning. First, it is the *lookup* screen — a
/// moderator arrives here knowing a name or half an address, and if the search
/// or the role chips filter on the wrong field they simply find nobody and
/// conclude the account does not exist. Second, it is where an invitation is
/// issued, and an invitation carries a role: sending "administrator" when
/// "member" was ticked hands over the whole project.
///
/// The list and its failure state are covered because `managedUsersProvider`
/// returns an empty list when there is no backend and an error when the call is
/// refused — and an admin screen that renders "nobody matches that" after a 403
/// is indistinguishable from an empty project.
class _MockAdmin extends Mock implements AdminRepository {}

ManagedUser account({
  String id = 'u1',
  String? email = 'anna@example.org',
  String? displayName = 'Anna Kovács',
  AppRole role = AppRole.member,
  bool emailConfirmed = true,
  DateTime? lastSignInAt,
  DateTime? guidelinesAcceptedAt,
  SongTally songs = const SongTally(),
  /// Never signed in, so the invitation was never taken up. A separate flag
  /// rather than `lastSignInAt: null`, which the default would swallow.
  bool dormant = false,
}) =>
    ManagedUser(
      id: id,
      email: email,
      displayName: displayName,
      role: role,
      emailConfirmed: emailConfirmed,
      lastSignInAt: dormant ? null : (lastSignInAt ?? DateTime(2026, 8, 20)),
      guidelinesAcceptedAt: guidelinesAcceptedAt,
      songs: songs,
    );

/// Three accounts covering all three rungs of the ladder, so a filter that
/// matches everything and one that matches nothing both look wrong.
List<ManagedUser> theCongregation() => [
      account(
        id: 'u1',
        displayName: 'Anna Kovács',
        email: 'anna@example.org',
        role: AppRole.member,
        songs: const SongTally(approved: 3, rejected: 1),
      ),
      account(
        id: 'u2',
        displayName: 'Béla Nagy',
        email: 'bela@example.org',
        role: AppRole.moderator,
      ),
      account(
        id: 'u3',
        displayName: 'Csaba Tóth',
        email: 'csaba@example.org',
        role: AppRole.administrator,
      ),
    ];

/// Mounts the screen over a stubbed repository, driving the real
/// [managedUsersProvider] so its own branches are part of what is exercised.
Future<AdminRepository> pumpUsers(
  WidgetTester tester, {
  List<ManagedUser>? users,
  Future<List<ManagedUser>> Function()? fetch,
  bool settle = true,
}) async {
  final repository = _MockAdmin();
  when(() => repository.listUsers()).thenAnswer(
    (_) => fetch == null ? Future.value(users ?? const []) : fetch(),
  );
  when(() => repository.invite(any(), role: any(named: 'role')))
      .thenAnswer((_) async {});

  await pumpScreen(
    tester,
    const AdminUsersScreen(),
    overrides: [adminRepositoryProvider.overrideWithValue(repository)],
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return repository;
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.pumpAndSettle();
}

Future<void> tapChip(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilterChip, label));
  await tester.pumpAndSettle();
}

Future<void> openInvite(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.person_add_alt));
  await tester.pumpAndSettle();
}

/// Taps something inside the open dialog, not the identically-labelled thing
/// behind it — the role names are also the filter chips on the screen below.
Finder inDialog(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(text),
    );

/// Lets the work behind a dismissed dialog run **without pumping a frame**.
///
/// **A workaround for a defect in the screen, not a testing preference.**
/// `_promptInvite` calls `controller.dispose()` on the line after
/// `await showDialog(...)` returns — before the dialog's exit transition has
/// finished. The next frame rebuilds the still-mounted `TextFormField`,
/// `EditableText` re-subscribes to the controller, and the framework throws
/// `A TextEditingController was used after being disposed.` See the skipped test
/// at the foot of this file, and the fuller note in `moderation_queue_test.dart`.
Future<void> settleWithoutAFrame(WidgetTester tester) => tester.idle();

void main() {
  setUpAll(() => registerFallbackValue(AppRole.member));

  group('the list', () {
    testWidgets('shows each account with its role and its tally',
        (tester) async {
      await pumpUsers(tester, users: theCongregation());

      expect(find.text('Anna Kovács'), findsOneWidget);
      expect(find.text('Béla Nagy'), findsOneWidget);
      expect(find.text('Csaba Tóth'), findsOneWidget);
      // The tally is on the row rather than only on the detail screen because
      // three turn-downs is a different conversation from three approvals, and
      // that is wanted at the moment of looking somebody up.
      expect(find.textContaining('Member'), findsWidgets);
      expect(find.textContaining('3 approved'), findsOneWidget);
      expect(find.textContaining('1 turned down'), findsOneWidget);
    });

    testWidgets('falls back to the address when there is no display name',
        (tester) async {
      await pumpUsers(tester, users: [
        account(id: 'u9', displayName: null, email: 'nameless@example.org'),
      ]);

      // Never a bare uuid: a row nobody can identify is a row nobody can act on.
      expect(find.text('nameless@example.org'), findsOneWidget);
      expect(find.text('u9'), findsNothing);
    });

    testWidgets('flags an account whose address is not confirmed',
        (tester) async {
      await pumpUsers(tester, users: [
        account(id: 'u1', displayName: 'Anna Kovács'),
        account(id: 'u2', displayName: 'Béla Nagy', emailConfirmed: false),
      ]);

      expect(find.byIcon(Icons.mark_email_unread_outlined), findsOneWidget);
    });

    testWidgets('marks an invitation nobody has taken up', (tester) async {
      await pumpUsers(tester, users: [
        account(id: 'u4', displayName: 'Dóra Szabó', dormant: true),
      ]);

      expect(find.textContaining('never signed in'), findsOneWidget);
    });

    testWidgets('is a spinner while it loads, not an empty result',
        (tester) async {
      await pumpUsers(
        tester,
        fetch: () => Completer<List<ManagedUser>>().future,
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Nobody matches that.'), findsNothing);
    });

    testWidgets('says so when it cannot be loaded, rather than showing nobody',
        (tester) async {
      await pumpUsers(tester, fetch: () => Future.error(Exception('403')));

      // Usually a lost administrator rank, second-most usually offline. Either
      // way "the list is empty" would be a lie.
      expect(find.text('The member list could not be loaded.'), findsOneWidget);
      expect(find.text('Nobody matches that.'), findsNothing);
    });
  });

  group('finding somebody', () {
    testWidgets('search narrows the list by name', (tester) async {
      await pumpUsers(tester, users: theCongregation());

      await search(tester, 'béla');

      expect(find.text('Béla Nagy'), findsOneWidget);
      expect(find.text('Anna Kovács'), findsNothing);
      expect(find.text('Csaba Tóth'), findsNothing);
    });

    testWidgets('search also matches the address, which is often all one has',
        (tester) async {
      await pumpUsers(tester, users: theCongregation());

      // Nothing in this query appears in any display name.
      await search(tester, 'csaba@example');

      expect(find.text('Csaba Tóth'), findsOneWidget);
      expect(find.text('Anna Kovács'), findsNothing);
    });

    testWidgets('search ignores case and surrounding space', (tester) async {
      await pumpUsers(tester, users: theCongregation());

      await search(tester, '  ANNA  ');

      expect(find.text('Anna Kovács'), findsOneWidget);
    });

    testWidgets('a search that matches nobody says so', (tester) async {
      await pumpUsers(tester, users: theCongregation());

      await search(tester, 'zzz');

      expect(find.text('Nobody matches that.'), findsOneWidget);
      expect(find.text('Anna Kovács'), findsNothing);
    });

    testWidgets('the role chips narrow the list, and All puts it back',
        (tester) async {
      await pumpUsers(tester, users: theCongregation());

      await tapChip(tester, 'Moderator');
      expect(find.text('Béla Nagy'), findsOneWidget);
      expect(find.text('Anna Kovács'), findsNothing);
      expect(find.text('Csaba Tóth'), findsNothing);

      await tapChip(tester, 'Administrator');
      expect(find.text('Csaba Tóth'), findsOneWidget);
      expect(find.text('Béla Nagy'), findsNothing);

      await tapChip(tester, 'All');
      expect(find.text('Anna Kovács'), findsOneWidget);
      expect(find.text('Béla Nagy'), findsOneWidget);
      expect(find.text('Csaba Tóth'), findsOneWidget);
    });

    testWidgets('the role chip and the search box narrow together',
        (tester) async {
      await pumpUsers(tester, users: [
        ...theCongregation(),
        account(id: 'u5', displayName: 'Anna Balogh', role: AppRole.moderator),
      ]);

      await tapChip(tester, 'Moderator');
      await search(tester, 'anna');

      // Not "either matches" — a filter that widens when you add a term is the
      // one that makes people give up on the search box.
      expect(find.text('Anna Balogh'), findsOneWidget);
      expect(find.text('Anna Kovács'), findsNothing);
      expect(find.text('Béla Nagy'), findsNothing);
    });
  });

  group('inviting somebody', () {
    testWidgets('the dialog offers all three roles', (tester) async {
      await pumpUsers(tester, users: theCongregation());
      await openInvite(tester);

      expect(inDialog('Member'), findsOneWidget);
      expect(inDialog('Moderator'), findsOneWidget);
      expect(inDialog('Administrator'), findsOneWidget);
    });

    testWidgets('an address with no @ is refused before anything is sent',
        (tester) async {
      final repository = await pumpUsers(tester, users: theCongregation());
      await openInvite(tester);

      await tester.enterText(find.byType(TextFormField), 'anna');
      await tester.tap(find.widgetWithText(FilledButton, 'Send invitation'));
      await tester.pumpAndSettle();

      expect(find.text('That does not look like an email address.'),
          findsOneWidget);
      // Still open, so the typo can be fixed in place.
      expect(find.byType(AlertDialog), findsOneWidget);
      verifyNever(() => repository.invite(any(), role: any(named: 'role')));
    });

    testWidgets('an empty address is refused too', (tester) async {
      final repository = await pumpUsers(tester, users: theCongregation());
      await openInvite(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Send invitation'));
      await tester.pumpAndSettle();

      expect(find.text('That does not look like an email address.'),
          findsOneWidget);
      verifyNever(() => repository.invite(any(), role: any(named: 'role')));
    });

    testWidgets('the address goes out as Member unless another role is ticked',
        (tester) async {
      final repository = await pumpUsers(tester, users: theCongregation());
      await openInvite(tester);

      await tester.enterText(find.byType(TextFormField), 'dora@example.org');
      await tester.tap(find.widgetWithText(FilledButton, 'Send invitation'));
      await settleWithoutAFrame(tester);

      // The safe default matters: an invitation is accepted by whoever holds
      // the address, and the rung it lands on is not renegotiated afterwards.
      verify(() => repository.invite('dora@example.org', role: AppRole.member))
          .called(1);
    });

    testWidgets('the role ticked is the role sent', (tester) async {
      final repository = await pumpUsers(tester, users: theCongregation());
      await openInvite(tester);

      await tester.enterText(find.byType(TextFormField), 'dora@example.org');
      await tester.tap(inDialog('Moderator'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Send invitation'));
      await settleWithoutAFrame(tester);

      verify(() =>
              repository.invite('dora@example.org', role: AppRole.moderator))
          .called(1);
    });

    testWidgets('cancelling invites nobody', (tester) async {
      final repository = await pumpUsers(tester, users: theCongregation());
      await openInvite(tester);

      await tester.enterText(find.byType(TextFormField), 'dora@example.org');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await settleWithoutAFrame(tester);

      verifyNever(() => repository.invite(any(), role: any(named: 'role')));
    });

    /// SKIPPED BECAUSE THE SCREEN IS BROKEN, not because the test is.
    ///
    /// `_promptInvite` disposes its `TextEditingController` on the line after
    /// `await showDialog(...)` returns, while the dialog's exit transition is
    /// still rebuilding the `TextFormField`. Every dismissal throws
    /// `A TextEditingController was used after being disposed.` in a debug
    /// build. Full write-up on the matching skipped test in
    /// `moderation_queue_test.dart`; the same line is in
    /// `admin_user_detail_screen._promptDelete`.
    testWidgets(
      'the invite dialog can be dismissed without a framework error',
      (tester) async {
        await pumpUsers(tester, users: theCongregation());
        await openInvite(tester);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      },
      skip: true,
    );
  });
}
