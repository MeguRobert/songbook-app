import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/song_id.dart';

void main() {
  group('canonical form', () {
    test('hymnal ids render as source:number', () {
      expect(const SongId.hymnal(151).value, 'hymnal:151');
      expect(const SongId.hymnal(1).toString(), 'hymnal:1');
    });

    test('user ids render as source:ref', () {
      expect(const SongId.user('l9f3a2c').value, 'user:l9f3a2c');
    });

    test('round-trips through its own string form', () {
      const ids = [SongId.hymnal(151), SongId.user('abc123')];
      for (final id in ids) {
        expect(SongId.parse(id.value), id);
      }
    });
  });

  group('parsing', () {
    test('accepts both canonical sources', () {
      expect(SongId.tryParse('hymnal:151'), const SongId.hymnal(151));
      expect(SongId.tryParse('user:abc'), const SongId.user('abc'));
    });

    test('reads a bare integer as a hymnal number', () {
      // The upgrade path: every favourite, recent, setlist entry and tag
      // override written before song ids existed stores a bare int.
      expect(SongId.tryParse('151'), const SongId.hymnal(151));
      expect(SongId.tryParse('  42  '), const SongId.hymnal(42));
    });

    test('rejects malformed input rather than guessing', () {
      expect(SongId.tryParse(''), isNull);
      expect(SongId.tryParse('   '), isNull);
      expect(SongId.tryParse('nonsense:1'), isNull);
      expect(SongId.tryParse('hymnal:'), isNull);
      expect(SongId.tryParse('not-a-number'), isNull);
    });

    test('parse throws where tryParse returns null', () {
      expect(() => SongId.parse('nonsense:1'), throwsFormatException);
    });

    test('keeps a ref containing a colon intact', () {
      // Split on the FIRST colon only, so a ref is never silently truncated.
      final id = SongId.parse('user:a:b:c');
      expect(id.source, SongSource.user);
      expect(id.ref, 'a:b:c');
    });
  });

  group('json', () {
    test('serialises to the canonical string', () {
      expect(const SongId.hymnal(151).toJson(), 'hymnal:151');
    });

    test('deserialises a legacy bare int', () {
      expect(SongId.fromJson(151), const SongId.hymnal(151));
    });

    test('deserialises the canonical string', () {
      expect(SongId.fromJson('user:xyz'), const SongId.user('xyz'));
    });

    test('returns null for anything else', () {
      expect(SongId.fromJson(null), isNull);
      expect(SongId.fromJson(3.5), isNull);
      expect(SongId.fromJson(const {}), isNull);
    });
  });

  group('hymnalNumber', () {
    test('is the number for hymnal ids', () {
      expect(const SongId.hymnal(151).hymnalNumber, 151);
      expect(const SongId.hymnal(151).isHymnal, isTrue);
      expect(const SongId.hymnal(151).isUserSong, isFalse);
    });

    test('is null for user ids', () {
      expect(const SongId.user('abc').hymnalNumber, isNull);
      expect(const SongId.user('abc').isUserSong, isTrue);
    });
  });

  group('equality', () {
    test('same source and ref are equal and hash equally', () {
      expect(const SongId.hymnal(151), const SongId.hymnal(151));
      expect(const SongId.hymnal(151).hashCode,
          const SongId.hymnal(151).hashCode);
      expect({const SongId.hymnal(151), const SongId.hymnal(151)}, hasLength(1));
    });

    test('the same ref from different sources is NOT equal', () {
      // The whole point of carrying a source: hymnal 300 and a user song that
      // happens to be called 300 must never collide.
      expect(const SongId.hymnal(300), isNot(const SongId.user('300')));
    });
  });

  group('ordering', () {
    test('hymnal ids sort numerically, not lexically', () {
      final ids = [
        const SongId.hymnal(90),
        const SongId.hymnal(151),
        const SongId.hymnal(1),
      ]..sort();
      expect(ids.map((i) => i.hymnalNumber), [1, 90, 151]);
    });

    test('hymnal songs sort before user songs', () {
      final ids = [
        const SongId.user('aaa'),
        const SongId.hymnal(999),
      ]..sort();
      expect(ids.first.isHymnal, isTrue);
    });
  });

  group('newUserSong', () {
    test('is deterministic given a clock and a seed', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1750000000000);
      final a = SongId.newUserSong(now: at, random: Random(7));
      final b = SongId.newUserSong(now: at, random: Random(7));
      expect(a, b);
      expect(a.source, SongSource.user);
    });

    test('differs for two songs created in the same millisecond', () {
      final at = DateTime.fromMillisecondsSinceEpoch(1750000000000);
      final a = SongId.newUserSong(now: at, random: Random(1));
      final b = SongId.newUserSong(now: at, random: Random(2));
      expect(a, isNot(b));
    });

    test('sorts by creation time', () {
      final earlier = SongId.newUserSong(
          now: DateTime.fromMillisecondsSinceEpoch(1750000000000),
          random: Random(1));
      final later = SongId.newUserSong(
          now: DateTime.fromMillisecondsSinceEpoch(1760000000000),
          random: Random(1));
      expect(earlier.compareTo(later), lessThan(0));
    });

    test('survives a round-trip through its string form', () {
      final id = SongId.newUserSong();
      expect(SongId.parse(id.value), id);
    });
  });

  test('canonical form is safe to carry in a route path', () {
    const id = SongId.hymnal(151);
    final uri = Uri.parse('/song/${Uri.encodeComponent(id.value)}');
    expect(SongId.parse(Uri.decodeComponent(uri.pathSegments.last)), id);
  });
}
