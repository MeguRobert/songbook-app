import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/providers.dart';

/// Builds a test song with one structured verse (with chords) and one
/// plain-text verse.
Song makeTestSong({
  int number = 42,
  String title = 'Mint a szép híves patakra',
  String originalKey = 'Bb',
}) {
  return Song(
    number: number,
    title: title,
    reference: 'Zsolt 42',
    originalKey: originalKey,
    verses: const [
      Verse(
        number: 1,
        hasNotation: true,
        lines: [
          LyricLine(
            text: 'Mint a szép híves patakra',
            chords: [ChordPosition(chord: 'Bb', position: 0)],
          ),
          LyricLine(text: 'A szarvas kívánkozik'),
        ],
      ),
      Verse(number: 2, plainText: 'Second verse plain text'),
    ],
    tags: const ['zsoltár'],
  );
}

/// Pumps [child] inside a ProviderScope + MaterialApp with a mocked
/// SharedPreferences (seeded with [prefs]) and any extra [overrides].
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Map<String, Object> prefs = const {},
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPreferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ...overrides,
      ],
      child: MaterialApp(home: child),
    ),
  );
}
