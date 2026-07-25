import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';

void main() {
  group('NoteDuration extension', () {
    test('beats values', () {
      expect(NoteDuration.whole.beats, 4.0);
      expect(NoteDuration.half.beats, 2.0);
      expect(NoteDuration.quarter.beats, 1.0);
      expect(NoteDuration.eighth.beats, 0.5);
      expect(NoteDuration.sixteenth.beats, 0.25);
    });

    test('spacing multipliers', () {
      expect(NoteDuration.whole.spacingMultiplier, 4.0);
      expect(NoteDuration.half.spacingMultiplier, 2.5);
      expect(NoteDuration.quarter.spacingMultiplier, 1.5);
      expect(NoteDuration.eighth.spacingMultiplier, 1.0);
      expect(NoteDuration.sixteenth.spacingMultiplier, 0.75);
    });
  });

  group('NotatedBeat JSON', () {
    test('fromJson with all fields', () {
      final beat = NotatedBeat.fromJson({
        'pitch': 'Bb4',
        'duration': 'eighth',
        'syllable': 'la',
        'syllables': ['la', 'lá'],
        'chord': 'Bb',
        'tieStart': true,
        'tieEnd': false,
        'dotted': true,
      });
      expect(beat.pitch, 'Bb4');
      expect(beat.duration, NoteDuration.eighth);
      expect(beat.syllable, 'la');
      expect(beat.syllables, ['la', 'lá']);
      expect(beat.chord, 'Bb');
      expect(beat.tieStart, isTrue);
      expect(beat.tieEnd, isFalse);
      expect(beat.dotted, isTrue);
    });

    test('fromJson defaults for optional flags', () {
      final beat = NotatedBeat.fromJson({'pitch': 'C4', 'duration': 'quarter'});
      expect(beat.tieStart, isFalse);
      expect(beat.tieEnd, isFalse);
      expect(beat.dotted, isFalse);
      expect(beat.syllable, isNull);
      expect(beat.syllables, isNull);
      expect(beat.chord, isNull);
    });

    test('duration enum maps all values by string', () {
      for (final entry in {
        'whole': NoteDuration.whole,
        'half': NoteDuration.half,
        'quarter': NoteDuration.quarter,
        'eighth': NoteDuration.eighth,
        'sixteenth': NoteDuration.sixteenth,
      }.entries) {
        final beat =
            NotatedBeat.fromJson({'pitch': 'C4', 'duration': entry.key});
        expect(beat.duration, entry.value, reason: entry.key);
        expect(beat.toJson()['duration'], entry.key);
      }
    });

    test('invalid duration string throws', () {
      expect(
        () => NotatedBeat.fromJson({'pitch': 'C4', 'duration': 'breve'}),
        throwsArgumentError,
      );
    });

    test('round-trips through encoded JSON', () {
      const beat = NotatedBeat(
        pitch: 'F#5',
        duration: NoteDuration.half,
        syllables: ['szó', 'tag'],
        chord: 'D',
        tieStart: true,
        dotted: true,
      );
      final decoded =
          NotatedBeat.fromJson(json.decode(json.encode(beat.toJson())));
      expect(decoded.pitch, beat.pitch);
      expect(decoded.duration, beat.duration);
      expect(decoded.syllables, beat.syllables);
      expect(decoded.chord, beat.chord);
      expect(decoded.tieStart, isTrue);
      expect(decoded.tieEnd, isFalse);
      expect(decoded.dotted, isTrue);
    });
  });

  group('NotatedBeat behavior', () {
    test('isRest recognizes R case-insensitively', () {
      expect(const NotatedBeat(pitch: 'R', duration: NoteDuration.quarter)
          .isRest, isTrue);
      expect(const NotatedBeat(pitch: 'r', duration: NoteDuration.quarter)
          .isRest, isTrue);
      expect(const NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter)
          .isRest, isFalse);
    });

    test('parsedPitch splits note and octave', () {
      expect(const NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter)
          .parsedPitch, ('C', 4));
      expect(const NotatedBeat(pitch: 'Bb5', duration: NoteDuration.quarter)
          .parsedPitch, ('BB', 5));
      expect(const NotatedBeat(pitch: 'f#3', duration: NoteDuration.quarter)
          .parsedPitch, ('F#', 3));
    });

    test('parsedPitch is null for rests and invalid pitches', () {
      expect(const NotatedBeat(pitch: 'R', duration: NoteDuration.quarter)
          .parsedPitch, isNull);
      expect(const NotatedBeat(pitch: 'X9', duration: NoteDuration.quarter)
          .parsedPitch, isNull);
      expect(const NotatedBeat(pitch: 'C', duration: NoteDuration.quarter)
          .parsedPitch, isNull);
    });

    test('actualBeats applies the dotted multiplier', () {
      expect(const NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter)
          .actualBeats, 1.0);
      expect(
        const NotatedBeat(
          pitch: 'C4',
          duration: NoteDuration.quarter,
          dotted: true,
        ).actualBeats,
        1.5,
      );
      expect(
        const NotatedBeat(
          pitch: 'C4',
          duration: NoteDuration.half,
          dotted: true,
        ).actualBeats,
        3.0,
      );
    });

    test('allSyllables prefers syllables over syllable', () {
      expect(
        const NotatedBeat(
          pitch: 'C4',
          duration: NoteDuration.quarter,
          syllable: 'single',
          syllables: ['v1', 'v2'],
        ).allSyllables,
        ['v1', 'v2'],
      );
      expect(
        const NotatedBeat(
          pitch: 'C4',
          duration: NoteDuration.quarter,
          syllable: 'single',
        ).allSyllables,
        ['single'],
      );
      expect(
        const NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter)
            .allSyllables,
        isEmpty,
      );
      // Empty syllables list falls back to single syllable.
      expect(
        const NotatedBeat(
          pitch: 'C4',
          duration: NoteDuration.quarter,
          syllable: 's',
          syllables: [],
        ).allSyllables,
        ['s'],
      );
    });

    test('copyWith overrides fields', () {
      const beat = NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter);
      expect(beat.copyWith(pitch: 'D4').pitch, 'D4');
      expect(beat.copyWith(duration: NoteDuration.half).duration,
          NoteDuration.half);
      expect(beat.copyWith(dotted: true).dotted, isTrue);
      expect(beat.copyWith(chord: 'G').chord, 'G');
    });
  });

  group('NotatedMeasure', () {
    test('fromJson defaults', () {
      final measure = NotatedMeasure.fromJson({
        'beats': [
          {'pitch': 'C4', 'duration': 'quarter'},
        ],
      });
      expect(measure.repeatStart, isFalse);
      expect(measure.repeatEnd, isFalse);
      expect(measure.lineBreakAfter, isFalse);
      expect(measure.beats, hasLength(1));
    });

    test('totalBeats sums actual (dotted-aware) beats', () {
      const measure = NotatedMeasure(beats: [
        NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter),
        NotatedBeat(pitch: 'D4', duration: NoteDuration.quarter, dotted: true),
        NotatedBeat(pitch: 'E4', duration: NoteDuration.eighth),
      ]);
      expect(measure.totalBeats, 1.0 + 1.5 + 0.5);
    });

    test('totalBeats is 0 for an empty measure', () {
      expect(const NotatedMeasure(beats: []).totalBeats, 0.0);
    });
  });

  group('NotatedVerse', () {
    test('allBeats flattens measures in order', () {
      const verse = NotatedVerse(number: 1, measures: [
        NotatedMeasure(beats: [
          NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter),
          NotatedBeat(pitch: 'D4', duration: NoteDuration.quarter),
        ]),
        NotatedMeasure(beats: [
          NotatedBeat(pitch: 'E4', duration: NoteDuration.quarter),
        ]),
      ]);
      expect(verse.allBeats.map((b) => b.pitch), ['C4', 'D4', 'E4']);
    });
  });

  group('SongNotation', () {
    test('fromJson with pickup and defaults', () {
      final notation = SongNotation.fromJson({
        'originalKey': 'G',
        'timeSignature': '3/4',
        'verses': <dynamic>[],
        'pickup': [
          {'pitch': 'D4', 'duration': 'quarter'},
        ],
      });
      expect(notation.originalKey, 'G');
      expect(notation.showTimeSignature, isTrue);
      expect(notation.pickup, hasLength(1));
    });

    test('parsedTimeSignature splits numerator and denominator', () {
      const notation = SongNotation(
        originalKey: 'C',
        timeSignature: '6/8',
        verses: [],
      );
      expect(notation.parsedTimeSignature, (6, 8));
      expect(notation.beatsPerMeasure, 6);
    });

    test('round-trips through encoded JSON', () {
      const notation = SongNotation(
        originalKey: 'Bb',
        timeSignature: '4/4',
        showTimeSignature: false,
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
              beats: [
                NotatedBeat(pitch: 'Bb4', duration: NoteDuration.quarter),
              ],
              repeatEnd: true,
              lineBreakAfter: true,
            ),
          ]),
        ],
        pickup: [NotatedBeat(pitch: 'F4', duration: NoteDuration.eighth)],
      );
      final decoded =
          SongNotation.fromJson(json.decode(json.encode(notation.toJson())));
      expect(decoded.originalKey, 'Bb');
      expect(decoded.showTimeSignature, isFalse);
      expect(decoded.verses.single.measures.single.repeatEnd, isTrue);
      expect(decoded.verses.single.measures.single.lineBreakAfter, isTrue);
      expect(decoded.pickup?.single.pitch, 'F4');
    });
  });
}
