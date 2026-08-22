import '../constants/music_constants.dart';

/// Utility class for transposing chords
class ChordTransposer {
  ChordTransposer._();

  static final _chordPattern = RegExp(r'^([A-GHa-gh][#b]?)(.*)$');

  /// A German root note: `H` opening the chord, or `H` as a slash bass.
  static final _germanRoot = RegExp(r'(^|/)[Hh]');

  /// A lowercase root — Central European for "minor" — and what follows it.
  ///
  /// Anchored at the start, and deliberately NOT applied after a slash: a slash
  /// bass is a single note with no quality of its own, so `G/h` is `G/B` and
  /// never `G/Bm`. Anchoring also keeps it away from the quality, where a
  /// lowercase letter is ordinary — unanchored, the `d` of `F#dim` read as a
  /// root and produced `F#Dmim`.
  static final _minorRoot = RegExp(r'^([a-gh])([#b]?)(.*)$');

  /// A lowercase slash bass: raised, never made minor.
  static final _lowercaseBass = RegExp(r'/([a-gh])([#b]?)$');

  /// Quality that already states what the chord is, so `m` must not be added.
  static final _statedQuality = RegExp(r'^(?:m|maj|min|dim|aug|sus|\+|°)');

  /// [chord] with German note names rewritten to the ones the app stores.
  ///
  /// `H` is B natural across Hungary, Germany, Poland, Czechia, the Balkans,
  /// Scandinavia and Russia — a medieval scribal accident, where the square `b`
  /// that meant B natural was written in a hand that later readers took for an
  /// `h`. A Hungarian songbook is full of `H` and `Hm`, so a page that is
  /// pasted or photographed has to be readable.
  ///
  /// `B` is deliberately left alone. Strict German notation reads it as B flat,
  /// but every song already stored here reads it as B natural, and redefining
  /// it would silently re-tune the library. Accepting `H` only ever adds
  /// information: unlike `B`, `H` names the same pitch in every system that
  /// uses it at all.
  ///
  /// The app keeps one spelling per pitch, so `H` is accepted on the way in and
  /// not carried through — otherwise transposition would have to decide, with
  /// nothing to go on, whether a song reaching B natural should say `B` or `H`.
  /// [chord] with a lowercase root raised and marked minor.
  ///
  /// Central European songbooks write case for quality: `C` is C major and `c`
  /// is C minor. Robert's book prints `em` on every chord row, and a row
  /// carrying one used to be classified as lyrics, so all of its chords entered
  /// the song as words.
  ///
  /// `m` is only added when the quality does not already state one: `em` is
  /// already minor and must not become `Emm`, and `asus4` is neither major nor
  /// minor — a suspended chord has no third to lower.
  static String _minorFromCase(String chord) {
    final bassRaised = chord.replaceAllMapped(
        _lowercaseBass, (m) => '/${m.group(1)!.toUpperCase()}${m.group(2)}');
    final match = _minorRoot.firstMatch(bassRaised);
    if (match == null) return bassRaised;
    final quality = match.group(3)!;
    final needsM = quality.isEmpty || !_statedQuality.hasMatch(quality);
    return '${match.group(1)!.toUpperCase()}${match.group(2)}'
        '${needsM ? 'm' : ''}$quality';
  }

  /// An accidental spelled out in letters, at a root position.
  ///
  /// Hungarian and German print the accidental as a syllable rather than a sign:
  /// `Fisz` and `Fis` are F sharp, `Esz` is E flat, `Desz` is D flat. A chord
  /// sheet from Robert's book is full of them — `fiszm`, `D4/Fis` — and without
  /// this they arrive at [_minorFromCase] as a root with a nonsense quality:
  /// `fiszm` came out as `Fmiszm`.
  ///
  /// Sharps are `isz`/`is`; flats are `esz`/`sz`. A bare `s` is deliberately not
  /// a flat, German short forms notwithstanding: it would read `Gsus2` as G flat
  /// carrying `us2`. Anchored to the start or to a slash bass, so a quality is
  /// still free to say `sus`.
  static final _spelledAccidental =
      RegExp(r'(^|/)([A-Ga-g])(isz|is|esz|sz)');

  static String toEnglishNotation(String chord) =>
      _minorFromCase(_signsForSyllables(chord))
          .replaceAllMapped(_germanRoot, (m) => '${m.group(1)}B');

  /// [chord] with `Fisz`/`Fis` written as `F#` and `Esz` as `Eb`.
  static String _signsForSyllables(String chord) =>
      chord.replaceAllMapped(_spelledAccidental, (m) {
        final sharp = m.group(3) == 'isz' || m.group(3) == 'is';
        return '${m.group(1)}${m.group(2)}${sharp ? '#' : 'b'}';
      });

  /// Transposes a single chord by the given number of semitones
  ///
  /// [chord] - The chord to transpose (e.g., "Gm7", "Bb", "F#dim", "G/B")
  /// [semitones] - Number of semitones to transpose (positive = up, negative = down)
  /// [useFlats] - Whether to use flat notation for the result
  static String transposeChord(String chord, int semitones, {bool useFlats = false}) {
    if (semitones == 0) return chord;

    // A slash chord carries a second, independent pitch. parseChord treats
    // "/B" as opaque quality (callers depend on that), so the split has to
    // happen here: without it the bass rode along untransposed and G/B + 2
    // came out as A/B instead of A/C#.
    final slashIndex = chord.indexOf('/');
    if (slashIndex > 0) {
      final upper = _transposeNote(chord.substring(0, slashIndex), semitones, useFlats);
      final bass = _transposeNote(chord.substring(slashIndex + 1), semitones, useFlats);
      // Half-transposing would silently change the harmony, so an unreadable
      // side leaves the whole chord alone.
      if (upper == null || bass == null) return chord;
      return '$upper/$bass';
    }

    return _transposeNote(chord, semitones, useFlats) ?? chord;
  }

  /// Transposes one root-plus-quality group, or null if it cannot be resolved
  static String? _transposeNote(String chord, int semitones, bool useFlats) {
    final parsed = parseChord(chord);
    if (parsed == null) return null;

    final (root, quality) = parsed;
    final notes = useFlats ? MusicConstants.flatNotes : MusicConstants.sharpNotes;

    // Find root index in either sharp or flat notes
    int index = MusicConstants.sharpNotes.indexOf(root);
    if (index == -1) index = MusicConstants.flatNotes.indexOf(root);
    if (index == -1) return null;

    // Transpose with wrapping
    int newIndex = (index + semitones) % MusicConstants.semitonesPerOctave;
    if (newIndex < 0) newIndex += MusicConstants.semitonesPerOctave;

    final newRoot = notes[newIndex];
    return '$newRoot$quality';
  }

  /// Parses a chord into its root note and quality
  ///
  /// Returns a tuple of (root, quality) or null if invalid
  ///
  /// A slash bass note stays inside the quality ("C/G" -> ("C", "/G"));
  /// [transposeChord] splits it off so both pitches move together.
  static (String, String)? parseChord(String chord) {
    // Normalised whole, then split. Splitting first and normalising each half
    // let the quality be read as though it began with a root: the `d` of
    // `F#dim` became a lowercase minor and the chord came out `F#Dmim`.
    final match = _chordPattern.firstMatch(toEnglishNotation(chord));
    if (match == null) return null;
    return (match.group(1)!, match.group(2)!);
  }

  /// Calculates the number of semitones between two keys
  static int semitonesBetween(String fromKey, String toKey) {
    final fromIndex = _keyToIndex(fromKey);
    final toIndex = _keyToIndex(toKey);
    if (fromIndex == -1 || toIndex == -1) return 0;

    int diff = toIndex - fromIndex;
    // Normalize to -6 to +5 range for shortest path
    if (diff > 6) diff -= 12;
    if (diff < -6) diff += 12;
    return diff;
  }

  /// Determines if a key typically uses flat notation
  static bool shouldUseFlats(String key) {
    return MusicConstants.flatKeys.contains(key);
  }

  /// Transposes a key by the given number of semitones
  static String transposeKey(String key, int semitones) {
    final isMinor = key.endsWith('m');
    final root = isMinor ? key.substring(0, key.length - 1) : key;
    final useFlats = shouldUseFlats(key);

    final newRoot = transposeChord(root, semitones, useFlats: useFlats);
    return isMinor ? '${newRoot}m' : newRoot;
  }

  /// Gets all available keys for transposition display
  static List<String> getAllKeys() {
    return [
      'C', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B'
    ];
  }

  static int _keyToIndex(String key) {
    // Remove minor indicator for index lookup
    final root = toEnglishNotation(key.replaceAll('m', ''));
    int index = MusicConstants.sharpNotes.indexOf(root);
    if (index == -1) index = MusicConstants.flatNotes.indexOf(root);
    return index;
  }
}
