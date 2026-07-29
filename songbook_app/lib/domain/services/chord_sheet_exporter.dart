import '../../data/models/song.dart';

/// Renders a [Song] back out as ChordPro text.
///
/// ChordPro rather than a prettier layout, because it is the format
/// [ChordSheetParser] already reads: what the app copies out can be pasted
/// straight back in, or into any other chord-sheet tool, and nothing is lost on
/// the way. Chords-over-lyrics would look more like the screen but would depend
/// on a monospace font to mean anything.
///
/// Inline brackets are placed from [ChordPosition.position], which is a character
/// index into the lyric — the same property that let the parser read both input
/// shapes into one model.
class ChordSheetExporter {
  const ChordSheetExporter();

  String toChordPro(Song song) {
    final out = StringBuffer()..writeln('{title: ${song.title}}');
    if (song.originalKey.isNotEmpty) out.writeln('{key: ${song.originalKey}}');
    if (song.reference != null) out.writeln('{c: ${song.reference}}');
    out.writeln();

    for (final verse in song.verses) {
      if (verse.lines.isEmpty) {
        // A plain-text verse has no chord positions to place, so it goes out as
        // it came in rather than being re-wrapped into something it is not.
        final plain = verse.plainText;
        if (plain != null && plain.trim().isNotEmpty) {
          out.writeln(plain.trim());
          out.writeln();
        }
        continue;
      }

      for (final line in verse.lines) {
        out.writeln(_lineToChordPro(line.text, line.chords));
      }
      out.writeln();
    }

    return out.toString().trimRight();
  }

  /// Rebuilds one line with its chords bracketed back in.
  ///
  /// Positions are inserted from the end so an earlier insertion cannot shift the
  /// index of a later one, and a chord overhanging a short lyric is appended
  /// rather than dropped — the parser deliberately does not clamp positions to
  /// the text length, so neither does this.
  String _lineToChordPro(String text, List<dynamic> chords) {
    final placed = [
      for (final chord in chords)
        (position: chord.position as int, chord: chord.chord as String),
    ]..sort((a, b) => b.position.compareTo(a.position));

    var result = text;
    for (final entry in placed) {
      final at = entry.position.clamp(0, result.length);
      result = result.replaceRange(at, at, '[${entry.chord}]');
    }
    return result;
  }
}
