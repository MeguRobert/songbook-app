import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/domain/services/notation_editor.dart';

/// The beat-level edit operations behind the notation-correction editor.
///
/// Kept pure and separate from the screen because this is where the errors are:
/// every path into the app's notation is a transcription — OMR guesses a pitch,
/// mis-reads a duration, drops a note, invents one — and correcting those is
/// index arithmetic over a nested list that no widget test would show clearly.
///
/// Address out of range is a no-op throughout, matching `SetlistRepository`'s
/// convention: stale indexes come from a screen that has been rebuilt, not from
/// a programming error, so they must not throw at the user.

SongNotation twoMeasures() => const SongNotation(
      originalKey: 'C',
      timeSignature: '4/4',
      verses: [
        NotatedVerse(number: 1, measures: [
          NotatedMeasure(beats: [
            NotatedBeat(
                pitch: 'C4', duration: NoteDuration.quarter, syllable: 'Az'),
            NotatedBeat(
                pitch: 'D4', duration: NoteDuration.quarter, syllable: 'Úr-'),
          ]),
          NotatedMeasure(beats: [
            NotatedBeat(
                pitch: 'E4', duration: NoteDuration.half, syllable: 'ra'),
          ]),
        ]),
      ],
    );

const editor = NotationEditor();

/// Every beat in [notation], flattened, for asserting nothing else moved.
List<String> pitches(SongNotation notation) => notation.verses
    .expand((v) => v.measures)
    .expand((m) => m.beats)
    .map((b) => b.pitch)
    .toList();

void main() {
  group('replaceBeat', () {
    test('swaps only the addressed beat', () {
      final before = twoMeasures();
      final after = editor.replaceBeat(
        before,
        const BeatAddress(verse: 0, measure: 0, beat: 1),
        const NotatedBeat(
            pitch: 'F4', duration: NoteDuration.eighth, syllable: 'Úr-'),
      );

      expect(pitches(after), ['C4', 'F4', 'E4']);
      expect(after.verses.first.measures.first.beats[1].duration,
          NoteDuration.eighth);
      // The first beat is untouched, not rebuilt with defaults.
      expect(after.verses.first.measures.first.beats.first,
          before.verses.first.measures.first.beats.first);
    });

    test('returns a notation that compares unequal to the original', () {
      // The whole feature rests on this: Riverpod and Flutter decide whether to
      // rebuild by comparing values, so an edited notation that still equals its
      // own previous version is a change nothing can see.
      final before = twoMeasures();
      final after = editor.replaceBeat(
        before,
        const BeatAddress(verse: 0, measure: 0, beat: 0),
        const NotatedBeat(pitch: 'G4', duration: NoteDuration.quarter),
      );

      expect(after, isNot(before));
    });

    test('leaves the key, time signature and pickup alone', () {
      const before = SongNotation(
        originalKey: 'Bb',
        timeSignature: '3/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter)]),
          ]),
        ],
        pickup: [NotatedBeat(pitch: 'G3', duration: NoteDuration.quarter)],
      );

      final after = editor.replaceBeat(
        before,
        const BeatAddress(verse: 0, measure: 0, beat: 0),
        const NotatedBeat(pitch: 'A4', duration: NoteDuration.half),
      );

      expect(after.originalKey, 'Bb');
      expect(after.timeSignature, '3/4');
      expect(after.pickup, before.pickup);
    });

    test('is a no-op for an address out of range', () {
      final before = twoMeasures();
      const replacement =
          NotatedBeat(pitch: 'G4', duration: NoteDuration.quarter);

      expect(
          editor.replaceBeat(before,
              const BeatAddress(verse: 0, measure: 0, beat: 9), replacement),
          before);
      expect(
          editor.replaceBeat(before,
              const BeatAddress(verse: 0, measure: 9, beat: 0), replacement),
          before);
      expect(
          editor.replaceBeat(before,
              const BeatAddress(verse: 9, measure: 0, beat: 0), replacement),
          before);
    });
  });

  group('insertBeatAfter', () {
    test('copies the addressed beat into the next slot', () {
      // A note the OMR dropped is nearly always next to one it read correctly,
      // so the neighbour's pitch and duration are the best starting point.
      final after = editor.insertBeatAfter(
          twoMeasures(), const BeatAddress(verse: 0, measure: 0, beat: 0));

      expect(pitches(after), ['C4', 'C4', 'D4', 'E4']);
      expect(after.verses.first.measures.first.beats[1].duration,
          NoteDuration.quarter);
    });

    test('does not copy the syllable, tie or chord', () {
      // The lyric belongs to the note that was already there. Copying it would
      // print the syllable twice and leave a tie dangling into a note that is
      // not the one it was tied to.
      const source = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(beats: [
              NotatedBeat(
                pitch: 'C4',
                duration: NoteDuration.quarter,
                syllable: 'Az',
                chord: 'C',
                tieStart: true,
                dotted: true,
              ),
            ]),
          ]),
        ],
      );

      final after = editor.insertBeatAfter(
          source, const BeatAddress(verse: 0, measure: 0, beat: 0));
      final inserted = after.verses.first.measures.first.beats[1];

      expect(inserted.pitch, 'C4');
      expect(inserted.duration, NoteDuration.quarter);
      expect(inserted.dotted, isTrue); // part of the duration, so kept
      expect(inserted.syllable, isNull);
      expect(inserted.chord, isNull);
      expect(inserted.tieStart, isFalse);
      expect(inserted.tieEnd, isFalse);
    });

    test('appends when the addressed beat is the last in its measure', () {
      final after = editor.insertBeatAfter(
          twoMeasures(), const BeatAddress(verse: 0, measure: 1, beat: 0));

      expect(pitches(after), ['C4', 'D4', 'E4', 'E4']);
      expect(after.verses.first.measures[1].beats, hasLength(2));
      // It goes into that measure, not into a new one.
      expect(after.verses.first.measures, hasLength(2));
    });

    test('is a no-op for an address out of range', () {
      final before = twoMeasures();
      expect(
          editor.insertBeatAfter(
              before, const BeatAddress(verse: 0, measure: 0, beat: 9)),
          before);
    });
  });

  group('deleteBeat', () {
    test('removes just that beat', () {
      final after = editor.deleteBeat(
          twoMeasures(), const BeatAddress(verse: 0, measure: 0, beat: 0));

      expect(pitches(after), ['D4', 'E4']);
    });

    test('keeps the measure when its last beat goes', () {
      // Measures are the unit the layout engine breaks systems on, and the
      // MusicXML importer keeps empty ones deliberately so the voices it
      // retained stay measure-aligned. Removing one here would desynchronise
      // them; an empty bar is recoverable, a missing one is not.
      final after = editor.deleteBeat(
          twoMeasures(), const BeatAddress(verse: 0, measure: 1, beat: 0));

      expect(after.verses.first.measures, hasLength(2));
      expect(after.verses.first.measures[1].beats, isEmpty);
    });

    test('preserves the measure flags of the measure it edits', () {
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
              beats: [
                NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter),
                NotatedBeat(pitch: 'D4', duration: NoteDuration.quarter),
              ],
              repeatStart: true,
              repeatEnd: true,
              lineBreakAfter: true,
            ),
          ]),
        ],
      );

      final after = editor.deleteBeat(
          before, const BeatAddress(verse: 0, measure: 0, beat: 0));
      final measure = after.verses.first.measures.first;

      expect(measure.repeatStart, isTrue);
      expect(measure.repeatEnd, isTrue);
      expect(measure.lineBreakAfter, isTrue);
    });

    test('is a no-op for an address out of range', () {
      final before = twoMeasures();
      expect(
          editor.deleteBeat(
              before, const BeatAddress(verse: 0, measure: 1, beat: 5)),
          before);
    });
  });

  group('BeatAddress', () {
    test('is a value, so two addresses to the same beat are equal', () {
      // The screen keeps one in state to mark the selected row; identity
      // equality would have made the selection never match.
      expect(const BeatAddress(verse: 0, measure: 1, beat: 2),
          const BeatAddress(verse: 0, measure: 1, beat: 2));
      expect(const BeatAddress(verse: 0, measure: 1, beat: 2).hashCode,
          const BeatAddress(verse: 0, measure: 1, beat: 2).hashCode);
      expect(const BeatAddress(verse: 0, measure: 1, beat: 2),
          isNot(const BeatAddress(verse: 0, measure: 2, beat: 1)));
    });
  });
}
