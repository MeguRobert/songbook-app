/// Music theory constants for chord transposition
class MusicConstants {
  MusicConstants._();

  /// Notes using sharp notation
  static const List<String> sharpNotes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  /// Notes using flat notation
  static const List<String> flatNotes = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B'
  ];

  /// Keys that traditionally use flat notation
  static const Set<String> flatKeys = {
    'F', 'Bb', 'Eb', 'Ab', 'Db', 'Gb',
    'Dm', 'Gm', 'Cm', 'Fm', 'Bbm', 'Ebm'
  };

  /// All valid root notes
  static const Set<String> validRoots = {
    'C', 'C#', 'Db', 'D', 'D#', 'Eb', 'E', 'F',
    'F#', 'Gb', 'G', 'G#', 'Ab', 'A', 'A#', 'Bb', 'B'
  };

  /// Common chord qualities/suffixes
  static const List<String> chordQualities = [
    '',      // major
    'm',     // minor
    '7',     // dominant 7th
    'maj7',  // major 7th
    'm7',    // minor 7th
    'dim',   // diminished
    'dim7',  // diminished 7th
    'aug',   // augmented
    'sus2',  // suspended 2nd
    'sus4',  // suspended 4th
    '6',     // major 6th
    'm6',    // minor 6th
    '9',     // dominant 9th
    'add9',  // add 9
  ];

  /// Number of semitones in an octave
  static const int semitonesPerOctave = 12;

  /// Common time signatures
  static const List<String> timeSignatures = [
    '4/4', '3/4', '6/8', '2/4', '2/2', '12/8'
  ];
}
