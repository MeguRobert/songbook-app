import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/domain/services/musicxml_importer.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_layout.dart';

/// An anacrusis (pickup / upbeat) — the partial bar a hymn often opens on.
///
/// The handoff this work resumed from recorded that `SongNotation.pickup` was
/// read by nothing and that "an upbeat hymn therefore renders its anacrusis as a
/// full bar". The second half is wrong, and these tests pin why: a pickup bar
/// simply *is* a measure with fewer beats, and the layout engine spaces measures
/// from their content rather than to a fixed width, so it already comes out
/// narrow. `SongNotation.pickup` is a parallel representation that no producer
/// has ever written.
///
/// What was genuinely missing is the *flag*. MusicXML marks the bar
/// `implicit="yes"`, the importer dropped that, and without it nothing downstream
/// can tell a legitimate upbeat from a bar where OMR lost a note — which the
/// correction editor flags in red. Both are short; only one is wrong.

/// A one-beat implicit opening bar, then a full 4/4 bar.
const _withPickup = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
  <part id="P1">
    <measure number="0" implicit="yes">
      <attributes><divisions>1</divisions><key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <note><pitch><step>G</step><octave>3</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
    <measure number="1">
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
  </part>
</score-partwise>
''';

/// The same shape, but the short bar is NOT declared implicit — a bar that is
/// simply missing a beat.
const _shortButNotImplicit = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>1</divisions><key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <note><pitch><step>G</step><octave>3</octave></pitch><duration>1</duration><type>quarter</type></note>
    </measure>
    <measure number="2">
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
    </measure>
  </part>
</score-partwise>
''';

SheetMusicLayout layoutOf(SongNotation notation) {
  return SheetMusicLayoutEngine(
    availableWidth: 800,
    transposePitch: (pitch, _) => pitch,
    transposeChord: (chord, _) => chord,
    showChords: false,
  ).calculateLayout(notation, 0);
}

void main() {
  const importer = MusicXmlImporter();

  group('importing', () {
    test('an implicit opening bar becomes a short leading measure', () {
      final notation = importer.importXml(_withPickup).notation;
      final measures = notation.verses.single.measures;

      expect(measures, hasLength(2));
      expect(measures.first.beats.map((b) => b.pitch), ['G3']);
      expect(measures.first.totalBeats, 1.0);
      expect(measures[1].totalBeats, 4.0);
      // NOT the parallel `pickup` list. A pickup bar is a measure; representing
      // it twice is what left the field dead and the behaviour unexplained.
      expect(notation.pickup, isNull);
    });

    test('and is marked as the pickup it was declared to be', () {
      final measures = importer.importXml(_withPickup).notation.verses.single.measures;

      expect(measures.first.isPickup, isTrue);
      expect(measures[1].isPickup, isFalse);
    });

    test('the flag survives the line-break pass', () {
      // `_applyLineBreaks` rebuilds the measures it marks, field by field, so
      // every new field on NotatedMeasure is one this pass can silently drop.
      // Forcing a break on the pickup bar itself is the case that would.
      final measures = importer
          .importXml(_withPickup, measuresPerLine: 1)
          .notation
          .verses
          .single
          .measures;

      expect(measures.first.lineBreakAfter, isTrue,
          reason: 'the test needs the rebuild to actually happen');
      expect(measures.first.isPickup, isTrue);
    });

    test('a short bar that is not declared implicit is not a pickup', () {
      // This is the case the flag exists to separate: same short bar, but here it
      // means a beat is missing, and nothing should excuse it.
      final measures =
          importer.importXml(_shortButNotImplicit).notation.verses.single.measures;

      expect(measures.first.totalBeats, 1.0);
      expect(measures.first.isPickup, isFalse);
    });
  });

  group('engraving', () {
    test('the pickup bar is laid out narrower than a full bar', () {
      // The claim being pinned: content-driven spacing already engraves an
      // anacrusis correctly, with no special case anywhere in the renderer.
      final layout = layoutOf(importer.importXml(_withPickup).notation);
      final barLines = layout.systems.single.barLines.map((b) => b.x).toList();

      expect(barLines, hasLength(3),
          reason: 'opening line, end of pickup, end of the full bar');
      final pickupWidth = barLines[1] - barLines[0];
      final fullWidth = barLines[2] - barLines[1];
      expect(pickupWidth, lessThan(fullWidth / 2));
    });

    test('the flag changes nothing about the engraving', () {
      // isPickup is information for the editor, not an instruction to the
      // renderer — the geometry has to stay identical either way.
      final flagged = importer.importXml(_withPickup).notation;
      final unflagged = SongNotation(
        originalKey: flagged.originalKey,
        timeSignature: flagged.timeSignature,
        verses: [
          NotatedVerse(
            number: 1,
            measures: [
              for (final m in flagged.verses.single.measures)
                NotatedMeasure(beats: m.beats),
            ],
          ),
        ],
      );

      expect(layoutOf(flagged).systems.single.notes.map((n) => n.x),
          layoutOf(unflagged).systems.single.notes.map((n) => n.x));
    });
  });

  group('persistence', () {
    test('the flag survives a round-trip', () {
      const measure = NotatedMeasure(
        beats: [NotatedBeat(pitch: 'G3', duration: NoteDuration.quarter)],
        isPickup: true,
      );
      // Through jsonEncode, not `fromJson(toJson())`: the generated `toJson`
      // leaves nested beats as objects for `jsonEncode` to convert, so the
      // shorter round-trip does not type-check at runtime.
      final decoded = NotatedMeasure.fromJson(
          jsonDecode(jsonEncode(measure.toJson())) as Map<String, dynamic>);
      expect(decoded.isPickup, isTrue);
      expect(decoded.beats.single.pitch, 'G3');
    });

    test('a measure stored before the flag existed reads as not a pickup', () {
      final legacy = NotatedMeasure.fromJson({
        'beats': [
          {'pitch': 'C4', 'duration': 'quarter'},
        ],
      });
      expect(legacy.isPickup, isFalse);
    });

    test('it is part of value equality', () {
      // Every other field of these classes is, for the reason at the top of
      // notation.dart: an edit that compares equal is a change nothing can see.
      const beats = [NotatedBeat(pitch: 'G3', duration: NoteDuration.quarter)];
      expect(const NotatedMeasure(beats: beats, isPickup: true),
          isNot(const NotatedMeasure(beats: beats)));
    });
  });
}
