/// Utility functions for text processing
class TextUtils {
  TextUtils._();

  /// Calculates the visual width of text for chord positioning
  ///
  /// This is an approximation - actual width depends on font metrics
  static double estimateTextWidth(String text, double fontSize) {
    // Average character width is roughly 0.5-0.6 of font size for proportional fonts
    return text.length * fontSize * 0.55;
  }

  /// Truncates text with ellipsis if it exceeds maxLength
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Splits text into lines, respecting word boundaries
  static List<String> wrapText(String text, int maxLineLength) {
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = StringBuffer();

    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine.write(word);
      } else if (currentLine.length + 1 + word.length <= maxLineLength) {
        currentLine.write(' $word');
      } else {
        lines.add(currentLine.toString());
        currentLine = StringBuffer(word);
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine.toString());
    }

    return lines;
  }

  /// Formats a song number with leading zeros (e.g., "001", "042", "151")
  static String formatSongNumber(int number, {int digits = 3}) {
    return number.toString().padLeft(digits, '0');
  }
}
