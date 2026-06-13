import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/settings/settings_screen.dart';
import 'package:songbook_app/presentation/screens/song_list/song_list_screen.dart';

/// A minimal song with a reference so the list tile renders title + subtitle.
final fixtureSongs = [
  const Song(
    number: 1,
    title: 'Test Song One',
    originalKey: 'C',
    verses: [],
    reference: 'Psalm 1',
    book: 'Zsoltárok',
  ),
  const Song(
    number: 42,
    title: 'Test Song Two',
    originalKey: 'G',
    verses: [],
    reference: 'Psalm 42',
    book: 'Zsoltárok',
  ),
];

/// Pumps [child] inside a ProviderScope with mock-backed SharedPreferences and
/// a fixed song list, wrapped in a MaterialApp. Optional [textScaler] exercises
/// system text scaling.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        songsProvider.overrideWith((ref) async => fixtureSongs),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Accessibility guidelines', () {
    testWidgets('SongListScreen meets tap-target and labeled-tap-target guidelines',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, const SongListScreen());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });

    testWidgets('SettingsScreen meets labeled-tap-target guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, const SettingsScreen());

      // Proves the font-size +/- IconButtons now carry tooltips (labels).
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });
  });

  group('Semantic labels', () {
    testWidgets('Song list tiles expose a "Song N" label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, const SongListScreen());

      // ListTile merges descendant semantics, so the leading number's label is
      // concatenated into the tile's combined label — match it as a substring.
      expect(find.bySemanticsLabel(RegExp('Song 1')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Song 42')), findsWidgets);

      handle.dispose();
    });

    testWidgets('Favorite action carries a tooltip label', (tester) async {
      await pumpScreen(tester, const SongListScreen());

      // The favorite IconButton's tooltip is its screen-reader label
      // (exposed via the semantics tooltip field, surfaced by find.byTooltip).
      expect(find.byTooltip('Add to favorites'), findsWidgets);
    });
  });

  group('Text scaling', () {
    testWidgets('SongListScreen renders at 2.5x text scale without exception',
        (tester) async {
      await pumpScreen(
        tester,
        const SongListScreen(),
        textScaler: const TextScaler.linear(2.5),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Test Song One'), findsOneWidget);
    });
  });
}
