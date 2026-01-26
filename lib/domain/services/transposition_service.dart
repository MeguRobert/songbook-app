import '../../core/utils/chord_transposer.dart';
import '../../data/models/chord_position.dart';
import '../../data/models/lyric_line.dart';
import '../../data/models/verse.dart';

/// Service for transposing chords in songs
class TranspositionService {
  const TranspositionService();

  /// Transposes a single chord by the given number of semitones
  String transposeChord(String chord, int semitones, {String? targetKey}) {
    final useFlats = targetKey != null
        ? ChordTransposer.shouldUseFlats(targetKey)
        : false;
    return ChordTransposer.transposeChord(chord, semitones, useFlats: useFlats);
  }

  /// Transposes all chords in a lyric line
  LyricLine transposeLine(LyricLine line, int semitones, {String? targetKey}) {
    if (semitones == 0 || line.chords.isEmpty) return line;

    final transposedChords = line.chords.map((cp) {
      return ChordPosition(
        chord: transposeChord(cp.chord, semitones, targetKey: targetKey),
        position: cp.position,
      );
    }).toList();

    return line.copyWith(chords: transposedChords);
  }

  /// Transposes all chords in a verse
  Verse transposeVerse(Verse verse, int semitones, {String? targetKey}) {
    if (semitones == 0 || verse.lines.isEmpty) return verse;

    final transposedLines = verse.lines.map((line) {
      return transposeLine(line, semitones, targetKey: targetKey);
    }).toList();

    return verse.copyWith(lines: transposedLines);
  }

  /// Calculates the target key after transposition
  String calculateTargetKey(String originalKey, int semitones) {
    return ChordTransposer.transposeKey(originalKey, semitones);
  }

  /// Gets the semitones needed to transpose from one key to another
  int getSemitonesBetweenKeys(String fromKey, String toKey) {
    return ChordTransposer.semitonesBetween(fromKey, toKey);
  }

  /// Gets a list of all available keys for transposition
  List<String> getAvailableKeys() {
    return ChordTransposer.getAllKeys();
  }

  /// Determines the display name for a transposition amount
  String getTranspositionDisplayName(int semitones) {
    if (semitones == 0) return 'Original';
    if (semitones > 0) return '+$semitones';
    return semitones.toString();
  }
}
