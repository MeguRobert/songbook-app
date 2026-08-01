/// The accent-stripped code unit for [unit], or [unit] itself.
///
/// A switch rather than a map so the lookup is a compare chain on an int instead
/// of a hash of a boxed key — this runs once per character of everything search
/// touches. Hungarian vowels only: this is a search normaliser for one language,
/// not Unicode decomposition, and `çñ` deliberately pass through (there is a test).
int _foldDiacritic(int unit) => switch (unit) {
      0x00E1 => 0x61, // á
      0x00E9 => 0x65, // é
      0x00ED => 0x69, // í
      0x00F3 => 0x6F, // ó
      0x00F6 => 0x6F, // ö
      0x0151 => 0x6F, // ő
      0x00FA => 0x75, // ú
      0x00FC => 0x75, // ü
      0x0171 => 0x75, // ű
      0x00C1 => 0x41, // Á
      0x00C9 => 0x45, // É
      0x00CD => 0x49, // Í
      0x00D3 => 0x4F, // Ó
      0x00D6 => 0x4F, // Ö
      0x0150 => 0x4F, // Ő
      0x00DA => 0x55, // Ú
      0x00DC => 0x55, // Ü
      0x0170 => 0x55, // Ű
      _ => unit,
    };

/// String extensions for text processing
extension StringExtensions on String {
  /// Capitalizes the first letter of the string
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Removes diacritics from Hungarian characters for search.
  ///
  /// This is the hottest string operation in the app: search normalises a title,
  /// a reference, every tag and — in the lyrics fallback — every line of every
  /// verse, on every keystroke, on the UI isolate. At 1000 songs that is tens of
  /// thousands of calls per character typed.
  ///
  /// It used to be `split('')/map/join`, which allocated a one-character String
  /// per character plus an intermediate iterable and list, for every string it
  /// saw. It is now a single pass over code units with a fast path that returns
  /// the receiver untouched when there is nothing to fold — which is most strings,
  /// and always the query itself once normalised.
  ///
  /// Every Hungarian accented vowel is a single UTF-16 code unit, so a
  /// per-code-unit pass is safe here. Surrogate halves are all ≥ 0xD800 and so
  /// never fold, and are copied through unchanged; there is a test for an emoji.
  String removeDiacritics() {
    // Scan before building. Rebuilding a string that needed no change is the
    // common case and by far the most expensive way to do nothing.
    var first = -1;
    for (var i = 0; i < length; i++) {
      final unit = codeUnitAt(i);
      if (_foldDiacritic(unit) != unit) {
        first = i;
        break;
      }
    }
    if (first < 0) return this;

    final folded = StringBuffer(substring(0, first));
    for (var i = first; i < length; i++) {
      folded.writeCharCode(_foldDiacritic(codeUnitAt(i)));
    }
    return folded.toString();
  }

  /// Normalizes string for search comparison
  String normalizeForSearch() {
    return toLowerCase().removeDiacritics().trim();
  }

  /// Checks if string contains search query (case-insensitive, diacritic-insensitive)
  bool containsNormalized(String query) {
    return normalizeForSearch().contains(query.normalizeForSearch());
  }
}
