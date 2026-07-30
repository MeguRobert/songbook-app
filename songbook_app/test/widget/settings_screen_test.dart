import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:songbook_app/presentation/screens/settings/settings_screen.dart';

import 'helpers.dart';

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

  testWidgets('renders all settings sections', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('DISPLAY'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Font Size'), findsOneWidget);
    expect(find.text('Default View'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
  });

  // The version used to be a hardcoded '1.0.0' literal, so it was already
  // wrong and would have stayed wrong through every release. It has to come
  // from the artifact, and it has to include the build number — that is the
  // part that distinguishes one deployment from a cached copy of the last one.
  testWidgets('reports the built version, not a hardcoded string',
      (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('1.1.0 (build 143)'), findsOneWidget);
  });

  testWidgets('omits the build number when there is none', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Songbook',
      packageName: 'com.example.songbook_app',
      version: '2.0.0',
      buildNumber: '',
      buildSignature: '',
    );

    await pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('2.0.0'), findsOneWidget);
  });

  testWidgets('shows the persisted theme label', (tester) async {
    await pumpScreen(tester, const SettingsScreen(),
        prefs: {'settings_theme_mode': 'dark'});
    await tester.pumpAndSettle();
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('font size + button increases the displayed size',
      (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    expect(find.text('18'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('20'), findsOneWidget);
    expect(find.text('18'), findsNothing);
  });

  testWidgets('theme dialog changes the theme mode', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    expect(find.text('System default'), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsOneWidget); // now the subtitle
  });

  testWidgets('default view dialog applies a preset', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    expect(find.text('Sheet Music'), findsOneWidget);

    await tester.tap(find.text('Default View'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lyrics Only'));
    await tester.pumpAndSettle();

    expect(find.text('Lyrics Only'), findsOneWidget); // now the subtitle
  });

  // The dialogs used RadioListTile, whose radio showed which option was
  // active. They now use ListTile + a tick, matching the language dialog,
  // because the Radio API is deprecated. The behaviour tests above pass either
  // way — they only tap and check the result — so these pin the part that
  // actually changed: the tick has to be on the CURRENT option and nowhere
  // else, or the dialog silently stops saying what is selected.
  Finder tickOnRowWith(String label) => find.descendant(
        of: find.widgetWithText(ListTile, label),
        matching: find.byIcon(Icons.check),
      );

  testWidgets('theme dialog ticks the active mode only', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    // Default is System default.
    expect(tickOnRowWith('System default'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'exactly one tick');

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    // Reopen: the tick has moved with the choice.
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(tickOnRowWith('Dark'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('default view dialog ticks the active preset only',
      (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Default View'));
    await tester.pumpAndSettle();
    expect(tickOnRowWith('Sheet Music'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('Chords'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Default View'));
    await tester.pumpAndSettle();
    expect(tickOnRowWith('Chords'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('each default-view option keeps its own hint', (tester) async {
    // The old dialog hardcoded a preset per branch and ignored its own `value`,
    // so a row could show one option's hint while applying another. The rows
    // are data-driven now; this pins hint-to-option pairing.
    await pumpScreen(tester, const SettingsScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default View'));
    await tester.pumpAndSettle();

    for (final label in ['Sheet Music', 'Chords', 'Lyrics Only']) {
      // Scoped to the dialog: the settings row behind it shows the current
      // preset as its own subtitle, so an unscoped finder matches twice.
      final row = find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.widgetWithText(ListTile, label),
      );
      expect(row, findsOneWidget, reason: label);
      // Every row carries a subtitle, and no two rows share one.
      expect(
        find.descendant(of: row, matching: find.byType(Text)),
        findsNWidgets(2),
        reason: '$label should have a title and its own hint',
      );
    }
  });
}
