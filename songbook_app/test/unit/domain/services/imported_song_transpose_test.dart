import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/domain/services/chord_sheet_parser.dart';
import 'package:songbook_app/domain/services/transposition_service.dart';

/// Transposing a song that came in as pasted text.
///
/// The reported symptom was "after adding a song with chords I cannot transpose
/// it — it does not recognise the chords". The cause was upstream of
/// transposition: a punctuated chord row (`C - D`, `| C | G |`) failed the
/// all-tokens-must-be-chords test, so it was stored as a line of *lyrics*. There
/// were no chords to transpose, and nothing said so.
///
/// This walks the whole chain the app walks — parse, build the song, transpose
/// every stored chord — because each half passed its own tests while the join
/// between them was where the song broke.

const _parser = ChordSheetParser();
const _transposer = TranspositionService();

/// Every chord in [song], transposed by [semitones], in reading order.
List<String> transposed(Song song, int semitones) => [
      for (final verse in song.verses)
        for (final line in verse.lines)
          for (final chord in line.chords)
            _transposer.transposeChord(chord.chord, semitones),
    ];

Song songFrom(String pasted) {
  final parsed = _parser.parse(pasted);
  return Song(
    number: 1,
    title: 'Teszt',
    originalKey: parsed.key ?? 'C',
    verses: parsed.verses,
  );
}

void main() {
  test('a dash-separated chord row transposes', () {
    final song = songFrom('C   -   G\nAz Úrra bízom életem');

    expect(song.hasChords, isTrue,
        reason: 'the row has to be chords before anything can transpose it');
    expect(transposed(song, 2), ['D', 'A']);
  });

  test('a bar-line chord row transposes', () {
    final song = songFrom('| C | G | Am | F |\nAz Úrra bízom életem');

    expect(transposed(song, 2), ['D', 'A', 'Bm', 'G']);
  });

  test('a parenthesised chord transposes like any other', () {
    final song = songFrom('C  (Em)  F\nAz Úrra bízom életem');

    expect(transposed(song, 2), ['D', 'F#m', 'G']);
  });

  test('a repeat marker is not transposed as if it were a chord', () {
    // `x2` starts with no note letter, so it was never at risk of becoming a
    // chord — but it must not survive into the stored chords either, or the
    // chord row prints "x2" above the lyric as though it were one.
    final song = songFrom('C  G  x2\nAz Úrra bízom életem');

    expect(transposed(song, 0), ['C', 'G']);
  });

  test('inline brackets still transpose, punctuation or not', () {
    final song = songFrom('[C]Az Úrra [G]bízom életem');

    expect(transposed(song, 2), ['D', 'A']);
  });

  test('a lyric line that merely contains a dash is left alone', () {
    // The guard that matters: separators must not turn words into chords.
    final song = songFrom('Az Úrra - bízom életem');

    expect(song.hasChords, isFalse);
    expect(song.verses.single.lines.single.text, 'Az Úrra - bízom életem');
  });
}
