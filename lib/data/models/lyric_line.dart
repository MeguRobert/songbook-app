import 'package:json_annotation/json_annotation.dart';
import 'chord_position.dart';

part 'lyric_line.g.dart';

/// Represents a single line of lyrics with optional chord positions
@JsonSerializable()
class LyricLine {
  /// The lyric text for this line
  final String text;

  /// Chord positions for this line (can be empty)
  @JsonKey(defaultValue: [])
  final List<ChordPosition> chords;

  const LyricLine({
    required this.text,
    this.chords = const [],
  });

  factory LyricLine.fromJson(Map<String, dynamic> json) =>
      _$LyricLineFromJson(json);

  Map<String, dynamic> toJson() => _$LyricLineToJson(this);

  /// Returns true if this line has any chords
  bool get hasChords => chords.isNotEmpty;

  LyricLine copyWith({
    String? text,
    List<ChordPosition>? chords,
  }) {
    return LyricLine(
      text: text ?? this.text,
      chords: chords ?? this.chords,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLine &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          _listEquals(chords, other.chords);

  @override
  int get hashCode => text.hashCode ^ chords.hashCode;

  @override
  String toString() => 'LyricLine(text: $text, chords: $chords)';

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
