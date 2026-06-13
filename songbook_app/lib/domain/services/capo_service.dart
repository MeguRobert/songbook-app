import '../../core/utils/chord_transposer.dart';

/// A single capo suggestion: place the capo on [fret] and play open-chord
/// shapes from the key [shapeKey] to sound in the song's key.
class CapoSuggestion {
  /// Capo fret (0 = no capo, play open in [shapeKey]).
  final int fret;

  /// The open-chord shape key to play with the capo on (e.g. "G", "Am").
  final String shapeKey;

  const CapoSuggestion({required this.fret, required this.shapeKey});

  /// Human-readable label for display.
  String get label => fret == 0
      ? 'No capo · play in $shapeKey'
      : 'Capo $fret · play $shapeKey shapes';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapoSuggestion &&
          runtimeType == other.runtimeType &&
          fret == other.fret &&
          shapeKey == other.shapeKey;

  @override
  int get hashCode => fret.hashCode ^ shapeKey.hashCode;

  @override
  String toString() => 'CapoSuggestion(fret: $fret, shapeKey: $shapeKey)';
}

/// Suggests capo positions + open-chord shapes for a sounding key.
///
/// Guitarists think in shapes, not absolute keys. Given the key a song actually
/// sounds in (after any transposition), this returns the CAGED open-chord shapes
/// you could play with a capo to reach that key, lowest fret first.
class CapoService {
  const CapoService();

  /// Practical open-chord "shape" keys (the CAGED system) for major keys.
  static const majorShapeKeys = ['C', 'A', 'G', 'E', 'D'];

  /// Practical open-chord shape keys for minor keys.
  static const minorShapeKeys = ['Em', 'Am', 'Dm'];

  /// Returns capo suggestions for [soundingKey], lowest fret first.
  ///
  /// [maxFret] caps how high a capo position is offered (default 9 — most necks
  /// stop being comfortable past there). Returns an empty list for an
  /// unparseable key.
  List<CapoSuggestion> suggestionsFor(String soundingKey, {int maxFret = 9}) {
    final key = soundingKey.trim();
    if (key.isEmpty) return const [];

    final isMinor = key.endsWith('m');
    final root = isMinor ? key.substring(0, key.length - 1) : key;
    if (!_isValidRoot(root)) return const [];

    final shapes = isMinor ? minorShapeKeys : majorShapeKeys;
    final suggestions = <CapoSuggestion>[];
    for (final shape in shapes) {
      // Frets to raise the open shape up to the sounding key (0..11).
      final raw = ChordTransposer.semitonesBetween(shape, key);
      final fret = ((raw % 12) + 12) % 12;
      if (fret <= maxFret) {
        suggestions.add(CapoSuggestion(fret: fret, shapeKey: shape));
      }
    }

    suggestions.sort((a, b) => a.fret.compareTo(b.fret));
    return suggestions;
  }

  /// The recommended capo suggestion (lowest practical fret) or null if none.
  CapoSuggestion? recommendedFor(String soundingKey, {int maxFret = 9}) {
    final suggestions = suggestionsFor(soundingKey, maxFret: maxFret);
    return suggestions.isEmpty ? null : suggestions.first;
  }

  bool _isValidRoot(String root) {
    // semitonesBetween strips an 'm'; validate the root note itself parses.
    final parsed = ChordTransposer.parseChord(root);
    return parsed != null && parsed.$2.isEmpty;
  }
}
