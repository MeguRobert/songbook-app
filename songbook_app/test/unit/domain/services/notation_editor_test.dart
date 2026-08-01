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

    test('keeps the score’s other voices', () {
      // A four-part score came back from one corrected note with its alto, tenor
      // and bass gone: this rebuilt SongNotation field by field and `voices` was
      // added after that code was written, so every beat edit dropped it and
      // reading the bass line meant finding and re-importing the source file.
      // The same shape of hole that had already cost `isPickup` twice.
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'C5', duration: NoteDuration.quarter),
            ]),
          ]),
        ],
        voices: [
          NotatedVoice(name: 'Bass', measures: [
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'C3', duration: NoteDuration.quarter),
            ]),
          ]),
        ],
      );

      final after = editor.replaceBeat(
        before,
        const BeatAddress(verse: 0, measure: 0, beat: 0),
        const NotatedBeat(pitch: 'D5', duration: NoteDuration.quarter),
      );

      expect(after.verses.first.measures.first.beats.single.pitch, 'D5');
      expect(after.voices, before.voices);
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
              isPickup: true,
              volta: 2,
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
      // isPickup and volta were both silently dropped: this rebuilt the measure
      // field by field, so every field added to the model was one an edit lost.
      // A pickup bar corrected in the editor came back flagged as a short bar
      // the transcription had damaged — the one thing isPickup exists to
      // prevent.
      expect(measure.isPickup, isTrue);
      expect(measure.volta, 2);
    });

    test('is a no-op for an address out of range', () {
      final before = twoMeasures();
      expect(
          editor.deleteBeat(
              before, const BeatAddress(verse: 0, measure: 1, beat: 5)),
          before);
    });
  });

  group('splitMeasure', () {
    test('the addressed beat starts a new measure', () {
      // The operation that fixes a mis-barred import. Audiveris returned ONE
      // measure per system on the real SÉ-90 output — six bars of 18 beats in
      // 4/4 — so what the reader needs is a bar line, not a corrected note.
      final after = editor.splitMeasure(
          twoMeasures(), const BeatAddress(verse: 0, measure: 0, beat: 1));

      expect(after.verses.first.measures, hasLength(3));
      expect(after.verses.first.measures[0].beats.map((b) => b.pitch), ['C4']);
      expect(after.verses.first.measures[1].beats.map((b) => b.pitch), ['D4']);
      expect(after.verses.first.measures[2].beats.map((b) => b.pitch), ['E4']);
      // No note is lost, invented or reordered — only a bar line moved.
      expect(pitches(after), pitches(twoMeasures()));
    });

    test('keeps the syllables on the beats they belong to', () {
      final after = editor.splitMeasure(
          twoMeasures(), const BeatAddress(verse: 0, measure: 0, beat: 1));

      expect(after.verses.first.measures[0].beats.single.syllable, 'Az');
      expect(after.verses.first.measures[1].beats.single.syllable, 'Úr-');
    });

    test('gives the bar’s opening to the first half and its close to the second',
        () {
      // repeatStart opens a bar; repeatEnd and a system break close one. A bar
      // carrying `:‖:` splits into a repeated section two bars long, which is
      // what the signs meant in the first place.
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
              volta: 2,
            ),
          ]),
        ],
      );

      final after = editor.splitMeasure(
          before, const BeatAddress(verse: 0, measure: 0, beat: 1));
      final first = after.verses.first.measures[0];
      final second = after.verses.first.measures[1];

      expect(first.repeatStart, isTrue);
      expect(first.repeatEnd, isFalse);
      expect(first.lineBreakAfter, isFalse);
      expect(second.repeatStart, isFalse);
      expect(second.repeatEnd, isTrue);
      expect(second.lineBreakAfter, isTrue);
      // A run of measures sharing a number IS the bracket, so both halves stay
      // under it — otherwise splitting inside a volta loses half the bracket.
      expect(first.volta, 2);
      expect(second.volta, 2);
    });

    test('does not label the second half a pickup', () {
      // The trap. `isPickup` means "short on purpose", and the editor answers it
      // by showing neither the arithmetic nor the warning. Copying it onto both
      // halves would put a bar in the middle of the score behind a Pickup label
      // and exempt it from the one check that catches a lost beat — hiding a
      // damaged bar behind the flag that exists to tell the two apart.
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
              isPickup: true,
              beats: [
                NotatedBeat(pitch: 'G3', duration: NoteDuration.quarter),
                NotatedBeat(pitch: 'A3', duration: NoteDuration.quarter),
              ],
            ),
          ]),
        ],
      );

      final after = editor.splitMeasure(
          before, const BeatAddress(verse: 0, measure: 0, beat: 1));

      expect(after.verses.first.measures[0].isPickup, isTrue);
      expect(after.verses.first.measures[1].isPickup, isFalse);
    });

    test('is a no-op on the first beat, which would leave an empty half', () {
      final before = twoMeasures();
      expect(
          editor.splitMeasure(
              before, const BeatAddress(verse: 0, measure: 0, beat: 0)),
          before);
    });

    test('is a no-op for an address out of range', () {
      final before = twoMeasures();
      expect(
          editor.splitMeasure(
              before, const BeatAddress(verse: 0, measure: 0, beat: 9)),
          before);
      expect(
          editor.splitMeasure(
              before, const BeatAddress(verse: 9, measure: 0, beat: 1)),
          before);
    });

    test('splits the other voices at the same point in musical time', () {
      // Voices are aligned measure for measure — the contract the importer
      // establishes by rest-padding them, and what `engravedAs` relies on to hand
      // a bass line the melody's repeats and voltas. Splitting only the melody
      // would shift every bar of every other voice by one.
      //
      // At the same POINT IN TIME, not the same beat index: a bar line falls
      // where it falls, and the melody's four quarters and the bass's two halves
      // occupy the same bar.
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'C5', duration: NoteDuration.quarter),
              NotatedBeat(pitch: 'D5', duration: NoteDuration.quarter),
              NotatedBeat(pitch: 'E5', duration: NoteDuration.quarter),
              NotatedBeat(pitch: 'F5', duration: NoteDuration.quarter),
            ]),
          ]),
        ],
        voices: [
          NotatedVoice(name: 'Bass', measures: [
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'C3', duration: NoteDuration.half),
              NotatedBeat(pitch: 'G3', duration: NoteDuration.half),
            ]),
          ]),
        ],
      );

      final after = editor.splitMeasure(
          before, const BeatAddress(verse: 0, measure: 0, beat: 2));
      final bass = after.voices!.single.measures;

      expect(after.verses.first.measures, hasLength(2));
      expect(bass, hasLength(2));
      expect(bass[0].beats.map((b) => b.pitch), ['C3']);
      expect(bass[1].beats.map((b) => b.pitch), ['G3']);
    });

    test('keeps a voice note that straddles the new bar line in the first bar',
        () {
      // A whole note cannot be divided without splitting the note, and dropping
      // it would lose a note. It starts before the new bar line, so that is the
      // bar it belongs to; the second bar comes out empty, which the layout
      // engine and `engravedAs` both already handle.
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'C5', duration: NoteDuration.quarter),
              NotatedBeat(pitch: 'D5', duration: NoteDuration.quarter),
            ]),
          ]),
        ],
        voices: [
          NotatedVoice(name: 'Bass', measures: [
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'C3', duration: NoteDuration.whole),
            ]),
          ]),
        ],
      );

      final after = editor.splitMeasure(
          before, const BeatAddress(verse: 0, measure: 0, beat: 1));
      final bass = after.voices!.single.measures;

      expect(bass, hasLength(2));
      expect(bass[0].beats.map((b) => b.pitch), ['C3']);
      expect(bass[1].beats, isEmpty);
    });

    test('re-bars the real SÉ-90 shape into 4/4 bars', () {
      // The measured case: Audiveris returned one measure per system, and 18 is
      // not a multiple of 4, so the durations were mis-read too. Four splits at
      // the fourth beat give 4+4+4+4 and a two-beat remainder — exactly the
      // remainder `--rebar` leaves and the validator names, and now the only bar
      // the editor flags.
      var notation = SongNotation(
        originalKey: 'Bb',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(beats: [
              for (var i = 0; i < 18; i++)
                const NotatedBeat(pitch: 'D4', duration: NoteDuration.quarter),
            ]),
          ]),
        ],
      );

      for (var bar = 0; bar < 4; bar++) {
        notation = editor.splitMeasure(
            notation, BeatAddress(verse: 0, measure: bar, beat: 4));
      }

      expect(notation.verses.first.measures.map((m) => m.totalBeats).toList(),
          [4.0, 4.0, 4.0, 4.0, 2.0]);
      expect(notation.verses.first.allBeats, hasLength(18));
    });
  });

  group('mergeMeasureIntoPrevious', () {
    test('appends its beats to the bar before it', () {
      // The inverse of a split, and the fix for the other half of mis-barring:
      // OMR reads one bar as two when a system breaks inside it.
      final after = editor.mergeMeasureIntoPrevious(
          twoMeasures(), const MeasureAddress(verse: 0, measure: 1));

      expect(after.verses.first.measures, hasLength(1));
      expect(pitches(after), ['C4', 'D4', 'E4']);
    });

    test('takes the opening from the first bar and the close from the second',
        () {
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
              beats: [NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter)],
              repeatStart: true,
              volta: 1,
            ),
            NotatedMeasure(
              beats: [NotatedBeat(pitch: 'D4', duration: NoteDuration.quarter)],
              repeatEnd: true,
              lineBreakAfter: true,
            ),
          ]),
        ],
      );

      final merged = editor
          .mergeMeasureIntoPrevious(
              before, const MeasureAddress(verse: 0, measure: 1))
          .verses
          .first
          .measures
          .single;

      expect(merged.repeatStart, isTrue);
      expect(merged.repeatEnd, isTrue);
      expect(merged.lineBreakAfter, isTrue);
      // The merged bar starts where the first one did, so it is under the
      // bracket the first one was under.
      expect(merged.volta, 1);
    });

    test('stops calling the result a pickup once it is no longer short', () {
      // Whether a SHORT bar is an upbeat or a damaged one is exactly the
      // ambiguity `isPickup` exists to answer, and this does not touch that. But
      // an anacrusis is by definition shorter than a full bar, so a merged bar
      // that now meets the time signature is not one whatever it used to be —
      // and leaving the flag on would exempt a full bar from the arithmetic for
      // good.
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
              isPickup: true,
              beats: [NotatedBeat(pitch: 'G3', duration: NoteDuration.quarter)],
            ),
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'C4', duration: NoteDuration.half),
              NotatedBeat(pitch: 'D4', duration: NoteDuration.quarter),
            ]),
          ]),
        ],
      );

      final merged = editor
          .mergeMeasureIntoPrevious(
              before, const MeasureAddress(verse: 0, measure: 1))
          .verses
          .first
          .measures
          .single;

      expect(merged.totalBeats, 4.0);
      expect(merged.isPickup, isFalse);
    });

    test('keeps the pickup flag while the merged bar is still short', () {
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
              isPickup: true,
              beats: [NotatedBeat(pitch: 'G3', duration: NoteDuration.eighth)],
            ),
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'A3', duration: NoteDuration.eighth),
            ]),
          ]),
        ],
      );

      final merged = editor
          .mergeMeasureIntoPrevious(
              before, const MeasureAddress(verse: 0, measure: 1))
          .verses
          .first
          .measures
          .single;

      expect(merged.totalBeats, 1.0);
      expect(merged.isPickup, isTrue);
    });

    test('is a no-op on the first measure, which has nothing before it', () {
      final before = twoMeasures();
      expect(
          editor.mergeMeasureIntoPrevious(
              before, const MeasureAddress(verse: 0, measure: 0)),
          before);
    });

    test('merges the same pair in every other voice', () {
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C5', duration: NoteDuration.half)]),
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'D5', duration: NoteDuration.half)]),
          ]),
        ],
        voices: [
          NotatedVoice(name: 'Bass', measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C3', duration: NoteDuration.half)]),
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'G3', duration: NoteDuration.half)]),
          ]),
        ],
      );

      final after = editor.mergeMeasureIntoPrevious(
          before, const MeasureAddress(verse: 0, measure: 1));

      expect(after.verses.first.measures, hasLength(1));
      expect(after.voices!.single.measures, hasLength(1));
      expect(after.voices!.single.measures.single.beats.map((b) => b.pitch),
          ['C3', 'G3']);
    });
  });

  group('insertMeasure', () {
    test('after puts a new bar behind the addressed one', () {
      final after = editor.insertMeasureAfter(
          twoMeasures(), const MeasureAddress(verse: 0, measure: 0));

      expect(after.verses.first.measures, hasLength(3));
      expect(after.verses.first.measures[0].beats.map((b) => b.pitch),
          ['C4', 'D4']);
      expect(after.verses.first.measures[2].beats.map((b) => b.pitch), ['E4']);
    });

    test('before puts one in front, which is the only way to regain bar 1', () {
      // OMR routinely mishandles the first bar of a page, and an anacrusis is the
      // most commonly lost one. Nothing else in this editor can produce a bar
      // ahead of the first.
      final after = editor.insertMeasureBefore(
          twoMeasures(), const MeasureAddress(verse: 0, measure: 0));

      expect(after.verses.first.measures, hasLength(3));
      expect(after.verses.first.measures[1].beats.map((b) => b.pitch),
          ['C4', 'D4']);
    });

    test('the new bar holds one rest, so it can actually be corrected', () {
      // Not empty. `deleteBeat` leaves an empty bar behind deliberately, and the
      // beat list has no row to address in one — so an empty bar is a bar you can
      // never put a note into. One rest at the beat unit gives the list a row,
      // the edit sheet turns it into a note, and `insertBeatAfter` fills the rest
      // of the bar from there.
      final measure = editor
          .insertMeasureAfter(
              twoMeasures(), const MeasureAddress(verse: 0, measure: 0))
          .verses
          .first
          .measures[1];

      expect(measure.beats, hasLength(1));
      expect(measure.beats.single.isRest, isTrue);
      expect(measure.beats.single.duration, NoteDuration.quarter);
    });

    test('the beat unit follows the time signature', () {
      const in68 = SongNotation(
        originalKey: 'C',
        timeSignature: '6/8',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(beats: [
              NotatedBeat(pitch: 'C4', duration: NoteDuration.eighth),
            ]),
          ]),
        ],
      );

      final measure = editor
          .insertMeasureAfter(in68, const MeasureAddress(verse: 0, measure: 0))
          .verses
          .first
          .measures[1];

      expect(measure.beats.single.duration, NoteDuration.eighth);
    });

    test('the new bar carries no repeat, volta, break or pickup flag', () {
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
              beats: [NotatedBeat(pitch: 'C4', duration: NoteDuration.quarter)],
              repeatStart: true,
              repeatEnd: true,
              lineBreakAfter: true,
              isPickup: true,
              volta: 1,
            ),
          ]),
        ],
      );

      final measure = editor
          .insertMeasureAfter(before, const MeasureAddress(verse: 0, measure: 0))
          .verses
          .first
          .measures[1];

      // Inherited flags would put a repeat sign where the score has none, and an
      // inherited `isPickup` would exempt the new bar from the arithmetic.
      expect(measure.repeatStart, isFalse);
      expect(measure.repeatEnd, isFalse);
      expect(measure.lineBreakAfter, isFalse);
      expect(measure.isPickup, isFalse);
      expect(measure.volta, isNull);
    });

    test('inserts a matching bar into every other voice', () {
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C5', duration: NoteDuration.whole)]),
          ]),
        ],
        voices: [
          NotatedVoice(name: 'Bass', measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C3', duration: NoteDuration.whole)]),
          ]),
        ],
      );

      final after = editor.insertMeasureAfter(
          before, const MeasureAddress(verse: 0, measure: 0));

      expect(after.verses.first.measures, hasLength(2));
      expect(after.voices!.single.measures, hasLength(2));
      expect(after.voices!.single.measures[1].beats.single.isRest, isTrue);
    });

    test('is a no-op for an address out of range', () {
      final before = twoMeasures();
      expect(
          editor.insertMeasureAfter(
              before, const MeasureAddress(verse: 0, measure: 9)),
          before);
    });
  });

  group('deleteMeasure', () {
    test('removes the bar and everything in it', () {
      // The only way out of the empty bar `deleteBeat` leaves behind, and the fix
      // for a bar OMR invented outright.
      final after = editor.deleteMeasure(
          twoMeasures(), const MeasureAddress(verse: 0, measure: 0));

      expect(after.verses.first.measures, hasLength(1));
      expect(pitches(after), ['E4']);
    });

    test('removes the same bar from every other voice', () {
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C5', duration: NoteDuration.whole)]),
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'D5', duration: NoteDuration.whole)]),
          ]),
        ],
        voices: [
          NotatedVoice(name: 'Bass', measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C3', duration: NoteDuration.whole)]),
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'G3', duration: NoteDuration.whole)]),
          ]),
        ],
      );

      final after = editor.deleteMeasure(
          before, const MeasureAddress(verse: 0, measure: 0));

      expect(after.verses.first.measures.single.beats.single.pitch, 'D5');
      expect(after.voices!.single.measures.single.beats.single.pitch, 'G3');
    });

    test('keeps the last measure, so a verse never loses its staff', () {
      // An empty measure list gives the layout engine nothing to lay out, and
      // there would be no row left to insert a bar from.
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C4', duration: NoteDuration.whole)]),
          ]),
        ],
      );

      expect(
          editor.deleteMeasure(
              before, const MeasureAddress(verse: 0, measure: 0)),
          before);
    });

    test('is a no-op for an address out of range', () {
      final before = twoMeasures();
      expect(
          editor.deleteMeasure(
              before, const MeasureAddress(verse: 0, measure: 9)),
          before);
    });
  });

  group('setMeasureFlags', () {
    const address = MeasureAddress(verse: 0, measure: 0);

    SongNotation oneBar({bool isPickup = false, int? volta}) => SongNotation(
          originalKey: 'C',
          timeSignature: '4/4',
          verses: [
            NotatedVerse(number: 1, measures: [
              NotatedMeasure(
                isPickup: isPickup,
                volta: volta,
                beats: const [
                  NotatedBeat(pitch: 'C4', duration: NoteDuration.whole),
                ],
              ),
            ]),
          ],
        );

    test('sets the repeat signs, the system break and the pickup flag', () {
      // An imported score frequently gets these wrong and there is no other way
      // to correct them: the editor preserved them and could not change them.
      final measure = editor
          .setMeasureFlags(oneBar(), address,
              repeatStart: true,
              repeatEnd: true,
              lineBreakAfter: true,
              isPickup: true,
              volta: 2)
          .verses
          .first
          .measures
          .single;

      expect(measure.repeatStart, isTrue);
      expect(measure.repeatEnd, isTrue);
      expect(measure.lineBreakAfter, isTrue);
      expect(measure.isPickup, isTrue);
      expect(measure.volta, 2);
      // The music is untouched: this edits the bar, not what is in it.
      expect(measure.beats.single.pitch, 'C4');
    });

    test('can take a volta bracket off again', () {
      // The case a plain `copyWith` cannot express: `volta: null` falls through
      // the `??` and keeps the old number, so a bracket the OMR invented would
      // have been impossible to remove.
      final measure = editor
          .setMeasureFlags(oneBar(volta: 2), address,
              repeatStart: false,
              repeatEnd: false,
              lineBreakAfter: false,
              isPickup: false,
              volta: null)
          .verses
          .first
          .measures
          .single;

      expect(measure.volta, isNull);
    });

    test('can clear the pickup flag, which is what makes a short bar a warning',
        () {
      // Both directions matter. Declaring a short bar an upbeat silences the
      // warning; un-declaring it puts the warning back, and an `isPickup` the
      // importer got wrong would otherwise hide a lost beat for good.
      final measure = editor
          .setMeasureFlags(oneBar(isPickup: true), address,
              repeatStart: false,
              repeatEnd: false,
              lineBreakAfter: false,
              isPickup: false,
              volta: null)
          .verses
          .first
          .measures
          .single;

      expect(measure.isPickup, isFalse);
    });

    test('leaves the other voices alone', () {
      // Repeats, voltas and system breaks belong to the BAR, not to the line
      // singing it, and only the engraved stream carries them — `engravedAs`
      // projects them onto whichever voice is being read.
      const before = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C5', duration: NoteDuration.whole)]),
          ]),
        ],
        voices: [
          NotatedVoice(name: 'Bass', measures: [
            NotatedMeasure(
                beats: [NotatedBeat(pitch: 'C3', duration: NoteDuration.whole)]),
          ]),
        ],
      );

      final after = editor.setMeasureFlags(before, address,
          repeatStart: true,
          repeatEnd: false,
          lineBreakAfter: false,
          isPickup: false,
          volta: null);

      expect(after.verses.first.measures.single.repeatStart, isTrue);
      expect(after.voices, before.voices);
    });

    test('is a no-op for an address out of range', () {
      final before = oneBar();
      expect(
          editor.setMeasureFlags(before, const MeasureAddress(verse: 0, measure: 9),
              repeatStart: true,
              repeatEnd: true,
              lineBreakAfter: true,
              isPickup: true,
              volta: 1),
          before);
    });
  });

  group('the voice list', () {
    const satb = SongNotation(
      originalKey: 'C',
      timeSignature: '4/4',
      verses: [
        NotatedVerse(number: 1, measures: [
          NotatedMeasure(
              beats: [NotatedBeat(pitch: 'C5', duration: NoteDuration.whole)]),
        ]),
      ],
      voices: [
        NotatedVoice(name: 'P2', measures: [
          NotatedMeasure(
              beats: [NotatedBeat(pitch: 'E4', duration: NoteDuration.whole)]),
        ]),
        NotatedVoice(name: 'P3', measures: [
          NotatedMeasure(
              beats: [NotatedBeat(pitch: 'C3', duration: NoteDuration.whole)]),
        ]),
      ],
    );

    test('renameVoice relabels one without touching its music', () {
      // Audiveris names parts `P1`, `P2`, `P3` and those names are what the voice
      // picker in the song controls offers a singer.
      final after = editor.renameVoice(satb, 1, 'Basszus');

      expect(after.voices!.map((v) => v.name), ['P2', 'Basszus']);
      expect(after.voices![1].measures, satb.voices![1].measures);
      expect(after.verses, satb.verses);
    });

    test('renameVoice ignores a blank name rather than erasing the label', () {
      expect(editor.renameVoice(satb, 0, '   '), satb);
    });

    test('removeVoice drops just that one', () {
      final after = editor.removeVoice(satb, 0);

      expect(after.voices!.map((v) => v.name), ['P3']);
      expect(after.verses, satb.verses);
    });

    test('removing the last voice leaves an empty list, not a broken picker',
        () {
      // `copyWith` cannot write null, and it does not need to: an empty list
      // behaves identically everywhere — `hasMultipleVoices` is false,
      // `voiceNames` is just the melody, and `engravedAs` returns the score
      // unchanged for any index.
      var after = editor.removeVoice(satb, 0);
      after = editor.removeVoice(after, 0);

      expect(after.voices, isEmpty);
      expect(after.hasMultipleVoices, isFalse);
      expect(after.voiceNames, ['Melody']);
      expect(after.engravedAs(1), after);
    });

    test('both are a no-op for an index out of range', () {
      expect(editor.renameVoice(satb, 9, 'Bass'), satb);
      expect(editor.removeVoice(satb, -1), satb);
      expect(
          editor.removeVoice(
              const SongNotation(
                  originalKey: 'C', timeSignature: '4/4', verses: []),
              0),
          const SongNotation(
              originalKey: 'C', timeSignature: '4/4', verses: []));
    });
  });

  group('MeasureAddress', () {
    test('is a value, like BeatAddress and for the same reason', () {
      expect(const MeasureAddress(verse: 0, measure: 1),
          const MeasureAddress(verse: 0, measure: 1));
      expect(const MeasureAddress(verse: 0, measure: 1).hashCode,
          const MeasureAddress(verse: 0, measure: 1).hashCode);
      expect(const MeasureAddress(verse: 0, measure: 1),
          isNot(const MeasureAddress(verse: 1, measure: 1)));
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
