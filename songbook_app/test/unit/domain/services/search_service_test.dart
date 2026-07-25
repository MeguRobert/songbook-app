import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/domain/services/search_service.dart';

Song makeSong({
  required int number,
  required String title,
  String? reference,
  String? tuneName,
  List<String> tags = const [],
}) {
  return Song(
    number: number,
    title: title,
    reference: reference,
    tune: tuneName != null ? Tune(name: tuneName) : null,
    originalKey: 'C',
    verses: const [],
    tags: tags,
  );
}

void main() {
  const service = SearchService();

  final songs = [
    makeSong(
      number: 1,
      title: 'Aki nem jár hitlenek tanácsán',
      reference: 'Zsolt 1',
      tags: ['zsoltár'],
    ),
    makeSong(
      number: 15,
      title: 'Uram, ki lészen lakója',
      reference: 'Zsolt 15',
      tags: ['zsoltár'],
    ),
    makeSong(
      number: 42,
      title: 'Mint a szép híves patakra',
      reference: 'Zsolt 42',
      tuneName: 'Genfi dallam',
      tags: ['zsoltár', 'kedvelt'],
    ),
    makeSong(
      number: 151,
      title: 'Uram Isten, siess',
      tags: ['dicséret'],
    ),
    makeSong(
      number: 200,
      title: 'Áldjad én lelkem az Urat',
      tags: ['Dicséret', 'hálaadás'],
    ),
  ];

  group('search - query basics', () {
    test('empty query returns the full input list', () {
      expect(service.search(songs, ''), songs);
    });

    test('whitespace-only query normalizes to empty and matches everything',
        () {
      // '   ' is not empty so it goes through scoring; the normalized query
      // '' matches every field, so all songs are returned. Songs with more
      // populated fields (reference, tune) score higher.
      final results = service.search(songs, '   ');
      expect(results.map((s) => s.number).toSet(), {1, 15, 42, 151, 200});
      // 42 has title+number+reference+tags+tune -> highest score, first.
      expect(results.first.number, 42);
    });

    test('non-matching query returns empty list', () {
      expect(service.search(songs, 'nincs ilyen'), isEmpty);
    });

    test('input list is not mutated', () {
      final copy = List.of(songs);
      service.search(songs, 'uram');
      expect(songs, copy);
    });
  });

  group('search - number matching', () {
    test('exact song number returns only that song', () {
      final results = service.search(songs, '42');
      expect(results.map((s) => s.number), [42]);
    });

    test('exact number match wins even when digits appear in other numbers',
        () {
      // '15' is an exact match for song 15, so 151 is not included.
      final results = service.search(songs, '15');
      expect(results.map((s) => s.number), [15]);
    });

    test('numeric query with surrounding whitespace still matches exactly',
        () {
      final results = service.search(songs, ' 42 ');
      expect(results.map((s) => s.number), [42]);
    });

    test('numeric query without an exact match falls back to contains-scoring',
        () {
      // No song number 5 exists; both 15 and 151 contain "5".
      final results = service.search(songs, '5');
      expect(results.map((s) => s.number), [15, 151]);
    });

    test('unknown number with no digit matches returns empty', () {
      expect(service.search(songs, '999'), isEmpty);
    });
  });

  group('search - title matching and ranking', () {
    test('title prefix matches, tied scores ordered by number', () {
      // 'uram' is a title prefix of songs 15 and 151 only.
      final results = service.search(songs, 'uram');
      expect(results.map((s) => s.number), [15, 151]);
    });

    test('title contains ranks below title prefix', () {
      final results = service.search(songs, 'isten');
      // 151 'Uram Isten, siess' matches via contains only.
      expect(results.map((s) => s.number), [151]);
    });

    test('title match is diacritic-insensitive', () {
      final results = service.search(songs, 'aldjad');
      expect(results.map((s) => s.number), [200]);
    });

    test('title match is case-insensitive', () {
      final results = service.search(songs, 'MINT A SZÉP');
      expect(results.map((s) => s.number), [42]);
    });

    test('equal scores are ordered by song number', () {
      final results = service.search(songs, 'zsolt');
      // Songs 1, 15, 42 all match on reference only -> same score.
      expect(results.map((s) => s.number), [1, 15, 42]);
    });
  });

  group('search - reference, tag and tune matching', () {
    test('matches on reference', () {
      final results = service.search(songs, 'zsolt 42');
      expect(results.map((s) => s.number), contains(42));
    });

    test('matches on tag', () {
      final results = service.search(songs, 'kedvelt');
      expect(results.map((s) => s.number), [42]);
    });

    test('matches on tune name', () {
      final results = service.search(songs, 'genfi');
      expect(results.map((s) => s.number), [42]);
    });

    test('tag match is diacritic- and case-insensitive', () {
      final results = service.search(songs, 'DICSERET');
      expect(results.map((s) => s.number), [151, 200]);
    });
  });

  group('filterByTag', () {
    test('filters case-insensitively', () {
      final results = service.filterByTag(songs, 'DICSÉRET');
      expect(results.map((s) => s.number), [151, 200]);
    });

    test('is exact (not substring) on the tag', () {
      expect(service.filterByTag(songs, 'dics'), isEmpty);
    });

    test('is diacritic-sensitive (exact lowercase comparison)', () {
      expect(service.filterByTag(songs, 'dicseret'), isEmpty);
    });

    test('unknown tag returns empty', () {
      expect(service.filterByTag(songs, 'nope'), isEmpty);
    });
  });

  group('getAllTags', () {
    test('returns lowercased unique tags', () {
      final tags = service.getAllTags(songs);
      expect(tags, {'zsoltár', 'kedvelt', 'dicséret', 'hálaadás'});
    });

    test('empty song list yields empty set', () {
      expect(service.getAllTags([]), isEmpty);
    });
  });
}
