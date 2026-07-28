import 'package:json_annotation/json_annotation.dart';

import 'song_id.dart';

part 'favorite.g.dart';

/// Represents a favorited song
@JsonSerializable()
class Favorite {
  /// The song that was favorited.
  ///
  /// [JsonKey.readValue] falls back to the pre-[SongId] key. Renaming this
  /// field renamed the key it is stored under, so without the fallback every
  /// favourite written by a shipped build reads `null`, throws inside the
  /// converter, is dropped by `LocalDataSource._decodeRecords`, and the next
  /// save writes the now-empty list back — silent, permanent loss of the
  /// user's favourites on upgrade.
  @JsonKey(readValue: _readSongId)
  @SongIdConverter()
  final SongId songId;

  static Object? _readSongId(Map<dynamic, dynamic> json, String key) =>
      json[key] ?? json['songNumber'];

  /// When the song was favorited
  final DateTime addedAt;

  /// Order in the favorites list (for custom sorting)
  @JsonKey(defaultValue: 0)
  final int sortOrder;

  const Favorite({
    required this.songId,
    required this.addedAt,
    this.sortOrder = 0,
  });

  factory Favorite.fromJson(Map<String, dynamic> json) =>
      _$FavoriteFromJson(json);

  Map<String, dynamic> toJson() => _$FavoriteToJson(this);

  Favorite copyWith({
    SongId? songId,
    DateTime? addedAt,
    int? sortOrder,
  }) {
    return Favorite(
      songId: songId ?? this.songId,
      addedAt: addedAt ?? this.addedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Value equality over ALL fields. `sortOrder` in particular MUST be included:
  /// once favorites reordering is wired to a provider holding `List<Favorite>`, an
  /// id-only comparison would report "no change" after a reorder and the list
  /// would never redraw — exactly how Setlist.== broke setlist editing.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Favorite &&
          runtimeType == other.runtimeType &&
          songId == other.songId &&
          addedAt == other.addedAt &&
          sortOrder == other.sortOrder;

  @override
  int get hashCode => Object.hash(songId, addedAt, sortOrder);

  @override
  String toString() =>
      'Favorite(songId: $songId, addedAt: $addedAt, sortOrder: $sortOrder)';
}
