import 'package:json_annotation/json_annotation.dart';

part 'favorite.g.dart';

/// Represents a favorited song
@JsonSerializable()
class Favorite {
  /// The song number that was favorited
  final int songNumber;

  /// When the song was favorited
  final DateTime addedAt;

  /// Order in the favorites list (for custom sorting)
  @JsonKey(defaultValue: 0)
  final int sortOrder;

  const Favorite({
    required this.songNumber,
    required this.addedAt,
    this.sortOrder = 0,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) =>
      _$FavoriteFromJson(json);

  Map<String, dynamic> toJson() => _$FavoriteToJson(this);

  Favorite copyWith({
    int? songNumber,
    DateTime? addedAt,
    int? sortOrder,
  }) {
    return Favorite(
      songNumber: songNumber ?? this.songNumber,
      addedAt: addedAt ?? this.addedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Favorite &&
          runtimeType == other.runtimeType &&
          songNumber == other.songNumber;

  @override
  int get hashCode => songNumber.hashCode;

  @override
  String toString() =>
      'Favorite(songNumber: $songNumber, addedAt: $addedAt, sortOrder: $sortOrder)';
}
