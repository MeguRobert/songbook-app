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
}
