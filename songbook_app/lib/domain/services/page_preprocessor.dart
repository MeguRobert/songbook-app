import 'dart:math' as math;
import 'dart:typed_data';

/// Cleans a photographed page before it is read.
///
/// A hymnal is printed thin enough to read the reverse side through it, and an
/// OCR engine returns that ghost as words. Measured on a real photograph of
/// song 149: `n bbod`, `$` and `drnisdl ,Edtt` arrived stuck to the real
/// lyrics, and — worse — the ghost was merged into the real text regions, which
/// inflated their bounding boxes and destroyed a whole chord row. Suppressing
/// it took that page from 3 recognised chord rows to 4.
///
/// Everything here works on 8-bit greyscale, which is what a canvas hands over
/// and what an OCR engine wants back, so no image-decoding dependency is needed
/// and the whole thing is testable with a plain [Uint8List].
///
/// This is the Dart port of the Python original. The reading moved into the
/// browser — Tesseract reads this page in about two seconds where the server
/// engine took forty — so the cleaning had to move with it.
class PagePreprocessor {
  const PagePreprocessor();

  /// Ghost ink lives in this brightness band once the lighting is flattened.
  static const _paleLow = 170;
  static const _paleHigh = 235;

  /// How much of the page has to sit in that band to count as show-through.
  ///
  /// Measured: 2.17% on the ghosted page against 0.00%-0.60% across seven clean
  /// scans, renders and simulated photographs. Antialiasing along the edge of
  /// real print lands in the same band, which is why this is a fraction rather
  /// than a presence test. Calibrated on one ghosted page, so it errs towards
  /// not firing: a page that misses the gate is read exactly as it was before.
  static const _paleFraction = 0.012;

  /// Everything below [_ghostLow] goes black, above [_ghostHigh] goes white.
  static const _ghostLow = 110;
  static const _ghostHigh = 190;

  /// Roughly the window the background is estimated over, in pixels.
  static const _backgroundWindow = 48;

  /// True when [grey] carries a second, paler population of ink.
  ///
  /// Suppression costs stroke sharpness, and on a page that does not need it
  /// that shows up as dropped chords — so it is asked for, never always applied.
  bool hasShowThrough(Uint8List grey, int width, int height) =>
      showsThroughAt(paleFraction(grey, width, height));

  /// Whether a [pale] share measured by [paleFraction] counts as show-through.
  ///
  /// Split out so a caller that already has the number does not pay for it
  /// twice, and so the threshold lives in exactly one place.
  bool showsThroughAt(double pale) => pale >= _paleFraction;

  /// What share of [grey] sits in the pale band once the lighting is flattened.
  ///
  /// Separate from [hasShowThrough] so the measurement can be reported rather
  /// than only acted on. The threshold was calibrated on a single ghosted page,
  /// and the number behind the verdict is what says whether it is calibrated
  /// well — which mattered as soon as the app started *telling* the user it had
  /// cleaned the page.
  double paleFraction(Uint8List grey, int width, int height) {
    if (grey.isEmpty || width <= 0 || height <= 0) return 0.0;
    final flattened = _flatten(grey, width, height);
    var pale = 0;
    for (final value in flattened) {
      if (value >= _paleLow && value <= _paleHigh) pale++;
    }
    return pale / flattened.length;
  }

  /// [grey] with the reverse page's bleed-through erased.
  Uint8List suppressShowThrough(Uint8List grey, int width, int height) {
    if (grey.isEmpty || width <= 0 || height <= 0) return grey;
    final flattened = _flatten(grey, width, height);
    const span = _ghostHigh - _ghostLow;
    final cleaned = Uint8List(flattened.length);
    for (var i = 0; i < flattened.length; i++) {
      final stretched = ((flattened[i] - _ghostLow) * 255) ~/ span;
      cleaned[i] = stretched < 0 ? 0 : (stretched > 255 ? 255 : stretched);
    }
    return cleaned;
  }

  /// [grey] divided by its own local background, so lighting stops mattering.
  ///
  /// Without this, one global brightness window either keeps the ghost in the
  /// bright half of a photographed page or eats the real print in the shadowed
  /// half.
  Uint8List _flatten(Uint8List grey, int width, int height) {
    final background = _background(grey, width, height);
    final flattened = Uint8List(grey.length);
    for (var i = 0; i < grey.length; i++) {
      final paper = background[i];
      if (paper <= 0) {
        flattened[i] = 255;
        continue;
      }
      final value = (grey[i] * 255) ~/ paper;
      flattened[i] = value > 255 ? 255 : value;
    }
    return flattened;
  }

  /// An estimate of the paper colour under every pixel.
  ///
  /// The Python original took a 51-pixel median, which is far too slow in Dart
  /// on a three-megapixel photo. This shrinks the page first — which averages
  /// the strokes away — then takes a local maximum, since paper is the
  /// brightest thing in any neighbourhood of text, smooths that, and scales it
  /// back up. Different arithmetic, same intent; what was actually compared is
  /// the reading it produces, not the pixels.
  Uint8List _background(Uint8List grey, int width, int height) {
    final scale = math.max(
        1, math.min(_backgroundWindow ~/ 6, math.min(width, height) ~/ 8));
    final smallWidth = math.max(1, width ~/ scale);
    final smallHeight = math.max(1, height ~/ scale);

    // Shrink by averaging, so a thin dark stroke is diluted by the paper around
    // it rather than surviving as a dark pixel.
    final small = Uint8List(smallWidth * smallHeight);
    for (var sy = 0; sy < smallHeight; sy++) {
      for (var sx = 0; sx < smallWidth; sx++) {
        var total = 0;
        var count = 0;
        for (var y = sy * scale; y < (sy + 1) * scale && y < height; y++) {
          for (var x = sx * scale; x < (sx + 1) * scale && x < width; x++) {
            total += grey[y * width + x];
            count++;
          }
        }
        small[sy * smallWidth + sx] = count == 0 ? 255 : total ~/ count;
      }
    }

    final lifted = _localMaximum(small, smallWidth, smallHeight);
    final smoothed = _boxBlur(lifted, smallWidth, smallHeight);
    return _upscale(smoothed, smallWidth, smallHeight, width, height);
  }

  /// The brightest value in each 3x3 neighbourhood — the paper, not the ink.
  Uint8List _localMaximum(Uint8List source, int width, int height) {
    final out = Uint8List(source.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var best = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            final value = source[ny * width + nx];
            if (value > best) best = value;
          }
        }
        out[y * width + x] = best;
      }
    }
    return out;
  }

  /// A 3x3 mean, to take the steps out of the maximum.
  Uint8List _boxBlur(Uint8List source, int width, int height) {
    final out = Uint8List(source.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var total = 0;
        var count = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            total += source[ny * width + nx];
            count++;
          }
        }
        out[y * width + x] = total ~/ count;
      }
    }
    return out;
  }

  /// Bilinear scale back up to the full page.
  Uint8List _upscale(Uint8List source, int sourceWidth, int sourceHeight,
      int width, int height) {
    final out = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      final fy = sourceHeight == 1
          ? 0.0
          : (y * (sourceHeight - 1)) / math.max(1, height - 1);
      final y0 = fy.floor();
      final y1 = math.min(y0 + 1, sourceHeight - 1);
      final wy = fy - y0;
      for (var x = 0; x < width; x++) {
        final fx = sourceWidth == 1
            ? 0.0
            : (x * (sourceWidth - 1)) / math.max(1, width - 1);
        final x0 = fx.floor();
        final x1 = math.min(x0 + 1, sourceWidth - 1);
        final wx = fx - x0;
        final top = source[y0 * sourceWidth + x0] * (1 - wx) +
            source[y0 * sourceWidth + x1] * wx;
        final bottom = source[y1 * sourceWidth + x0] * (1 - wx) +
            source[y1 * sourceWidth + x1] * wx;
        out[y * width + x] = (top * (1 - wy) + bottom * wy).round();
      }
    }
    return out;
  }
}
