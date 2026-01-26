import 'package:json_annotation/json_annotation.dart';
import 'lyric_line.dart';

part 'verse.g.dart';

/// Represents a verse of a song
@JsonSerializable()
class Verse {
  /// Verse number (1-indexed)
  final int number;

  /// Whether this verse has musical notation (first verse typically does)
  @JsonKey(defaultValue: false)
  final bool hasNotation;

  /// Structured lines with chord positions (for verses with notation)
  @JsonKey(defaultValue: [])
  final List<LyricLine> lines;

  /// Plain text for verses without notation
  final String? plainText;

  const Verse({
    required this.number,
    this.hasNotation = false,
    this.lines = const [],
    this.plainText,
  });

  factory Verse.fromJson(Map<String, dynamic> json) => _$VerseFromJson(json);

  Map<String, dynamic> toJson() => _$VerseToJson(this);

  /// Gets the display text for this verse
  String get displayText {
    if (plainText != null && plainText!.isNotEmpty) {
      return plainText!;
    }
    return lines.map((line) => line.text).join('\n');
  }

  /// Returns true if this verse has structured chord data
  bool get hasChordData => lines.any((line) => line.hasChords);

  Verse copyWith({
    int? number,
    bool? hasNotation,
    List<LyricLine>? lines,
    String? plainText,
  }) {
    return Verse(
      number: number ?? this.number,
      hasNotation: hasNotation ?? this.hasNotation,
      lines: lines ?? this.lines,
      plainText: plainText ?? this.plainText,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Verse &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          hasNotation == other.hasNotation &&
          plainText == other.plainText;

  @override
  int get hashCode =>
      number.hashCode ^ hasNotation.hashCode ^ plainText.hashCode;

  @override
  String toString() =>
      'Verse(number: $number, hasNotation: $hasNotation, lines: ${lines.length})';
}
