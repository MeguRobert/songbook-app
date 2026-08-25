import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/app_role.dart';
import 'package:songbook_app/l10n/app_localizations.dart';
import 'package:songbook_app/presentation/providers/admin_provider.dart';
import 'package:songbook_app/presentation/screens/admin/admin_gate.dart';

/// Three states, not two — and the middle one is the whole reason this file
/// exists.
///
/// A guard that reads "rank not yet known" as "denied" bounces an administrator
/// out of a bookmarked `/admin` URL on every cold load, because the rank arrives
/// from the server after the first frame. The bug is invisible in a hot-reloaded
/// session, where the answer is usually already cached, and reliable in a fresh
/// tab, which is how anyone else would ever hit it.
void main() {
  Widget wrap(Widget child, {required Override roleOverride}) {
    return ProviderScope(
      overrides: [roleOverride],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: child,
      ),
    );
  }

  /// A role that never arrives, standing in for a slow first load.
  Override pending() => currentRoleProvider.overrideWith(
        (ref) => Future<AppRole>.value(AppRole.member)
            // Never completes.
            .then((_) => Completer<AppRole>().future),
      );

  Override resolved(AppRole role) =>
      currentRoleProvider.overrideWith((ref) async => role);

  group('AdminGate', () {
    testWidgets('waits while the rank is still unknown, and does not deny',
        (tester) async {
      await tester.pumpWidget(wrap(
        const AdminGate(child: Text('the panel')),
        roleOverride: pending(),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The critical assertion: it has NOT decided against the caller.
      expect(find.text('This area is for administrators.'), findsNothing);
      expect(find.text('the panel'), findsNothing);
    });

    testWidgets('an administrator sees the panel', (tester) async {
      await tester.pumpWidget(wrap(
        const AdminGate(child: Text('the panel')),
        roleOverride: resolved(AppRole.administrator),
      ));
      await tester.pumpAndSettle();

      expect(find.text('the panel'), findsOneWidget);
    });

    testWidgets('a resolved member is told plainly, not silently redirected',
        (tester) async {
      await tester.pumpWidget(wrap(
        const AdminGate(child: Text('the panel')),
        roleOverride: resolved(AppRole.member),
      ));
      await tester.pumpAndSettle();

      expect(find.text('the panel'), findsNothing);
      expect(find.text('This area is for administrators.'), findsOneWidget);
    });

    testWidgets('a moderator is refused the administrator-only screens',
        (tester) async {
      await tester.pumpWidget(wrap(
        const AdminGate(child: Text('the panel')),
        roleOverride: resolved(AppRole.moderator),
      ));
      await tester.pumpAndSettle();

      // This is the split the whole feature turns on: before the role ladder,
      // is_admin() was true for a moderator and this would have passed.
      expect(find.text('the panel'), findsNothing);
    });

    testWidgets('a moderator IS allowed the queue, which asks for less',
        (tester) async {
      await tester.pumpWidget(wrap(
        const AdminGate(needsAdmin: false, child: Text('the queue')),
        roleOverride: resolved(AppRole.moderator),
      ));
      await tester.pumpAndSettle();

      expect(find.text('the queue'), findsOneWidget);
    });

    testWidgets('a member is refused even the queue', (tester) async {
      await tester.pumpWidget(wrap(
        const AdminGate(needsAdmin: false, child: Text('the queue')),
        roleOverride: resolved(AppRole.member),
      ));
      await tester.pumpAndSettle();

      expect(find.text('the queue'), findsNothing);
    });

    testWidgets('a failed rank check denies rather than spinning forever',
        (tester) async {
      await tester.pumpWidget(wrap(
        const AdminGate(child: Text('the panel')),
        roleOverride: currentRoleProvider
            .overrideWith((ref) async => throw Exception('offline')),
      ));
      await tester.pumpAndSettle();

      // Treating an error as "still checking" would hang the route behind a
      // spinner with no way out.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('This area is for administrators.'), findsOneWidget);
    });
  });
}
