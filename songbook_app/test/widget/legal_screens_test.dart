import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/auth/auth_screen.dart';
import 'package:songbook_app/presentation/screens/legal/legal_screen.dart';
import 'package:songbook_app/router/app_router.dart';

import 'helpers.dart';

/// The privacy notice and the terms, over the real route table.
///
/// `createAppRouter` rather than a hand-built one: the thing worth pinning is
/// that `/privacy` resolves from a cold load — a link in the sign-up footer, or
/// pasted into a fresh tab, has to land somewhere other than the error page.
Future<GoRouter> pumpLegalAppAt(
  WidgetTester tester,
  String location, {
  bool withAccounts = false,
}) async {
  SharedPreferences.setMockInitialValues(const {});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
    songRepositoryProvider
        .overrideWithValue(EmptyBundledCatalogue(LocalDataSource(preferences))),
    // The account section renders only when there is a backend. Overriding the
    // derived flag rather than supplying a repository keeps this test away from
    // Supabase entirely: nothing here signs in, it only walks to the footer.
    if (withAccounts) authAvailableProvider.overrideWithValue(true),
  ]);
  addTearDown(container.dispose);

  final router = createAppRouter(initialLocation: location);
  addTearDown(router.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: localizedRouterApp(router),
  ));
  await tester.pumpAndSettle();
  return router;
}

/// Scrolls [label] into view in the first scrollable on screen.
Future<void> reveal(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Songbook',
      packageName: 'com.example.songbook_app',
      version: '1.1.0',
      buildNumber: '143',
      buildSignature: '',
    );
  });

  group('the notice has an address of its own', () {
    testWidgets('/privacy cold-loads', (tester) async {
      await pumpLegalAppAt(tester, AppRoutes.privacy);

      expect(find.byType(PrivacyScreen), findsOneWidget);
      expect(find.text('Privacy'), findsWidgets);
    });

    testWidgets('/terms cold-loads', (tester) async {
      await pumpLegalAppAt(tester, AppRoutes.terms);

      expect(find.byType(TermsScreen), findsOneWidget);
      expect(find.text('Copyright — please read this one'), findsOneWidget);
    });
  });

  testWidgets('the two photo readers are described separately', (tester) async {
    // The one claim on the page a reader is entitled to rely on: which button
    // uploads their photograph. Both headings present is what makes the
    // distinction visible rather than buried in a paragraph.
    await pumpLegalAppAt(tester, AppRoutes.privacy);

    await reveal(tester, 'Words and chords');
    expect(find.text('Words and chords'), findsOneWidget);
    await reveal(tester, 'Sheet music');
    expect(find.text('Sheet music'), findsOneWidget);
  });

  testWidgets('Settings reaches it', (tester) async {
    final router = await pumpLegalAppAt(tester, AppRoutes.settings);

    await reveal(tester, 'Privacy and terms');
    await tester.tap(find.text('Privacy and terms'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyScreen), findsOneWidget);
    expect(router.state.uri.toString(), AppRoutes.privacy);
  });

  testWidgets('the notice links on to the terms', (tester) async {
    await pumpLegalAppAt(tester, AppRoutes.privacy);

    await reveal(tester, 'Terms of use');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Terms of use'));
    await tester.pumpAndSettle();

    expect(find.byType(TermsScreen), findsOneWidget);
  });

  testWidgets('somebody creating an account can read it first', (tester) async {
    // The sign-in screen is pushed with a MaterialPageRoute onto the *shell's*
    // navigator, while `/privacy` is a top-level route on the root one. That
    // mixture is exactly what could have left the notice rendering underneath
    // the form, so it is walked rather than assumed.
    await pumpLegalAppAt(tester, AppRoutes.settings, withAccounts: true);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);

    await reveal(tester, 'Privacy');
    await tester.tap(find.widgetWithText(TextButton, 'Privacy'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyScreen), findsOneWidget);
  });
}
