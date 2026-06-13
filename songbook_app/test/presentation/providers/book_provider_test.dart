import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/domain/services/book_service.dart';
import 'package:songbook_app/presentation/providers/book_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';

Song song(int number, {String? book}) => Song(
      number: number,
      title: 'Song $number',
      originalKey: 'C',
      verses: const [],
      book: book,
    );

final fixtureSongs = [
  song(1, book: 'Zsoltárok'),
  song(42, book: 'Zsoltárok'),
  song(151, book: 'Dicséretek'),
  song(999), // no book -> Other
];

/// Builds a ProviderContainer with a real mock-backed SharedPreferences and a
/// fixed song list.
Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      songsProvider.overrideWith((ref) async => fixtureSongs),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('booksProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns ordered books with counts including Other', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final books = await container.read(booksProvider.future);

      expect(books.map((b) => b.name), equals(['Zsoltárok', 'Dicséretek', 'Other']));
      expect(books.firstWhere((b) => b.name == 'Zsoltárok').songCount, 2);
      expect(books.firstWhere((b) => b.name == 'Other').songCount, 1);
    });
  });

  group('filteredSongsProvider', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns all songs when no book is selected', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      final songs = await container.read(filteredSongsProvider.future);

      expect(songs.map((s) => s.number), equals([1, 42, 151, 999]));
    });

    test('selecting a book filters the list and persists the choice', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container.read(selectedBookProvider.notifier).select('Zsoltárok');

      final songs = await container.read(filteredSongsProvider.future);
      expect(songs.map((s) => s.number), equals([1, 42]));
      expect(container.read(selectedBookProvider), 'Zsoltárok');

      // Persisted under the settings_-prefixed key.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_selected_book'), 'Zsoltárok');
    });

    test('selecting the Other bucket returns only unbooked songs', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container
          .read(selectedBookProvider.notifier)
          .select(BookService.ungroupedLabel);

      final songs = await container.read(filteredSongsProvider.future);
      expect(songs.map((s) => s.number), equals([999]));
    });

    test('clear() restores all songs and removes the pref', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);

      await container.read(selectedBookProvider.notifier).select('Dicséretek');
      await container.read(selectedBookProvider.notifier).clear();

      final songs = await container.read(filteredSongsProvider.future);
      expect(songs.map((s) => s.number), equals([1, 42, 151, 999]));
      expect(container.read(selectedBookProvider), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_selected_book'), isNull);
    });
  });

  group('selectedBookProvider initial state', () {
    test('reads a pre-seeded selected book from prefs', () async {
      SharedPreferences.setMockInitialValues({
        'settings_selected_book': 'Dicséretek',
      });
      final container = await makeContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedBookProvider), 'Dicséretek');

      final songs = await container.read(filteredSongsProvider.future);
      expect(songs.map((s) => s.number), equals([151]));
    });
  });
}
