import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/chord_position.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/domain/services/chord_sheet_exporter.dart';
import 'package:songbook_app/domain/services/chord_sheet_parser.dart';

/// Copying a song out as ChordPro.
///
/// The format is chosen so that what leaves the app can come back into it — the
/// paste importer reads exactly this. So the test that matters is a round trip,
/// not a string comparison.

const exporter = ChordSheetExporter();
const parser = ChordSheetParser();

Song song() => const Song(
      number: 42,
      title: 'Mint a szép híves patakra',
      reference: 'Zsolt 42',
      originalKey: 'Bb',
      verses: [
        Verse(number: 1, lines: [
          LyricLine(
            text: 'Mint a szép híves patakra',
            chords: [
              ChordPosition(chord: 'Bb', position: 0),
              ChordPosition(chord: 'F', position: 12),
            ],
          ),
          LyricLine(text: 'A szarvas kívánkozik'),
        ]),
        Verse(number: 2, plainText: 'Második versszak szövege'),
      ],
    );

void main() {
  test('brackets each chord back in at its own character index', () {
    final text = exporter.toChordPro(song());

    expect(text, contains('[Bb]Mint a szép [F]híves patakra'));
  });

  test('carries the title, key and reference as directives', () {
    final text = exporter.toChordPro(song());

    expect(text, contains('{title: Mint a szép híves patakra}'));
    expect(text, contains('{key: Bb}'));
    expect(text, contains('{c: Zsolt 42}'));
  });

  test('a plain-text verse goes out as it came in', () {
    // It has no chord positions to place, so re-wrapping it into something else
    // would be inventing structure that was never there.
    expect(exporter.toChordPro(song()), contains('Második versszak szövege'));
  });

  test('round-trips through the parser', () {
    final reparsed = parser.parse(exporter.toChordPro(song()));

    expect(reparsed.title, 'Mint a szép híves patakra');
    expect(reparsed.key, 'Bb');
    // Verse 1's lines and chords survive exactly — same text, same columns.
    final first = reparsed.verses.first.lines.first;
    expect(first.text, 'Mint a szép híves patakra');
    expect(first.chords, const [
      ChordPosition(chord: 'Bb', position: 0),
      ChordPosition(chord: 'F', position: 12),
    ]);
    expect(reparsed.verses.first.lines[1].text, 'A szarvas kívánkozik');
  });

  test('a chord overhanging a short lyric is kept, not dropped', () {
    // The parser deliberately does not clamp positions to the text length, so a
    // chord may sit past the end of its line; the exporter must not lose it.
    const overhanging = Song(
      number: 1,
      title: 'T',
      originalKey: 'C',
      verses: [
        Verse(number: 1, lines: [
          LyricLine(text: 'Rövid', chords: [
            ChordPosition(chord: 'G', position: 40),
          ]),
        ]),
      ],
    );

    expect(exporter.toChordPro(overhanging), contains('Rövid[G]'));
  });
}
