/// String extensions for text processing
extension StringExtensions on String {
  /// Capitalizes the first letter of the string
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Removes diacritics from Hungarian characters for search
  String removeDiacritics() {
    const diacritics = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ö': 'o', 'ő': 'o',
      'ú': 'u', 'ü': 'u', 'ű': 'u',
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ö': 'O', 'Ő': 'O',
      'Ú': 'U', 'Ü': 'U', 'Ű': 'U',
    };
    return split('').map((char) => diacritics[char] ?? char).join();
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
