/// Immutable configuration for song view display.
///
/// Controls visibility of notation (sheet music) and chords.
/// Lyrics are always visible (not configurable).
class ViewConfig {
  final bool showNotation;
  final bool showChords;

  const ViewConfig({
    this.showNotation = true,
    this.showChords = true,
  });

  // --- Preset Factories ---

  /// Full sheet music view with both notation and chords
  const ViewConfig.sheetMusic()
      : showNotation = true,
        showChords = true;

  /// Chord sheet view with chords but no notation
  const ViewConfig.chords()
      : showNotation = false,
        showChords = true;

  /// Clean lyrics-only view with no notation or chords
  const ViewConfig.lyricsOnly()
      : showNotation = false,
        showChords = false;

  // --- Preset Checks ---

  /// Returns true if this config matches the sheet music preset
  bool get isSheetMusicPreset => showNotation && showChords;

  /// Returns true if this config matches the chords preset
  bool get isChordsPreset => !showNotation && showChords;

  /// Returns true if this config matches the lyrics-only preset
  bool get isLyricsOnlyPreset => !showNotation && !showChords;

  /// Returns true if notation is shown without chords (4th valid state)
  bool get isNotationWithoutChords => showNotation && !showChords;

  // --- Copy ---

  ViewConfig copyWith({
    bool? showNotation,
    bool? showChords,
  }) {
    return ViewConfig(
      showNotation: showNotation ?? this.showNotation,
      showChords: showChords ?? this.showChords,
    );
  }

  // --- Storage Serialization ---

  /// Encodes config as "notation:chords" (e.g., "true:true", "false:true")
  String toStorageString() {
    return '$showNotation:$showChords';
  }

  /// Parses config from storage string format.
  /// Falls back to default (all on) for invalid input.
  factory ViewConfig.fromStorageString(String s) {
    final parts = s.split(':');
    if (parts.length != 2) {
      return const ViewConfig(); // Default: all on
    }

    final notation = parts[0].toLowerCase() == 'true';
    final chords = parts[1].toLowerCase() == 'true';

    return ViewConfig(
      showNotation: notation,
      showChords: chords,
    );
  }

  // --- Equality ---

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ViewConfig &&
        other.showNotation == showNotation &&
        other.showChords == showChords;
  }

  @override
  int get hashCode => Object.hash(showNotation, showChords);

  @override
  String toString() {
    return 'ViewConfig(showNotation: $showNotation, showChords: $showChords)';
  }
}
