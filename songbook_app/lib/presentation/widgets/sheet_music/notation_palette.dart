import 'package:flutter/material.dart';

/// Ink colours for the engraved staff, in one place per theme.
///
/// The notation is drawn on a [CustomPaint] straight over the scaffold — there
/// is no white "paper" behind it — so every mark has to follow the theme. Note
/// heads and stems already did, but lyrics, chord symbols and the time signature
/// took their colour from `EngravingConstants`' baked-in light-theme values and
/// stayed near-black on a dark background: white notes floating above unreadable
/// words.
///
/// Kept as one object rather than scattered ternaries so a new mark cannot be
/// added without picking a colour for both themes.
class NotationPalette {
  /// Note heads, stems, beams, bar lines, ties — and the time signature, which
  /// is a glyph rather than text.
  final Color note;

  /// Staff and leger lines. Slightly softer than [note] so the lines read as
  /// ruling and the notes sit on top of them.
  final Color staff;

  /// Lyric syllables and their hyphens.
  final Color lyric;

  /// Chord symbols above the staff. Stays chromatic in both themes — it is how
  /// chords are told apart from lyrics at a glance — but the dark variant is
  /// lightened well past the light-theme blue, which is far too dark to read
  /// on a dark surface.
  final Color chord;

  const NotationPalette({
    required this.note,
    required this.staff,
    required this.lyric,
    required this.chord,
  });

  static const _light = NotationPalette(
    note: Color(0xFF333333),
    staff: Color(0xFF333333),
    lyric: Color(0xFF333333),
    chord: Color(0xFF1565C0),
  );

  static const _dark = NotationPalette(
    note: Color(0xFFFFFFFF),
    staff: Color(0xFFD0D0D6),
    lyric: Color(0xFFF2F2F5),
    chord: Color(0xFF8AB4FF),
  );

  static NotationPalette of(ThemeData theme) =>
      theme.brightness == Brightness.dark ? _dark : _light;
}
