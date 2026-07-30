import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/domain/services/musicxml_importer.dart';

/// Wraps [body] in the boilerplate every fixture needs, so each test only
/// spells out the part it is actually about.
String score({
  String header = '',
  String partList =
      '<part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>',
  required String body,
}) {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  $header
  $partList
  $body
</score-partwise>
''';
}

String attributes({
  int fifths = 0,
  String? mode,
  int beats = 4,
  int beatType = 4,
  int divisions = 1,
  int? staves,
}) {
  return '''
      <attributes>
        <divisions>$divisions</divisions>
        <key><fifths>$fifths</fifths>${mode == null ? '' : '<mode>$mode</mode>'}</key>
        <time><beats>$beats</beats><beat-type>$beatType</beat-type></time>
        ${staves == null ? '' : '<staves>$staves</staves>'}
      </attributes>''';
}

String note(
  String step,
  int octave, {
  String type = 'quarter',
  int alter = 0,
  int duration = 1,
  String? voice,
  int? staff,
  bool chord = false,
  bool dot = false,
  String? tie,
  String? lyric,
  String? syllabic,
  String? lyricNumber,
}) {
  return '''
      <note>
        ${chord ? '<chord/>' : ''}
        <pitch><step>$step</step>${alter == 0 ? '' : '<alter>$alter</alter>'}<octave>$octave</octave></pitch>
        <duration>$duration</duration>
        ${tie == null ? '' : '<tie type="$tie"/>'}
        ${voice == null ? '' : '<voice>$voice</voice>'}
        <type>$type</type>
        ${dot ? '<dot/>' : ''}
        ${staff == null ? '' : '<staff>$staff</staff>'}
        ${tie == null ? '' : '<notations><tied type="$tie"/></notations>'}
        ${lyric == null ? '' : '''<lyric number="${lyricNumber ?? '1'}">
          ${syllabic == null ? '' : '<syllabic>$syllabic</syllabic>'}
          <text>$lyric</text>
        </lyric>'''}
      </note>''';
}

String rest({String type = 'quarter', int duration = 1, String? voice}) {
  return '''
      <note>
        <rest/>
        <duration>$duration</duration>
        ${voice == null ? '' : '<voice>$voice</voice>'}
        <type>$type</type>
      </note>''';
}

/// A `<barline>`, the element that carries repeat signs and volta brackets.
///
/// `location` is genuinely optional in MusicXML and defaults to `right`, so it is
/// nullable here rather than defaulted — a fixture that omits it is testing that
/// the importer applies the same default.
String barline({
  String? location,
  String? repeat,
  String? endingNumber,
  String? endingType,
}) {
  return '''
      <barline${location == null ? '' : ' location="$location"'}>
        ${endingType == null ? '' : '<ending number="${endingNumber ?? '1'}" type="$endingType"/>'}
        ${repeat == null ? '' : '<repeat direction="$repeat"/>'}
      </barline>''';
}

/// Packs [entries] into an in-memory zip, the way a real `.mxl` is laid out.
List<int> zip(Map<String, String> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive)!;
}

void main() {
  const importer = MusicXmlImporter();

  List<NotatedBeat> beatsOf(SongNotation notation) =>
      notation.verses.single.allBeats;

  group('monophonic melody', () {
    final xml = score(
      header: '<work><work-title>Mint a szép híves patakra</work-title></work>',
      body: '''
  <part id="P1">
    <measure number="1">
      ${attributes(fifths: -2, beats: 3, beatType: 4)}
      ${note('G', 4, lyric: 'Mint')}
      ${note('B', 4, alter: -1, lyric: 'a')}
      ${note('C', 5, lyric: 'szép')}
    </measure>
    <measure number="2">
      ${note('D', 5, type: 'half', duration: 2, lyric: 'hí', syllabic: 'begin')}
      ${note('C', 5, lyric: 'ves', syllabic: 'end')}
    </measure>
  </part>''',
    );

    test('reads title, key, time signature and measures', () {
      final result = importer.importXml(xml);

      expect(result.title, 'Mint a szép híves patakra');
      expect(result.key, 'Bb');
      expect(result.timeSignature, '3/4');
      expect(result.notation.originalKey, 'Bb');
      expect(result.notation.timeSignature, '3/4');
      expect(result.notation.showTimeSignature, isFalse);
      expect(result.notation.verses.single.number, 1);
      expect(result.notation.verses.single.measures, hasLength(2));
    });

    test('maps pitch, accidentals and duration onto beats', () {
      final beats = beatsOf(importer.importXml(xml).notation);

      expect(beats.map((b) => b.pitch), ['G4', 'Bb4', 'C5', 'D5', 'C5']);
      expect(beats.map((b) => b.duration), [
        NoteDuration.quarter,
        NoteDuration.quarter,
        NoteDuration.quarter,
        NoteDuration.half,
        NoteDuration.quarter,
      ]);
    });

    test('carries syllables, hyphenating mid-word ones', () {
      final beats = beatsOf(importer.importXml(xml).notation);

      expect(beats.map((b) => b.syllable), ['Mint', 'a', 'szép', 'hí-', 'ves']);
      // A single lyric line stays in `syllable`; `syllables` is for stacking.
      expect(beats.every((b) => b.syllables == null), isTrue);
    });

    test('rebuilds a Verse whose words re-join across syllable hyphens', () {
      final result = importer.importXml(xml);

      expect(result.verses, hasLength(1));
      expect(result.verses.single.number, 1);
      expect(result.verses.single.hasNotation, isTrue);
      expect(result.verses.single.displayText, 'Mint a szép híves');
    });

    test('reports no warnings for a clean single-voice file', () {
      expect(importer.importXml(xml).warnings, isEmpty);
      expect(importer.importXml(xml).additionalVoices, isEmpty);
    });

    test('minor mode resolves to the relative minor key name', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes(fifths: -1, mode: 'minor')}
      ${note('D', 4)}
    </measure>
  </part>'''));

      expect(result.key, 'Dm');
    });

    test('rests become "R" beats', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('G', 4)}
      ${rest()}
    </measure>
  </part>'''));

      final beats = beatsOf(result.notation);
      expect(beats.map((b) => b.pitch), ['G4', 'R']);
      expect(beats.last.isRest, isTrue);
    });
  });

  group('dots and ties', () {
    final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes(divisions: 2)}
      ${note('G', 4, type: 'quarter', duration: 3, dot: true)}
      ${note('A', 4, type: 'eighth', duration: 1)}
      ${note('B', 4, type: 'half', duration: 4, tie: 'start')}
    </measure>
    <measure number="2">
      ${note('B', 4, type: 'half', duration: 4, tie: 'stop')}
      ${note('C', 5, type: '16th', duration: 1)}
    </measure>
  </part>'''));

    test('a <dot> sets dotted and 1.5x the beat value', () {
      final first = beatsOf(result.notation).first;

      expect(first.dotted, isTrue);
      expect(first.duration, NoteDuration.quarter);
      expect(first.actualBeats, 1.5);
    });

    test('undotted notes stay undotted', () {
      expect(beatsOf(result.notation)[1].dotted, isFalse);
    });

    test('tie start and stop land on the right beats', () {
      final beats = beatsOf(result.notation);

      expect(beats[2].tieStart, isTrue);
      expect(beats[2].tieEnd, isFalse);
      expect(beats[3].tieEnd, isTrue);
      expect(beats[3].tieStart, isFalse);
    });

    test('16th maps to the sixteenth enum value', () {
      expect(beatsOf(result.notation).last.duration, NoteDuration.sixteenth);
    });

    test('a missing <type> is derived from duration/divisions', () {
      final derived = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      <attributes><divisions>4</divisions></attributes>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>8</duration></note>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>6</duration></note>
    </measure>
  </part>'''));

      final beats = beatsOf(derived.notation);
      expect(beats[0].duration, NoteDuration.half);
      expect(beats[0].dotted, isFalse);
      expect(beats[1].duration, NoteDuration.quarter);
      expect(beats[1].dotted, isTrue);
    });

    test('a note value the model cannot draw is approximated with a warning', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('G', 4, type: '32nd')}
    </measure>
  </part>'''));

      expect(beatsOf(result.notation).single.duration, NoteDuration.sixteenth);
      expect(result.warnings.join(), contains('32nd'));
    });
  });

  group('harmony', () {
    test('a <harmony> attaches its chord to the following note', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      <harmony>
        <root><root-step>B</root-step><root-alter>-1</root-alter></root>
        <kind>major</kind>
      </harmony>
      ${note('D', 5, lyric: 'Ó')}
      ${note('D', 5)}
      <harmony>
        <root><root-step>F</root-step></root>
        <kind>dominant</kind>
      </harmony>
      ${note('C', 5)}
    </measure>
  </part>'''));

      final beats = beatsOf(result.notation);
      expect(beats.map((b) => b.chord), ['Bb', null, 'F7']);
    });

    test('minor and slash chords keep their suffix and bass', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      <harmony>
        <root><root-step>G</root-step></root>
        <kind>minor</kind>
      </harmony>
      ${note('G', 4)}
      <harmony>
        <root><root-step>C</root-step></root>
        <kind>major</kind>
        <bass><bass-step>E</bass-step></bass>
      </harmony>
      ${note('E', 4)}
    </measure>
  </part>'''));

      expect(beatsOf(result.notation).map((b) => b.chord), ['Gm', 'C/E']);
    });

    test('the printed kind text wins over the kind name', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      <harmony>
        <root><root-step>A</root-step></root>
        <kind text="m7">minor-seventh</kind>
      </harmony>
      ${note('A', 4)}
    </measure>
  </part>'''));

      expect(beatsOf(result.notation).single.chord, 'Am7');
    });

    test('chord symbols reach the rebuilt verse as ChordPositions', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      <harmony><root><root-step>C</root-step></root><kind>major</kind></harmony>
      ${note('C', 5, lyric: 'Szent')}
      <harmony><root><root-step>G</root-step></root><kind>major</kind></harmony>
      ${note('D', 5, lyric: 'Is', syllabic: 'begin')}
      ${note('E', 5, lyric: 'ten', syllabic: 'end')}
    </measure>
  </part>'''));

      final line = result.verses.single.lines.single;
      expect(line.text, 'Szent Isten');
      expect(line.chords.map((c) => c.chord), ['C', 'G']);
      expect(line.chords.map((c) => c.position), [0, 6]);
    });
  });

  group('SATB reduction', () {
    /// One part, two staves: staff 1 holds soprano (voice 1) and alto
    /// (voice 2), staff 2 holds tenor (voice 5) and bass (voice 6) — the
    /// standard closed-score hymnal layout.
    final closedScore = score(
      partList:
          '<part-list><score-part id="P1"><part-name>Chorus</part-name></score-part></part-list>',
      body: '''
  <part id="P1">
    <measure number="1">
      ${attributes(staves: 2)}
      ${note('G', 5, voice: '1', staff: 1, lyric: 'Szent')}
      ${note('A', 5, voice: '1', staff: 1, lyric: 'Is', syllabic: 'begin')}
      <backup><duration>2</duration></backup>
      ${note('D', 5, voice: '2', staff: 1)}
      ${note('D', 5, voice: '2', staff: 1)}
      <backup><duration>2</duration></backup>
      ${note('B', 4, voice: '5', staff: 2)}
      ${note('C', 5, voice: '5', staff: 2)}
      <backup><duration>2</duration></backup>
      ${note('G', 3, voice: '6', staff: 2)}
      ${note('F', 3, voice: '6', staff: 2)}
    </measure>
  </part>''',
    );

    test('voice 1 of the top staff of the first part becomes the melody', () {
      final result = importer.importXml(closedScore);

      expect(beatsOf(result.notation).map((b) => b.pitch), ['G5', 'A5']);
      expect(result.melody, isNotNull);
      expect(result.melody!.partId, 'P1');
      expect(result.melody!.staff, 1);
      expect(result.melody!.voiceId, '1');
    });

    test('the other three voices are retained, not dropped', () {
      final result = importer.importXml(closedScore);

      expect(result.additionalVoices, hasLength(3));
      expect(
        result.additionalVoices.map((v) => '${v.staff}/${v.voiceId}'),
        ['1/2', '2/5', '2/6'],
      );
      expect(
        result.additionalVoices
            .map((v) => v.measures.single.beats.map((b) => b.pitch).toList()),
        [
          ['D5', 'D5'],
          ['B4', 'C5'],
          ['G3', 'F3'],
        ],
      );
    });

    test('a warning names how many extra voices were found', () {
      final warnings = importer.importXml(closedScore).warnings;

      expect(warnings, isNotEmpty);
      expect(warnings.first, contains('3 additional voices'));
      expect(warnings.first, contains('additionalVoices'));
    });

    test('four separate parts reduce to the first part', () {
      String voicePart(String id, String name, String step, int octave) => '''
  <part id="$id">
    <measure number="1">
      ${attributes()}
      ${note(step, octave)}
    </measure>
  </part>''';

      final result = importer.importXml(score(
        partList: '''<part-list>
          <score-part id="P1"><part-name>Soprano</part-name></score-part>
          <score-part id="P2"><part-name>Alto</part-name></score-part>
          <score-part id="P3"><part-name>Tenor</part-name></score-part>
          <score-part id="P4"><part-name>Bass</part-name></score-part>
        </part-list>''',
        body: '${voicePart('P1', 'Soprano', 'G', 5)}\n'
            '${voicePart('P2', 'Alto', 'D', 5)}\n'
            '${voicePart('P3', 'Tenor', 'B', 4)}\n'
            '${voicePart('P4', 'Bass', 'G', 3)}',
      ));

      expect(beatsOf(result.notation).single.pitch, 'G5');
      expect(result.melody!.partName, 'Soprano');
      expect(
        result.additionalVoices.map((v) => v.partName),
        ['Alto', 'Tenor', 'Bass'],
      );
    });

    test('a <chord> keeps its top note and retains the lower ones', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('C', 5, lyric: 'Ó')}
      ${note('E', 4, chord: true)}
      ${note('G', 4, chord: true)}
      ${note('D', 5)}
    </measure>
  </part>'''));

      expect(beatsOf(result.notation).map((b) => b.pitch), ['C5', 'D5']);
      // The lyric was written on the stem note; it must survive the reduction.
      expect(beatsOf(result.notation).first.syllable, 'Ó');

      expect(result.additionalVoices, hasLength(2));
      expect(
        result.additionalVoices.map((v) => v.voiceId),
        ['1#2', '1#3'],
      );
      // The second beat had no chord notes, so the retained lines are padded
      // with rests and stay aligned with the melody.
      expect(
        result.additionalVoices
            .map((v) => v.measures.single.beats.map((b) => b.pitch).toList()),
        [
          ['G4', 'R'],
          ['E4', 'R'],
        ],
      );
      expect(result.warnings.join(), contains('reduced to the top note'));
    });

    test('multiple lyric lines stack into syllables and separate Verses', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      <note>
        <pitch><step>G</step><octave>4</octave></pitch>
        <duration>1</duration><type>quarter</type>
        <lyric number="1"><text>Szent</text></lyric>
        <lyric number="2"><text>Nagy</text></lyric>
      </note>
      <note>
        <pitch><step>A</step><octave>4</octave></pitch>
        <duration>1</duration><type>quarter</type>
        <lyric number="1"><text>Isten</text></lyric>
        <lyric number="2"><text>Úr</text></lyric>
      </note>
    </measure>
  </part>'''));

      final beats = beatsOf(result.notation);
      expect(beats.first.syllables, ['Szent', 'Nagy']);
      expect(beats.last.syllables, ['Isten', 'Úr']);

      expect(result.verses.map((v) => v.number), [1, 2]);
      expect(result.verses.map((v) => v.displayText), ['Szent Isten', 'Nagy Úr']);
      expect(result.verses.map((v) => v.hasNotation), [true, false]);
    });
  });

  group('line breaks', () {
    String bars(int count, {bool withSystemBreaks = false}) {
      final buffer = StringBuffer();
      for (var i = 1; i <= count; i++) {
        buffer.writeln('''
    <measure number="$i">
      ${i == 1 ? attributes() : ''}
      ${withSystemBreaks && i == 4 ? '<print new-system="yes"/>' : ''}
      ${note('G', 4)}
    </measure>''');
      }
      return '<part id="P1">$buffer</part>';
    }

    test('falls back to a break every N measures, never on the last', () {
      final measures = importer
          .importXml(score(body: bars(5)), measuresPerLine: 2)
          .notation
          .verses
          .single
          .measures;

      expect(measures.map((m) => m.lineBreakAfter), [
        false, true, false, true, false, //
      ]);
    });

    test('measuresPerLine 1 breaks after every measure but the last', () {
      final measures = importer
          .importXml(score(body: bars(3)), measuresPerLine: 1)
          .notation
          .verses
          .single
          .measures;

      expect(measures.map((m) => m.lineBreakAfter), [true, true, false]);
    });

    test('measuresPerLine 0 adds no breaks at all', () {
      final measures = importer
          .importXml(score(body: bars(4)), measuresPerLine: 0)
          .notation
          .verses
          .single
          .measures;

      expect(measures.every((m) => !m.lineBreakAfter), isTrue);
    });

    test("the file's own system breaks win over the fallback rule", () {
      final measures = importer
          .importXml(score(body: bars(5, withSystemBreaks: true)),
              measuresPerLine: 2)
          .notation
          .verses
          .single
          .measures;

      // new-system on bar 4 means the break belongs after bar 3.
      expect(measures.map((m) => m.lineBreakAfter), [
        false, false, true, false, false, //
      ]);
    });
  });

  group('.mxl', () {
    const inner = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <part-list><score-part id="P1"><part-name>Voice</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1">
      <attributes><divisions>1</divisions><key><fifths>2</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time></attributes>
      <note><pitch><step>A</step><octave>4</octave></pitch><duration>1</duration>
        <type>quarter</type><lyric number="1"><text>Áldjad</text></lyric></note>
    </measure>
  </part>
</score-partwise>''';

    test('finds the score named by META-INF/container.xml', () {
      final bytes = zip({
        'META-INF/container.xml': '''<?xml version="1.0" encoding="UTF-8"?>
<container><rootfiles>
  <rootfile full-path="score/hymn.xml" media-type="application/vnd.recordare.musicxml+xml"/>
</rootfiles></container>''',
        'score/hymn.xml': inner,
        'decoy.xml': '<score-partwise><part id="P9"/></score-partwise>',
      });

      final result = importer.importCompressed(bytes);

      expect(result.key, 'D');
      expect(beatsOf(result.notation).single.pitch, 'A4');
      expect(result.verses.single.displayText, 'Áldjad');
    });

    test('falls back to the first non-META-INF xml when there is no manifest',
        () {
      final result = importer.importCompressed(zip({'hymn.musicxml': inner}));

      expect(beatsOf(result.notation).single.pitch, 'A4');
    });

    test('round-trips the same model as the uncompressed source', () {
      final fromZip = importer.importCompressed(zip({'hymn.xml': inner}));
      final fromText = importer.importXml(inner);

      expect(fromZip.notation, fromText.notation);
    });

    test('an archive with no score reports a clean error', () {
      expect(
        () => importer.importCompressed(zip({'META-INF/container.xml': '<c/>'})),
        throwsA(isA<MusicXmlImportException>().having(
          (e) => e.message,
          'message',
          contains('no MusicXML score entry'),
        )),
      );
    });

    test('bytes that are not a zip report a clean error', () {
      expect(
        () => importer.importCompressed(utf8.encode('this is not a zip')),
        throwsA(isA<MusicXmlImportException>()),
      );
    });

    test('empty bytes report a clean error', () {
      expect(
        () => importer.importCompressed(const []),
        throwsA(isA<MusicXmlImportException>().having(
          (e) => e.message,
          'message',
          contains('empty'),
        )),
      );
    });
  });

  group('malformed input', () {
    test('empty input throws instead of crashing', () {
      expect(
        () => importer.importXml('   '),
        throwsA(isA<MusicXmlImportException>().having(
          (e) => e.message,
          'message',
          contains('empty'),
        )),
      );
    });

    test('unclosed XML throws a MusicXmlImportException, not an XmlException',
        () {
      expect(
        () => importer.importXml('<score-partwise><part id="P1">'),
        throwsA(isA<MusicXmlImportException>().having(
          (e) => e.message,
          'message',
          contains('not valid XML'),
        )),
      );
    });

    test('valid XML with no notes warns rather than throwing', () {
      final result = importer.importXml(score(body: '<part id="P1"/>'));

      expect(result.notation.verses.single.measures, isEmpty);
      expect(result.melody, isNull);
      expect(result.verses, isEmpty);
      expect(result.warnings, contains('No notes were found in the file.'));
    });

    test('a score without key or time falls back but reports them as absent',
        () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">${note('G', 4)}</measure>
  </part>'''));

      expect(result.key, isNull);
      expect(result.timeSignature, isNull);
      expect(result.notation.originalKey, 'C');
      expect(result.notation.timeSignature, '4/4');
    });

    test('a namespaced document parses the same as a bare one', () {
      final result = importer.importXml('''<?xml version="1.0"?>
<score-partwise xmlns="http://www.musicxml.org/ns" version="4.0">
  <part id="P1">
    <measure number="1">
      <attributes><divisions>1</divisions><key><fifths>1</fifths></key>
        <time><beats>3</beats><beat-type>4</beat-type></time></attributes>
      <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration>
        <type>quarter</type></note>
    </measure>
  </part>
</score-partwise>''');

      expect(result.key, 'G');
      expect(result.timeSignature, '3/4');
      expect(beatsOf(result.notation).single.pitch, 'E5');
    });

    test('grace notes are skipped with a warning', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      <note><grace/><pitch><step>F</step><octave>4</octave></pitch><type>eighth</type></note>
      ${note('G', 4)}
    </measure>
  </part>'''));

      expect(beatsOf(result.notation).map((b) => b.pitch), ['G4']);
      expect(result.warnings.join(), contains('grace note'));
    });

    test('an .mxl container manifest passed as a score is rejected clearly', () {
      expect(
        () => importer.importXml('<container><rootfiles/></container>'),
        throwsA(isA<MusicXmlImportException>().having(
          (e) => e.message,
          'message',
          contains('importCompressed'),
        )),
      );
    });
  });

  // Hymns repeat constantly — the refrain, the second half, a whole verse — and
  // every repeat sign in an imported score used to be dropped on the floor:
  // `_readMeasure` handled <attributes>, <print>, <harmony> and <note>, and
  // nothing else. NotatedMeasure had carried repeatStart/repeatEnd all along.
  group('repeats and endings', () {
    List<NotatedMeasure> measuresOf(SongNotation notation) =>
        notation.verses.single.measures;

    test('a backward repeat on the right barline closes a repeat', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('G', 4)}
      ${barline(location: 'right', repeat: 'backward')}
    </measure>
    <measure number="2">
      ${note('A', 4)}
    </measure>
  </part>'''));

      final measures = measuresOf(result.notation);
      expect(measures[0].repeatEnd, isTrue);
      expect(measures[1].repeatEnd, isFalse);
    });

    test('a forward repeat on the left barline opens a repeat', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('G', 4)}
    </measure>
    <measure number="2">
      ${barline(location: 'left', repeat: 'forward')}
      ${note('A', 4)}
    </measure>
  </part>'''));

      final measures = measuresOf(result.notation);
      expect(measures[0].repeatStart, isFalse);
      expect(measures[1].repeatStart, isTrue);
    });

    test('a barline with no location defaults to the right of the measure', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('G', 4)}
      ${barline(repeat: 'backward')}
    </measure>
  </part>'''));

      expect(measuresOf(result.notation).single.repeatEnd, isTrue);
      expect(measuresOf(result.notation).single.repeatStart, isFalse);
    });

    test('an ending marks every measure under its bracket, not just the first',
        () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('G', 4)}
    </measure>
    <measure number="2">
      ${barline(location: 'left', endingNumber: '1', endingType: 'start')}
      ${note('A', 4)}
    </measure>
    <measure number="3">
      ${note('B', 4)}
      ${barline(location: 'right', endingNumber: '1', endingType: 'stop', repeat: 'backward')}
    </measure>
    <measure number="4">
      ${barline(location: 'left', endingNumber: '2', endingType: 'start')}
      ${note('C', 5)}
    </measure>
  </part>'''));

      final measures = measuresOf(result.notation);
      expect(measures.map((m) => m.volta), [null, 1, 1, 2]);
    });

    test('a discontinued ending still closes the bracket', () {
      // `discontinue` is the open-ended second-time bar: the bracket has no
      // downward hook at its right end. It still ends the run of measures.
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${barline(location: 'left', endingNumber: '2', endingType: 'start')}
      ${note('G', 4)}
      ${barline(location: 'right', endingNumber: '2', endingType: 'discontinue')}
    </measure>
    <measure number="2">
      ${note('A', 4)}
    </measure>
  </part>'''));

      expect(measuresOf(result.notation).map((m) => m.volta), [2, null]);
    });

    test('an ending number the file writes as a list keeps the first', () {
      // "1,2" is legal and means the bracket covers both passes. The model holds
      // one number, so the lowest is what gets drawn.
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${barline(location: 'left', endingNumber: '1, 2', endingType: 'start')}
      ${note('G', 4)}
      ${barline(location: 'right', endingNumber: '1, 2', endingType: 'stop')}
    </measure>
  </part>'''));

      expect(measuresOf(result.notation).single.volta, 1);
    });

    test('repeats survive the line-breaking pass', () {
      // `_applyLineBreaks` and `_markPickups` both rebuild measures. They use
      // copyWith for exactly this reason — isPickup was silently dropped by a
      // field-by-field rebuild once already.
      final result = importer.importXml(
        score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('G', 4)}
      ${barline(location: 'right', repeat: 'backward')}
    </measure>
    <measure number="2">
      ${barline(location: 'left', repeat: 'forward')}
      ${note('A', 4)}
    </measure>
    <measure number="3">
      ${note('B', 4)}
    </measure>
  </part>'''),
        measuresPerLine: 1,
      );

      final measures = measuresOf(result.notation);
      expect(measures[0].lineBreakAfter, isTrue, reason: 'the fixture premise');
      expect(measures[0].repeatEnd, isTrue);
      expect(measures[1].repeatStart, isTrue);
    });

    test('a score with no barline elements reports no repeats', () {
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('G', 4)}
    </measure>
  </part>'''));

      final measure = measuresOf(result.notation).single;
      expect(measure.repeatStart, isFalse);
      expect(measure.repeatEnd, isFalse);
      expect(measure.volta, isNull);
    });
  });

  // The importer recovered every voice from the start and the app then dropped
  // all but the melody: nothing stored `additionalVoices`, so reading a bass
  // line meant finding and re-importing the source file.
  group('voices reach the stored notation', () {
    List<NotatedMeasure> measuresOf(SongNotation notation) =>
        notation.verses.single.measures;

    /// One part, one staff, four voices stacked as a <chord> — the shape a
    /// hymnal SATB score most often takes.
    String satb() => score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('C', 5)}
      ${note('G', 4, chord: true)}
      ${note('E', 4, chord: true)}
      ${note('C', 4, chord: true)}
    </measure>
  </part>''');

    test('the extra voices are stored, not only held in the result', () {
      final result = importer.importXml(satb());

      expect(result.additionalVoices, hasLength(3),
          reason: 'the fixture premise');
      expect(result.notation.voices, hasLength(3));
    });

    test('four voices are named SATB, top down', () {
      final result = importer.importXml(satb());

      expect(result.notation.voiceNames,
          ['Melody', 'Alto', 'Tenor', 'Bass']);
    });

    test('each stored voice carries its own pitches', () {
      final result = importer.importXml(satb());

      final pitches = result.notation.voices!
          .map((v) => v.measures.single.beats.single.pitch)
          .toList();
      expect(pitches, ['G4', 'E4', 'C4']);
      // And the engraved stream is still the top note.
      expect(beatsOf(result.notation).single.pitch, 'C5');
    });

    test('any stored voice can be engraved in place of the melody', () {
      final notation = importer.importXml(satb()).notation;

      expect(notation.engravedAs(3).verses.single.measures.single.beats.single
          .pitch, 'C4');
    });

    test('a single-voice score stores no voice list at all', () {
      // Null rather than empty: a picker with one entry is noise, and
      // hasMultipleVoices is what the controls sheet keys off.
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('G', 4)}
    </measure>
  </part>'''));

      expect(result.notation.voices, isNull);
      expect(result.notation.hasMultipleVoices, isFalse);
    });

    test('a count other than four falls back to the file’s own labels', () {
      // SATB naming is a convention about four-part hymns. Two voices could be
      // anything, so guessing "Alto" would be a lie the singer cannot check.
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('C', 5)}
      ${note('E', 4, chord: true)}
    </measure>
  </part>'''));

      expect(result.notation.voices, hasLength(1));
      expect(result.notation.voices!.single.name, isNot('Alto'));
      expect(result.notation.voices!.single.name, contains('P1'));
    });

    test('stored voices stay aligned measure-for-measure with the melody', () {
      // A voice silent for a bar gets that bar as an empty measure rather than
      // no measure, or switching voices would renumber every bar after it.
      final result = importer.importXml(score(body: '''
  <part id="P1">
    <measure number="1">
      ${attributes()}
      ${note('C', 5)}
      ${note('G', 4, chord: true)}
      ${note('E', 4, chord: true)}
      ${note('C', 4, chord: true)}
    </measure>
    <measure number="2">
      ${note('D', 5)}
    </measure>
  </part>'''));

      final melodyBars = measuresOf(result.notation).length;
      for (final voice in result.notation.voices!) {
        expect(voice.measures, hasLength(melodyBars), reason: voice.name);
      }
    });
  });

}
