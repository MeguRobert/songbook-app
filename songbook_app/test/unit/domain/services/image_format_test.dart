import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/image_format.dart';

/// [head] followed by enough zeroes to look like a file.
///
/// A signature is read out of the first twelve bytes, so every case here is a
/// real header with a plausible tail rather than a twelve-byte string: a sniff
/// that only worked on inputs exactly as long as its own table would pass a
/// test written the other way and fail on every real upload.
Uint8List bytes(List<int> head, {int pad = 64}) =>
    Uint8List.fromList([...head, ...List.filled(pad, 0)]);

/// `ftyp` at offset 4, brand at 8. The box length in front of it is real:
/// 0x00000018 is what a phone actually writes, and the sniff is not allowed to
/// depend on the value.
Uint8List isoBmff(String brand) => bytes([
      0x00, 0x00, 0x00, 0x18, // box length
      0x66, 0x74, 0x79, 0x70, // 'ftyp'
      ...brand.codeUnits, // major brand
      0x00, 0x00, 0x00, 0x00, // minor version
      ...'mif1heic'.codeUnits, // compatible brands, as a real file carries
    ]);

void main() {
  group('sniffImageFormat', () {
    // Table-driven over the signatures as they appear in real files, because
    // the whole value of this function is that it agrees with what a phone
    // hands over. Anything invented here would prove only that the invention
    // matches itself.
    final cases = <String, (Uint8List, ImageFormat)>{
      'JPEG/JFIF': (
        bytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, ...'JFIF'.codeUnits]),
        ImageFormat.jpeg,
      ),
      'JPEG/Exif — what a camera writes': (
        bytes([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x1C, ...'Exif'.codeUnits]),
        ImageFormat.jpeg,
      ),
      'PNG': (
        bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ImageFormat.png,
      ),
      'GIF87a': (bytes('GIF87a'.codeUnits), ImageFormat.gif),
      'GIF89a': (bytes('GIF89a'.codeUnits), ImageFormat.gif),
      'WebP': (
        bytes([
          ...'RIFF'.codeUnits,
          0x24, 0x00, 0x00, 0x00, // file size, which must not be looked at
          ...'WEBPVP8 '.codeUnits,
        ]),
        ImageFormat.webp,
      ),
      'HEIC — Xiaomi and Apple high efficiency': (
        isoBmff('heic'),
        ImageFormat.heic,
      ),
      'HEIC, heix profile': (isoBmff('heix'), ImageFormat.heic),
      'HEIF, mif1 — what Android most often stamps': (
        isoBmff('mif1'),
        ImageFormat.heif,
      ),
      'HEIF, msf1 image sequence': (isoBmff('msf1'), ImageFormat.heif),
      'AVIF': (isoBmff('avif'), ImageFormat.avif),
      'MP4 — a motion photo or a screen recording picked by mistake': (
        isoBmff('mp42'),
        ImageFormat.isoBmff,
      ),
      'QuickTime': (isoBmff('qt  '), ImageFormat.isoBmff),
      'PDF': (bytes('%PDF-1.7'.codeUnits), ImageFormat.pdf),
    };

    cases.forEach((name, expected) {
      test(name, () => expect(sniffImageFormat(expected.$1), expected.$2));
    });

    test('a RIFF that is not WebP is not claimed as one', () {
      // WAVE, and the form type twelve bytes in is the only thing that says so.
      // Matching `RIFF` alone would have reported a sound file as a picture.
      final wave = bytes([
        ...'RIFF'.codeUnits,
        0x24, 0x00, 0x00, 0x00,
        ...'WAVEfmt '.codeUnits,
      ]);
      expect(sniffImageFormat(wave), ImageFormat.unknown);
    });

    test('a bare SOI marker is not enough to claim JPEG', () {
      // 0xFFD8 alone is one marker; the third byte is what makes it a stream
      // rather than two bytes that happen to collide.
      expect(sniffImageFormat(bytes([0xFF, 0xD8, 0x00, 0x00])),
          ImageFormat.unknown);
    });

    test('an ftyp box with no room for a brand still says what it is', () {
      // Truncated at eleven bytes: `ftyp` is there and the brand is not.
      final truncated =
          Uint8List.fromList([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69]);
      expect(sniffImageFormat(truncated), ImageFormat.isoBmff);
    });

    test('nothing at all is unknown rather than a throw', () {
      // The refused-empty-file path records a format like every other path, so
      // this input reaches the function on a real run.
      expect(sniffImageFormat(Uint8List(0)), ImageFormat.unknown);
    });

    test('a short file is unknown rather than a range error', () {
      for (var length = 1; length <= 12; length++) {
        expect(sniffImageFormat(Uint8List(length)), ImageFormat.unknown,
            reason: 'length $length');
      }
    });

    test('the name is never consulted', () {
      // The point of sniffing: `.jpg` on a HEIC is exactly the case this exists
      // to catch, and there is no parameter here that could carry a name.
      expect(sniffImageFormat(isoBmff('heic')), ImageFormat.heic);
    });
  });
}
