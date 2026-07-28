import 'song_id.dart';

/// A song the user has opened, with the timestamp of the most recent view.
///
/// Stored as part of the recents list in SharedPreferences. Uses hand-written
/// JSON (no codegen) to keep the POC dependency-free — the shape is trivial.
class RecentSong {
  final SongId songId;
  final DateTime viewedAt;

  const RecentSong({
    required this.songId,
    required this.viewedAt,
  });

  factory RecentSong.fromJson(Map<String, dynamic> json) {
    return RecentSong(
      // Accepts a bare int: that is how every recent written before
      // song ids existed is stored.
      songId: SongId.fromJson(json['n'])!,
      viewedAt: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
    );
  }

  Map<String, dynamic> toJson() => {
        'n': songId.value,
        't': viewedAt.millisecondsSinceEpoch,
      };

  RecentSong copyWith({SongId? songId, DateTime? viewedAt}) {
    return RecentSong(
      songId: songId ?? this.songId,
      viewedAt: viewedAt ?? this.viewedAt,
    );
  }

  /// Value equality over ALL fields. Must include [viewedAt]: providers compare
  /// old and new values with `==` to decide whether to rebuild, so ignoring a
  /// mutable field silently suppresses UI updates — the bug that made setlist
  /// edits invisible until Setlist.== was fixed the same way.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentSong &&
          runtimeType == other.runtimeType &&
          songId == other.songId &&
          viewedAt == other.viewedAt;

  @override
  int get hashCode => Object.hash(songId, viewedAt);

  @override
  String toString() => 'RecentSong(songId: $songId, viewedAt: $viewedAt)';
}
