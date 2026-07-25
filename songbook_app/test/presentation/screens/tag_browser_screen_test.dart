import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/tags/tag_browser_screen.dart';

Song song(int number, {List<String> tags = const []}) => Song(
      number: number,
      title: 'Song $number',
      originalKey: 'C',
      verses: const [],
      tags: tags,
    );

Future<void> pumpScreen(WidgetTester tester, List<Song> songs) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        songsProvider.overrideWith((ref) async => songs),
      ],
      child: const MaterialApp(home: TagBrowserScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders a tile per tag with its song count', (tester) async {
    await pumpScreen(tester, [
      song(1, tags: ['praise', 'advent']),
      song(2, tags: ['praise']),
    ]);

    expect(find.text('praise'), findsOneWidget);
    expect(find.text('advent'), findsOneWidget);
    // praise appears on 2 songs, advent on 1.
    expect(find.text('2 songs'), findsOneWidget);
    expect(find.text('1 song'), findsOneWidget);
  });

  testWidgets('shows the empty state when no songs have tags', (tester) async {
    await pumpScreen(tester, [song(1), song(2)]);

    expect(find.text('No tags yet'), findsOneWidget);
  });
}
