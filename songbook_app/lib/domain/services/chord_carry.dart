import '../../data/models/chord_position.dart';
import '../../data/models/lyric_line.dart';
import '../../data/models/verse.dart';

/// Copies the first verse's chords onto later verses that were printed without
/// them.
///
/// A songbook sets the chords over verse 1 and the remaining verses as words
/// alone, because a musician reading the page is expected to play the same
/// shape again. Every importer faithfully reproduces that, which leaves a song
/// whose second verse cannot be played from — and the second verse is exactly
/// where you are when you have stopped looking at the page and are looking at
/// the phone.
///
/// The copy is by line position, which is what the page means: verse 2's third
/// line is sung to verse 1's third line. It is a guess, but a guess the printed
/// page is already asking the reader to make.
///
/// Deliberately conservative in two ways. A verse that carries *any* chord of
/// its own is left completely alone — those were read off the page and a guess
/// must not overwrite them. And a verse held as [Verse.plainText] is skipped,
/// because there are no positions in it to attach a chord to.
class ChordCarry {
  const ChordCarry();

  /// [verses] with later chordless verses given the first verse's chords.
  List<Verse> carry(List<Verse> verses) {
    if (verses.length < 2) return verses;

    final source = verses.first.lines;
    if (!source.any((line) => line.chords.isNotEmpty)) return verses;

    return [
      verses.first,
      for (final verse in verses.skip(1))
        _hasNoChords(verse) ? _filled(verse, source) : verse,
    ];
  }

  bool _hasNoChords(Verse verse) =>
      verse.lines.isNotEmpty &&
      verse.lines.every((line) => line.chords.isEmpty);

  Verse _filled(Verse verse, List<LyricLine> source) => Verse(
        number: verse.number,
        hasNotation: verse.hasNotation,
        plainText: verse.plainText,
        lines: [
          for (var i = 0; i < verse.lines.length; i++)
            i < source.length
                ? _withChordsOf(verse.lines[i], source[i])
                : verse.lines[i],
        ],
      );

  LyricLine _withChordsOf(LyricLine line, LyricLine source) => LyricLine(
        text: line.text,
        chords: [
          for (final chord in source.chords)
            ChordPosition(
              chord: chord.chord,
              // Verse 2's line is rarely as long as verse 1's, and a copied
              // chord left at its original column would hang in space past the
              // end of its own words. An observed overhang is meaningful; an
              // invented one is not.
              position:
                  chord.position > line.text.length
                      ? line.text.length
                      : chord.position,
            ),
        ],
      );
}
