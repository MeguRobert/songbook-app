import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';

void main() {
  group('Origin', () {
    test('JSON round-trip', () {
      const origin = Origin(place: 'Genf', year: 1562);
      expect(Origin.fromJson(origin.toJson()), origin);
    });

    test('fromJson tolerates missing fields', () {
      final origin = Origin.fromJson({});
      expect(origin.place, isNull);
      expect(origin.year, isNull);
    });

    test('displayString formats all combinations', () {
      expect(const Origin(place: 'Genf', year: 1562).displayString,
          'Genf, 1562');
      expect(const Origin(place: 'Genf').displayString, 'Genf');
      expect(const Origin(year: 1562).displayString, '1562');
      expect(const Origin().displayString, isNull);
    });

    test('equality on place and year', () {
      expect(const Origin(place: 'a', year: 1), const Origin(place: 'a', year: 1));
      expect(const Origin(place: 'a'), isNot(const Origin(place: 'b')));
      expect(const Origin(year: 1), isNot(const Origin(year: 2)));
    });
  });

  group('Tune', () {
    test('JSON round-trip with nested origin', () {
      const tune = Tune(name: 'Genfi', origin: Origin(place: 'Genf', year: 1562));
      final decoded =
          Tune.fromJson(json.decode(json.encode(tune.toJson())));
      expect(decoded, tune);
    });

    test('fromJson tolerates missing fields', () {
      final tune = Tune.fromJson({});
      expect(tune.name, isNull);
      expect(tune.origin, isNull);
    });
  });

  group('SheetMusic', () {
    test('JSON round-trip', () {
      const sheet = SheetMusic(type: 'svg', basePath: 'assets/sheet_music/151');
      expect(SheetMusic.fromJson(sheet.toJson()), sheet);
    });

    test('getPathForKey appends key and extension', () {
      const sheet = SheetMusic(type: 'svg', basePath: 'assets/sheet_music/151');
      expect(sheet.getPathForKey('Bb'), 'assets/sheet_music/151_Bb.svg');
      expect(sheet.getPathForKey('C'), 'assets/sheet_music/151_C.svg');
    });
  });

  group('Song JSON', () {
    final fullJson = {
      'number': 42,
      'title': 'Mint a szép híves patakra',
      'reference': 'Zsolt 42',
      'origin': {'place': 'Genf', 'year': 1562},
      'tune': {
        'name': 'Genfi dallam',
        'origin': {'place': 'Genf', 'year': 1551},
      },
      'originalKey': 'Bb',
      'timeSignature': '4/4',
      'sheetMusic': {'type': 'svg', 'basePath': 'assets/sheet_music/42'},
      'notation': {
        'originalKey': 'Bb',
        'timeSignature': '4/4',
        'verses': [
          {
            'number': 1,
            'measures': [
              {
                'beats': [
                  {'pitch': 'Bb4', 'duration': 'quarter', 'syllable': 'Mint'},
                ],
              },
            ],
          },
        ],
      },
      'verses': [
        {
          'number': 1,
          'hasNotation': true,
          'lines': [
            {
              'text': 'Mint a szép híves patakra',
              'chords': [
                {'chord': 'Bb', 'position': 0},
              ],
            },
          ],
        },
        {'number': 2, 'plainText': 'Second verse text'},
      ],
      'tags': ['zsoltár'],
    };

    test('fromJson parses a fully populated song', () {
      final song = Song.fromJson(fullJson);
      expect(song.number, 42);
      expect(song.title, 'Mint a szép híves patakra');
      expect(song.reference, 'Zsolt 42');
      expect(song.origin, const Origin(place: 'Genf', year: 1562));
      expect(song.tune?.name, 'Genfi dallam');
      expect(song.tune?.origin?.year, 1551);
      expect(song.originalKey, 'Bb');
      expect(song.timeSignature, '4/4');
      expect(song.sheetMusic?.basePath, 'assets/sheet_music/42');
      expect(song.notation?.originalKey, 'Bb');
      expect(song.verses, hasLength(2));
      expect(song.verses[0].lines.single.chords.single.chord, 'Bb');
      expect(song.verses[1].plainText, 'Second verse text');
      expect(song.tags, ['zsoltár']);
    });

    test('fromJson parses a minimal song with defaults', () {
      final song = Song.fromJson({
        'number': 1,
        'title': 'Minimal',
        'originalKey': 'C',
        'verses': <dynamic>[],
      });
      expect(song.reference, isNull);
      expect(song.origin, isNull);
      expect(song.tune, isNull);
      expect(song.timeSignature, isNull);
      expect(song.sheetMusic, isNull);
      expect(song.notation, isNull);
      expect(song.verses, isEmpty);
      expect(song.tags, isEmpty);
    });

    test('round-trips through encoded JSON', () {
      final song = Song.fromJson(fullJson);
      final reencoded = json.decode(json.encode(song.toJson()));
      final decoded = Song.fromJson(reencoded);

      expect(decoded.number, song.number);
      expect(decoded.title, song.title);
      expect(decoded.origin, song.origin);
      expect(decoded.tune, song.tune);
      expect(decoded.sheetMusic, song.sheetMusic);
      expect(decoded.verses.length, song.verses.length);
      expect(decoded.verses[0].lines.single, song.verses[0].lines.single);
      expect(decoded.tags, song.tags);
      expect(decoded.notation?.verses.single.measures.single.beats.single.pitch,
          'Bb4');
    });
  });

  group('Song computed properties', () {
    final structuredVerse = Verse(
      number: 1,
      hasNotation: true,
      lines: const [
        LyricLine(text: 'l1', chords: [ChordPosition(chord: 'C', position: 0)]),
      ],
    );
    const plainVerse = Verse(number: 2, plainText: 'plain');

    Song song({List<Verse> verses = const [], SheetMusic? sheet,
        SongNotation? notation}) {
      return Song(
        number: 1,
        title: 't',
        originalKey: 'C',
        verses: verses,
        sheetMusic: sheet,
        notation: notation,
      );
    }

    test('firstVerse returns first or null', () {
      expect(song(verses: [structuredVerse, plainVerse]).firstVerse,
          structuredVerse);
      expect(song().firstVerse, isNull);
    });

    test('additionalVerses excludes verses with notation', () {
      final s = song(verses: [structuredVerse, plainVerse]);
      expect(s.additionalVerses, [plainVerse]);
    });

    test('hasSheetMusic / hasNotation reflect presence', () {
      expect(song().hasSheetMusic, isFalse);
      expect(song(sheet: const SheetMusic(type: 'svg', basePath: 'x'))
          .hasSheetMusic, isTrue);
      expect(song().hasNotation, isFalse);
      expect(
        song(notation: const SongNotation(
          originalKey: 'C',
          timeSignature: '4/4',
          verses: [],
        )).hasNotation,
        isTrue,
      );
    });

    test('hasChords is true only when a line has chords', () {
      expect(song(verses: [structuredVerse]).hasChords, isTrue);
      expect(song(verses: [plainVerse]).hasChords, isFalse);
      expect(song().hasChords, isFalse);
    });

    test('displayNumber is the plain number string', () {
      expect(song().displayNumber, '1');
    });
  });

  group('Song copyWith and equality', () {
    test('copyWith overrides fields', () {
      final s = Song(number: 1, title: 'a', originalKey: 'C', verses: const []);
      expect(s.copyWith(title: 'b').title, 'b');
      expect(s.copyWith(title: 'b').number, 1);
      expect(s.copyWith(number: 2).number, 2);
      expect(s.copyWith(originalKey: 'D').originalKey, 'D');
    });

    test('equality covers every field, not just the number', () {
      final a = Song(number: 5, title: 'x', originalKey: 'C', verses: const []);
      // Same number, different everything else. These used to compare equal.
      final b = Song(number: 5, title: 'y', originalKey: 'G', verses: const []);
      expect(a, isNot(b));
      expect(
          a, isNot(Song(number: 6, title: 'x', originalKey: 'C', verses: const [])));

      final same = Song(number: 5, title: 'x', originalKey: 'C', verses: const []);
      expect(a, same);
      expect(a.hashCode, same.hashCode);
    });

    test('a retagged song differs from the one it replaced', () {
      final original = Song(
        number: 5,
        title: 'x',
        originalKey: 'C',
        verses: const [],
        tags: const ['zsoltár'],
      );
      final retagged = original.copyWith(tags: const ['zsoltár', 'advent']);

      expect(retagged, isNot(original));
      expect(retagged.hashCode, isNot(original.hashCode));
    });

    test('an edited verse makes the song differ', () {
      final original = Song(
        number: 5,
        title: 'x',
        originalKey: 'C',
        verses: const [Verse(number: 1, lines: [LyricLine(text: 'eredeti')])],
      );
      final edited = original.copyWith(
        verses: const [Verse(number: 1, lines: [LyricLine(text: 'javított')])],
      );

      // Only reaches through if BOTH Verse and LyricLine carry value equality.
      expect(edited, isNot(original));
    });
  });
}
