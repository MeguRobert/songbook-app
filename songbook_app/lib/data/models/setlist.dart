import 'package:json_annotation/json_annotation.dart';

import 'song_id.dart';

part 'setlist.g.dart';

/// An ordered, named list of songs for a service or event.
///
/// A setlist references songs by their [number] (the same identity used by
/// [Song] and [Favorite]); it does not embed the songs themselves. The order of
/// [songIds] is significant — it is the order songs are played during a
/// service.
@JsonSerializable()
class Setlist {
  /// Stable unique identifier (generated when the setlist is created).
  final String id;

  /// User-facing setlist name (e.g., "Sunday Morning").
  final String name;

  /// Ordered song numbers in this setlist.
  /// [JsonKey.readValue] falls back to the pre-[SongId] key. Renaming this
  /// field renamed the key it is stored under; without the fallback a stored
  /// `{"songNumbers":[1,42]}` reads `null`, quietly takes the `defaultValue`
  /// of `[]`, and the setlist survives by name with every song gone — no
  /// exception, no warning, and the next save persists the emptiness.
  @JsonKey(defaultValue: [], readValue: _readSongIds)
  @SongIdConverter()
  final List<SongId> songIds;

  static Object? _readSongIds(Map<dynamic, dynamic> json, String key) =>
      json[key] ?? json['songNumbers'];

  /// When the setlist was created.
  final DateTime createdAt;

  /// When the setlist was last modified.
  final DateTime updatedAt;

  const Setlist({
    required this.id,
    required this.name,
    this.songIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Setlist.fromJson(Map<String, dynamic> json) =>
      _$SetlistFromJson(json);

  Map<String, dynamic> toJson() => _$SetlistToJson(this);

  /// Number of songs in the setlist.
  int get length => songIds.length;

  /// Whether the setlist has no songs.
  bool get isEmpty => songIds.isEmpty;

  Setlist copyWith({
    String? id,
    String? name,
    List<SongId>? songIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Setlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Value equality over ALL fields, including [songIds].
  ///
  /// This must not be id-only. Riverpod (and Flutter's widget diffing) decide
  /// whether to rebuild by comparing old and new values with `==`, so a
  /// Setlist whose equality ignored its song list made providers report "no
  /// change" after add/remove/reorder — the write persisted but the UI only
  /// refreshed after leaving and re-entering the screen.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Setlist || runtimeType != other.runtimeType) return false;
    if (songIds.length != other.songIds.length) return false;
    for (var i = 0; i < songIds.length; i++) {
      if (songIds[i] != other.songIds[i]) return false;
    }
    return id == other.id &&
        name == other.name &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        Object.hashAll(songIds),
        createdAt,
        updatedAt,
      );

  @override
  String toString() =>
      'Setlist(id: $id, name: $name, songIds: $songIds)';
}
