import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/domain/services/search_service.dart';

/// Song whose verses use the structured `lines` shape (verse 1 with notation).
Song structured(int number, String title, List<List<String>> verseLines) {
  return Song(
    number: number,
    title: title,
    originalKey: 'C',
    verses: [
      for (var i = 0; i < verseLines.length; i++)
        Verse(
          number: i + 1,
          hasNotation: i == 0,
          lines: [for (final t in verseLines[i]) LyricLine(text: t)],
        ),
    ],
  );
}

/// Song whose verses use the `plainText` shape (verses 2+ typically).
Song plain(int number, String title, List<String> verses) {
  return Song(
    number: number,
    title: title,
    originalKey: 'C',
    verses: [
      for (var i = 0; i < verses.length; i++)
        Verse(number: i + 1, plainText: verses[i]),
    ],
  );
}

void main() {
  const service = SearchService();

  final songs = [
    structured(1, 'Szent Isten, kit a seregek', [
      ['Szent Isten, kit a seregek', 'dicsérnek szüntelen'],
      ['Téged dicsér a föld s az ég'],
    ]),
    structured(42, 'Mint a szép híves patakra', [
      ['Mint a szép híves patakra', 'a szarvas kívánkozik'],
    ]),
    plain(90, 'Te benned bíztunk eleitől fogva', [
      'Te benned bíztunk eleitől fogva,',
      'Az embereket te meg hagyod halni,\nés ezt mondod az emberi nemzetnek:',
    ]),
  ];

  group('searchLyrics', () {
    test('finds a song by a phrase from its lyrics, not its title', () {
      final hits = service.searchLyrics(songs, 'szarvas');

      expect(hits.map((h) => h.song.number), [42]);
      expect(hits.single.snippet, contains('szarvas'));
    });

    test('matches inside a plainText verse', () {
      final hits = service.searchLyrics(songs, 'emberi nemzetnek');

      expect(hits.map((h) => h.song.number), [90]);
      expect(hits.single.snippet, contains('emberi nemzetnek'));
    });

    test('is diacritic- and case-insensitive like the rest of search', () {
      final hits = service.searchLyrics(songs, 'DICSERNEK');

      expect(hits.map((h) => h.song.number), [1]);
    });

    test('returns the matching line as the snippet, not the whole verse', () {
      final hits = service.searchLyrics(songs, 'meg hagyod halni');

      expect(hits.single.snippet, 'Az embereket te meg hagyod halni,');
    });

    test('reports every matching song, ordered by song number', () {
      final hits = service.searchLyrics(songs, 'a'); // appears everywhere

      expect(hits.map((h) => h.song.number), [1, 42, 90]);
    });

    test('empty query matches nothing', () {
      expect(service.searchLyrics(songs, ''), isEmpty);
      expect(service.searchLyrics(songs, '   '), isEmpty);
    });

    test('no match yields no hits', () {
      expect(service.searchLyrics(songs, 'villamos'), isEmpty);
    });

    test('a long line is windowed around the match with ellipses', () {
      final long = plain(7, 'Long', [
        '${'lorem ipsum dolor sit amet ' * 8}NEEDLE${' consectetur adipiscing elit' * 8}',
      ]);

      final snippet = service.searchLyrics([long], 'NEEDLE').single.snippet;

      expect(snippet, contains('NEEDLE'));
      expect(snippet.length, lessThan(120));
      expect(snippet, startsWith('…'));
      expect(snippet, endsWith('…'));
    });

    test('a short line is returned whole, without ellipses', () {
      final snippet = service.searchLyrics(songs, 'szarvas').single.snippet;

      expect(snippet, 'a szarvas kívánkozik');
    });
  });
}
