import 'package:flutter/material.dart';

/// Constants for music engraving and sheet music rendering
/// Based on SMuFL (Standard Music Font Layout) engraving defaults
/// All proportional measurements are in staff spaces (1 space = staffLineSpacing)
/// Reference: https://w3c.github.io/smufl/latest/specification/engravingdefaults.html
class EngravingConstants {
  EngravingConstants._();

  // ============ STAFF DIMENSIONS ============
  // Based on SMuFL: 1 staff space = distance between two staff lines

  /// Spacing between staff lines (in logical pixels)
  /// This is the base unit - all other measurements derive from this
  static const double staffLineSpacing = 10.0;

  /// Alias for staff space (SMuFL standard terminology)
  static double get staffSpace => staffLineSpacing;

  /// Number of lines in a staff
  static const int staffLines = 5;

  /// Total height of a staff (from top line to bottom line)
  /// Equals 4 staff spaces
  static double get staffHeight => staffLineSpacing * (staffLines - 1);

  /// Staff line thickness (SMuFL default: 0.13 spaces)
  /// Thinner than stems for proper visual hierarchy
  static double get staffLineWidth => staffSpace * 0.13;

  /// Color of staff lines
  static const Color staffLineColor = Color(0xFF333333);

  // ============ SMuFL ENGRAVING DEFAULTS ============
  // These follow the SMuFL specification for professional engraving

  /// Stem thickness (SMuFL default: 0.12 spaces)
  /// Should be thinner than staff lines per Gould's "Behind Bars"
  static double get stemThickness => staffSpace * 0.12;

  /// Beam thickness (SMuFL default: 0.5 spaces)
  static double get beamThickness => staffSpace * 0.5;

  /// Beam spacing for multiple beams (SMuFL default: 0.25 spaces)
  static double get beamSpacing => staffSpace * 0.25;

  /// Leger line thickness (SMuFL default: 0.16 spaces)
  static double get legerLineThickness => staffSpace * 0.16;

  /// Leger line extension beyond note head (SMuFL default: 0.4 spaces)
  static double get legerLineExtension => staffSpace * 0.4;

  /// Bar line thickness (SMuFL default: 0.16 spaces)
  static double get barLineThickness => staffSpace * 0.16;

  /// Thin bar line thickness for double bars (SMuFL default: 0.16 spaces)
  static double get thinBarLineThickness => staffSpace * 0.16;

  /// Thick bar line thickness for final bars (SMuFL default: 0.5 spaces)
  static double get thickBarLineThickness => staffSpace * 0.5;

  /// Bar line separation for double bars (SMuFL default: 0.4 spaces)
  static double get barLineSeparation => staffSpace * 0.4;

  // ============ STEM RULES ============
  // Based on Ted Ross "The Art of Music Engraving" and Elaine Gould "Behind Bars"

  /// Standard stem length (3.5 spaces = one octave)
  static double get stemLength => staffSpace * 3.5;

  /// Minimum stem length for notes far from staff
  static double get minStemLength => staffSpace * 2.5;

  /// Stem extension per additional beam (1 space each)
  static double get stemExtensionPerBeam => staffSpace;

  // ============ BEAM RULES ============
  // Following Ross beam rules for professional engraving

  /// Minimum beam slant for seconds (0.25 spaces)
  static double get minBeamSlant => staffSpace * 0.25;

  /// Maximum beam slant for large intervals (1.5 spaces)
  static double get maxBeamSlant => staffSpace * 1.5;

  /// Beam slant increment per staff position
  static double get beamSlantPerPosition => staffSpace * 0.125;

  // ============ MARGINS AND SPACING ============

  /// Left margin before first element
  static const double leftMargin = 20.0;

  /// Right margin after last element
  static const double rightMargin = 20.0;

  /// Space between clef and key signature (SMuFL: 0.5-1.0 spaces)
  static double get clefToKeySpace => staffSpace * 0.75;

  /// Space between key signature and time signature
  static double get keyToTimeSpace => staffSpace * 1.0;

  /// Space between time signature and first note
  static double get timeToNoteSpace => staffSpace * 2.0;

  /// Minimum space between notes (optical spacing base)
  static double get minNoteSpacing => staffSpace * 3.5;

  /// Space between measures (bar lines)
  static double get measureSpacing => staffSpace * 2.5;

  /// Space between staff systems (lines of music)
  static double get systemSpacing => staffSpace * 10.0;

  /// Space above staff for chord symbols
  static double get chordAboveStaff => staffSpace * 2.5;

  /// Space below staff for lyrics
  static double get lyricBelowStaff => staffSpace * 2.8;

  // ============ NOTE HEAD DIMENSIONS ============
  // Based on typical music font proportions

  /// Width of a note head (approximately 1.3 spaces)
  static double get noteHeadWidth => staffSpace * 1.3;

  /// Height of a note head (approximately 1.0 space for filled notes)
  static double get noteHeadHeight => staffSpace * 1.0;

  /// Note head rotation angle (slight tilt for natural appearance)
  static const double noteHeadRotation = -0.2; // radians

  /// Dot offset from note head
  static double get dotOffset => staffSpace * 0.5;

  /// Dot radius
  static double get dotRadius => staffSpace * 0.2;

  // ============ ACCIDENTALS ============

  /// Space before accidental
  static double get accidentalSpace => staffSpace * 0.25;

  /// Sharp width
  static double get sharpWidth => staffSpace * 0.95;

  /// Flat width
  static double get flatWidth => staffSpace * 0.85;

  /// Natural width
  static double get naturalWidth => staffSpace * 0.7;

  // ============ CLEF DIMENSIONS ============

  /// Width allocated for treble clef
  static double get clefWidth => staffSpace * 2.8;

  /// Font size for clef (scales with staff space)
  static double get clefFontSize => staffSpace * 4.8;

  // ============ TIE AND SLUR DEFAULTS ============

  /// Tie thickness at endpoints
  static double get tieEndpointThickness => staffSpace * 0.1;

  /// Tie thickness at midpoint
  static double get tieMidpointThickness => staffSpace * 0.22;

  /// Minimum tie height
  static double get minTieHeight => staffSpace * 0.5;

  /// Tie offset from note head
  static double get tieOffset => staffSpace * 0.3;

  // ============ TEXT STYLES ============

  /// Font size for chord symbols (relative to staff)
  static double get chordFontSize => staffSpace * 1.4;

  /// Font size for lyrics
  static double get lyricFontSize => staffSpace * 1.6;

  /// Font size for time signature
  static double get timeSigFontSize => staffSpace * 2.2;

  /// Chord text style
  static TextStyle get chordStyle => TextStyle(
    fontSize: chordFontSize,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF1565C0),
    fontFamily: 'Arial',
  );

  /// Lyric text style
  static TextStyle get lyricStyle => TextStyle(
    fontSize: lyricFontSize,
    color: const Color(0xFF333333),
    fontFamily: 'Georgia',
    height: 1.2,
  );

  /// Time signature style
  static TextStyle get timeSigStyle => TextStyle(
    fontSize: timeSigFontSize,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF333333),
    fontFamily: 'serif',
  );

  // ============ LEGACY COMPATIBILITY ============
  // Keep old names for backward compatibility

  /// @deprecated Use stemThickness instead
  static double get stemWidth => stemThickness;

  /// @deprecated Use barLineThickness instead
  static double get barLineWidth => barLineThickness;

  /// @deprecated Use thickBarLineThickness instead
  static double get finalBarLineWidth => thickBarLineThickness;

  // ============ PITCH TO POSITION MAPPING ============

  /// Middle C (C4) position relative to treble clef staff
  /// Counted from bottom line (0) in half-steps
  /// E4 is on bottom line (0), so C4 is -2 (one ledger line below)
  static const int middleCPosition = -2;

  /// Map note names to positions relative to C
  static const Map<String, int> notePositions = {
    'C': 0,
    'D': 1,
    'E': 2,
    'F': 3,
    'G': 4,
    'A': 5,
    'B': 6,
  };

  /// Calculate Y position for a pitch relative to staff bottom
  /// Higher position number = higher on staff = smaller Y value
  static double getYPositionForPitch(String pitch, double staffBottom) {
    final match = RegExp(r'^([A-Ga-g])([#b]?)(\d)$').firstMatch(pitch);
    if (match == null) return staffBottom;

    final noteName = match.group(1)!.toUpperCase();
    final octave = int.parse(match.group(3)!);

    // Calculate position in staff positions (each position is half a staffLineSpacing)
    // E4 is on the bottom line (position 0)
    // F4 = position 1 (first space), G4 = position 2 (second line), etc.
    // C5 = position 5 (third space), F5 = position 8 (top line)

    final noteIndex = notePositions[noteName] ?? 0;

    // Calculate octave offset (E4 is reference, 7 positions per octave)
    final octaveOffset = (octave - 4) * 7;

    // Calculate note offset from E within octave
    // notePositions: C=0, D=1, E=2, F=3, G=4, A=5, B=6
    final noteOffset = noteIndex - 2; // E = 2, so E offset = 0

    // Total position (positive = up on staff)
    final position = octaveOffset + noteOffset;

    // Convert to Y coordinate
    // Position 0 (E4) = staffBottom (bottom line)
    // Each position up decreases Y by half a staff line spacing
    final halfSpacing = staffLineSpacing / 2;
    return staffBottom - (position * halfSpacing);
  }

  // ============ KEY SIGNATURE ============

  /// Flats in order for key signatures
  static const List<String> flatOrder = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];

  /// Sharps in order for key signatures
  static const List<String> sharpOrder = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];

  /// Number of flats/sharps for each major key
  static const Map<String, int> keySignatures = {
    'C': 0,
    'G': 1, 'D': 2, 'A': 3, 'E': 4, 'B': 5, 'F#': 6, 'C#': 7,
    'F': -1, 'Bb': -2, 'Eb': -3, 'Ab': -4, 'Db': -5, 'Gb': -6, 'Cb': -7,
  };

  /// Y positions for flats on treble clef (relative to middle line)
  /// Positive = up from middle, negative = down from middle
  /// Each unit = half a staff line spacing
  static const List<double> flatPositions = [
    0.0,  // Bb on middle line (line 3, B4)
    3.0,  // Eb in 4th space (E5)
    -1.0, // Ab in 2nd space (A4)
    2.0,  // Db on 4th line (D5)
    -2.0, // Gb on 2nd line (G4)
    1.0,  // Cb in 3rd space (C5)
    -3.0, // Fb in 1st space (F4)
  ];

  /// Y positions for sharps on treble clef (relative to middle line)
  /// Positive = up from middle, negative = down from middle
  static const List<double> sharpPositions = [
    4.0,  // F# on top line (F5)
    1.0,  // C# in 3rd space (C5)
    5.0,  // G# above staff (G5)
    2.0,  // D# on 4th line (D5)
    -1.0, // A# in 2nd space (A4)
    3.0,  // E# in 4th space (E5)
    0.0,  // B# on middle line (B4)
  ];

  /// Calculate the width needed for a key signature
  static double getKeySignatureWidth(String key) {
    final numAccidentals = (keySignatures[key] ?? 0).abs();
    if (numAccidentals == 0) return 0;

    // Use flat width as it's slightly smaller - sharps will fit too
    return numAccidentals * flatWidth + staffSpace * 0.5; // Extra padding
  }
}
