import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/notation_palette.dart';

/// Robert, on a dark-theme phone: the notation's text rendered grey and was too
/// dark to read.
///
/// The notation is painted straight onto the scaffold with no white "paper"
/// behind it, so every mark has to follow the theme. Note heads and stems
/// already did; lyrics, chord symbols, the time signature and the key/time
/// header were drawn from EngravingConstants' baked-in light-theme colours and
/// stayed near-black on a dark surface.
void main() {
  /// Relative luminance, WCAG definition. Used to assert "bright enough"
  /// without pinning exact hex values that a palette tweak may legitimately
  /// change.
  double luminance(Color c) => c.computeLuminance();

  group('dark palette', () {
    final dark = NotationPalette.of(ThemeData.dark());

    test('every mark is light enough to read on a dark surface', () {
      final marks = {
        'note': dark.note,
        'staff': dark.staff,
        'lyric': dark.lyric,
        'chord': dark.chord,
        'header': dark.header,
      };

      marks.forEach((name, color) {
        expect(
          luminance(color),
          greaterThan(0.35),
          reason: '$name is too dark for a dark background',
        );
      });
    });

    test('notes and lyrics are near-white, not mid-grey', () {
      expect(luminance(dark.note), greaterThan(0.9));
      expect(luminance(dark.lyric), greaterThan(0.8));
    });

    test('no mark keeps its light-theme colour', () {
      final light = NotationPalette.of(ThemeData.light());

      expect(dark.note, isNot(light.note));
      expect(dark.staff, isNot(light.staff));
      expect(dark.lyric, isNot(light.lyric));
      expect(dark.chord, isNot(light.chord));
      expect(dark.header, isNot(light.header));
    });

    test('chords stay chromatic so they read as chords, not lyrics', () {
      // A blue-ish hue: distinguishable from the near-white lyric text.
      expect(dark.chord.b, greaterThan(dark.chord.r));
    });
  });

  group('light palette', () {
    final light = NotationPalette.of(ThemeData.light());

    test('every mark is dark enough to read on a light surface', () {
      for (final color in [
        light.note,
        light.staff,
        light.lyric,
        light.chord,
        light.header,
      ]) {
        expect(luminance(color), lessThan(0.35));
      }
    });
  });
}
