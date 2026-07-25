import 'package:json_annotation/json_annotation.dart';

part 'setlist.g.dart';

/// An ordered, named list of songs for a service or event.
///
/// A setlist references songs by their [number] (the same identity used by
/// [Song] and [Favorite]); it does not embed the songs themselves. The order of
/// [songNumbers] is significant — it is the order songs are played during a
/// service.
@JsonSerializable()
class Setlist {
  /// Stable unique identifier (generated when the setlist is created).
  final String id;

  /// User-facing setlist name (e.g., "Sunday Morning").
  final String name;

  /// Ordered song numbers in this setlist.
  @JsonKey(defaultValue: [])
  final List<int> songNumbers;

  /// When the setlist was created.
  final DateTime createdAt;

  /// When the setlist was last modified.
  final DateTime updatedAt;

  const Setlist({
    required this.id,
    required this.name,
    this.songNumbers = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Setlist.fromJson(Map<String, dynamic> json) =>
      _$SetlistFromJson(json);

  Map<String, dynamic> toJson() => _$SetlistToJson(this);

  /// Number of songs in the setlist.
  int get length => songNumbers.length;

  /// Whether the setlist has no songs.
  bool get isEmpty => songNumbers.isEmpty;

  Setlist copyWith({
    String? id,
    String? name,
    List<int>? songNumbers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Setlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songNumbers: songNumbers ?? this.songNumbers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Setlist &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Setlist(id: $id, name: $name, songNumbers: $songNumbers)';
}
