import 'package:collection/collection.dart';
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

  /// Value equality over ALL fields, `lines` included.
  ///
  /// `lines` used to be excluded. That was invisible while verses were built
  /// once from the bundled catalogue and only read, but the song editor mutates
  /// them: `verse.copyWith(lines: …)` returned a verse that compared **equal**
  /// to the original, so an edit reached no widget or provider that diffs
  /// verses. Same family as the identity-only `Song.==` that caused the setlist
  /// bug.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Verse &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          hasNotation == other.hasNotation &&
          plainText == other.plainText &&
          const ListEquality<LyricLine>().equals(lines, other.lines);

  @override
  int get hashCode =>
      Object.hash(number, hasNotation, plainText, Object.hashAll(lines));

  @override
  String toString() =>
      'Verse(number: $number, hasNotation: $hasNotation, lines: ${lines.length})';
}
