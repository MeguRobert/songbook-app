/// A derived tag grouping with the number of songs that carry it.
///
/// Like [Book], this is a computed/UI value object — tags themselves live on
/// [Song.tags] (plus user overrides in persistence); the counts here are
/// derived from the song collection and are NOT JSON-serialized.
class Tag {
  /// Display name of the tag (original casing preserved).
  final String name;

  /// Number of songs carrying this tag.
  final int songCount;

  const Tag({required this.name, required this.songCount});

  Tag copyWith({String? name, int? songCount}) {
    return Tag(
      name: name ?? this.name,
      songCount: songCount ?? this.songCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          songCount == other.songCount;

  @override
  int get hashCode => name.hashCode ^ songCount.hashCode;

  @override
  String toString() => 'Tag(name: $name, songCount: $songCount)';
}
