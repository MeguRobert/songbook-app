import 'package:json_annotation/json_annotation.dart';

part 'chord_position.g.dart';

/// Represents a chord at a specific position in a lyric line
@JsonSerializable()
class ChordPosition {
  /// The chord symbol (e.g., "Bb", "F7", "Gm")
  final String chord;

  /// Character position in the lyric text where the chord is placed
  final int position;

  const ChordPosition({
    required this.chord,
    required this.position,
  });

  factory ChordPosition.fromJson(Map<String, dynamic> json) =>
      _$ChordPositionFromJson(json);

  Map<String, dynamic> toJson() => _$ChordPositionToJson(this);

  ChordPosition copyWith({
    String? chord,
    int? position,
  }) {
    return ChordPosition(
      chord: chord ?? this.chord,
      position: position ?? this.position,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChordPosition &&
          runtimeType == other.runtimeType &&
          chord == other.chord &&
          position == other.position;

  @override
  int get hashCode => chord.hashCode ^ position.hashCode;

  @override
  String toString() => 'ChordPosition(chord: $chord, position: $position)';
}
