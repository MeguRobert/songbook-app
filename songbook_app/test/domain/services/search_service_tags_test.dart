import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/domain/services/search_service.dart';

Song song(int number, {List<String> tags = const []}) => Song(
      number: number,
      title: 'Song $number',
      originalKey: 'C',
      verses: const [],
      tags: tags,
    );

void main() {
  const service = SearchService();

  group('tagsWithCounts', () {
    test('counts distinct tags and orders by count desc then name', () {
      final songs = [
        song(1, tags: ['praise', 'advent']),
        song(2, tags: ['praise']),
        song(3, tags: ['praise', 'communion']),
      ];

      final tags = service.tagsWithCounts(songs);

      expect(tags.map((t) => t.name), equals(['praise', 'advent', 'communion']));
      expect(tags.first.songCount, 3);
      expect(tags[1].songCount, 1); // advent before communion (alpha tiebreak)
    });

    test('groups case-insensitively and preserves first-seen casing', () {
      final songs = [
        song(1, tags: ['Luther']),
        song(2, tags: ['luther']),
      ];

      final tags = service.tagsWithCounts(songs);

      expect(tags.length, 1);
      expect(tags.first.name, 'Luther');
      expect(tags.first.songCount, 2);
    });

    test('ignores blank tags and empty input', () {
      expect(service.tagsWithCounts([]), isEmpty);
      expect(service.tagsWithCounts([song(1, tags: ['  ', ''])]), isEmpty);
    });
  });

  group('filterByTags', () {
    final songs = [
      song(1, tags: ['praise', 'advent']),
      song(2, tags: ['praise']),
      song(3, tags: ['advent', 'communion']),
    ];

    test('empty tag set returns all songs', () {
      expect(service.filterByTags(songs, {}).length, 3);
    });

    test('single tag, case-insensitive', () {
      final result = service.filterByTags(songs, {'PRAISE'});
      expect(result.map((s) => s.number), equals([1, 2]));
    });

    test('matchAll (AND) requires all tags', () {
      final result =
          service.filterByTags(songs, {'praise', 'advent'}, matchAll: true);
      expect(result.map((s) => s.number), equals([1]));
    });

    test('matchAll:false (OR) requires any tag', () {
      final result = service
          .filterByTags(songs, {'communion', 'praise'}, matchAll: false);
      expect(result.map((s) => s.number), equals([1, 2, 3]));
    });
  });

  group('applyTagOverrides', () {
    final songs = [
      song(1, tags: ['praise']),
      song(2, tags: ['advent']),
    ];

    test('empty overrides returns the same list reference', () {
      final result = service.applyTagOverrides(songs, {});
      expect(identical(result, songs), isTrue);
    });

    test('overridden song gets new tags; others unchanged', () {
      final result = service.applyTagOverrides(songs, {
        const SongId.hymnal(1): ['communion', 'evening'],
      });

      expect(result.firstWhere((s) => s.number == 1).tags,
          equals(['communion', 'evening']));
      expect(result.firstWhere((s) => s.number == 2).tags, equals(['advent']));
    });
  });
}
