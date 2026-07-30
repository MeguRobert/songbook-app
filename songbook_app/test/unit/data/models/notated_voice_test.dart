import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';

/// The voices of a multi-voice score.
///
/// [SongNotation] renders one monophonic stream, and hymnal MusicXML is
/// four-voice SATB, so importing has always been a reduction to the top line.
/// The importer kept the other three in memory and the app then threw them away:
/// nothing stored them, so re-reading a bass line meant re-importing the file.
void main() {
  NotatedMeasure bar(String pitch) => NotatedMeasure(
        beats: [NotatedBeat(pitch: pitch, duration: NoteDuration.whole)],
      );

  SongNotation satb() => SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [bar('C5'), bar('D5')]),
        ],
        voices: [
          NotatedVoice(name: 'Alto', measures: [bar('G4'), bar('A4')]),
          NotatedVoice(name: 'Bass', measures: [bar('C3'), bar('D3')]),
        ],
      );

  group('NotatedVoice', () {
    test('carries value equality over its measures', () {
      // Notation is mutated by the import and the beat editor, so a copy that
      // compares equal to its original is a change no widget can see.
      expect(
        NotatedVoice(name: 'Alto', measures: [bar('G4')]),
        NotatedVoice(name: 'Alto', measures: [bar('G4')]),
      );
      expect(
        NotatedVoice(name: 'Alto', measures: [bar('G4')]),
        isNot(NotatedVoice(name: 'Alto', measures: [bar('A4')])),
      );
      expect(
        NotatedVoice(name: 'Alto', measures: [bar('G4')]),
        isNot(NotatedVoice(name: 'Tenor', measures: [bar('G4')])),
      );
    });

    test('round-trips through JSON', () {
      final decoded = SongNotation.fromJson(
        json.decode(json.encode(satb().toJson())) as Map<String, dynamic>,
      );

      expect(decoded.voices, hasLength(2));
      expect(decoded.voices!.first.name, 'Alto');
      expect(decoded.voices!.first.measures.first.beats.single.pitch, 'G4');
      expect(decoded, satb());
    });

    test('notation stored before voices existed still decodes', () {
      // Every song already on a device was written without the key. Losing
      // favourites and setlists to a renamed JSON key has happened here before.
      final decoded = SongNotation.fromJson({
        'originalKey': 'C',
        'timeSignature': '4/4',
        'verses': [
          {
            'number': 1,
            'measures': [
              {
                'beats': [
                  {'pitch': 'C5', 'duration': 'whole'}
                ]
              }
            ]
          }
        ],
      });

      expect(decoded.voices, isNull);
      expect(decoded.verses.single.measures, hasLength(1));
    });
  });

  group('voiceNames', () {
    test('names the engraved stream first, then the rest', () {
      expect(satb().voiceNames, ['Melody', 'Alto', 'Bass']);
    });

    test('a single-voice score names only its one stream', () {
      const single = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [NotatedVerse(number: 1, measures: [])],
      );

      expect(single.voiceNames, ['Melody']);
      expect(single.hasMultipleVoices, isFalse);
    });

    test('a score with extra voices says so', () {
      expect(satb().hasMultipleVoices, isTrue);
    });
  });

  group('engravedAs', () {
    test('index 0 is the score unchanged', () {
      expect(satb().engravedAs(0), satb());
    });

    test('a later index engraves that voice instead', () {
      final alto = satb().engravedAs(1);

      expect(alto.verses.single.measures.first.beats.single.pitch, 'G4');
      // Key, time signature and the voice list itself all survive, so the picker
      // still has something to offer and nothing else about the score moves.
      expect(alto.originalKey, 'C');
      expect(alto.timeSignature, '4/4');
      expect(alto.voices, hasLength(2));
    });

    test('projecting the stored score twice gives the same result', () {
      // The property that matters: this is applied to `song.notation` fresh on
      // every build, so it has to be stable, not chainable. Chaining it is
      // explicitly wrong — engravedAs(0) means "leave it alone", so applying it
      // to an already-swapped score returns the swapped voice.
      final stored = satb();
      expect(stored.engravedAs(2), stored.engravedAs(2));
      expect(stored.engravedAs(2).engravedAs(0), stored.engravedAs(2));
    });

    test('the swapped-in voice keeps the melody verse number', () {
      // The verse number identifies which set of words the notation belongs to.
      // It is a property of the song, not of the voice singing it.
      expect(satb().engravedAs(1).verses.single.number, 1);
    });

    test('an index past the end is the score unchanged, not a crash', () {
      expect(satb().engravedAs(9), satb());
      expect(satb().engravedAs(-1), satb());
    });

    test('the bar structure of the score comes with it', () {
      // A repeat sign, a volta bracket and a system break belong to the BAR, not
      // to the line singing it — every voice of a four-part score shares them.
      // Only the engraved stream gets them from the importer, so a projected
      // voice arrives with beats and nothing else: switching to the bass dropped
      // the repeats and the voltas off the staff entirely, and re-broke the
      // systems somewhere different from the melody's. Caught in a browser.
      final stored = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [
            NotatedMeasure(beats: [
              const NotatedBeat(pitch: 'C5', duration: NoteDuration.whole),
            ], repeatStart: true),
            NotatedMeasure(beats: [
              const NotatedBeat(pitch: 'D5', duration: NoteDuration.whole),
            ], volta: 1, repeatEnd: true, lineBreakAfter: true),
          ]),
        ],
        voices: [
          NotatedVoice(name: 'Bass', measures: [bar('C3'), bar('D3')]),
        ],
      );

      final bass = stored.engravedAs(1).verses.single.measures;

      expect(bass.map((m) => m.beats.single.pitch), ['C3', 'D3']);
      expect(bass[0].repeatStart, isTrue);
      expect(bass[1].repeatEnd, isTrue);
      expect(bass[1].volta, 1);
      expect(bass[1].lineBreakAfter, isTrue);
    });

    test('a voice with more bars than the melody keeps its extra ones', () {
      // Defensive: the importer pads voices to the melody's length, but a
      // hand-edited payload need not, and dropping bars would lose notes.
      final stored = SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [NotatedVerse(number: 1, measures: [bar('C5')])],
        voices: [
          NotatedVoice(name: 'Bass', measures: [bar('C3'), bar('D3')]),
        ],
      );

      expect(stored.engravedAs(1).verses.single.measures, hasLength(2));
    });
  });
}
