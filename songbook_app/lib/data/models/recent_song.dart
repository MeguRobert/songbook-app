/// A song the user has opened, with the timestamp of the most recent view.
///
/// Stored as part of the recents list in SharedPreferences. Uses hand-written
/// JSON (no codegen) to keep the POC dependency-free — the shape is trivial.
class RecentSong {
  final int songNumber;
  final DateTime viewedAt;

  const RecentSong({
    required this.songNumber,
    required this.viewedAt,
  });

  factory RecentSong.fromJson(Map<String, dynamic> json) {
    return RecentSong(
      songNumber: json['n'] as int,
      viewedAt: DateTime.fromMillisecondsSinceEpoch(json['t'] as int),
    );
  }

  Map<String, dynamic> toJson() => {
        'n': songNumber,
        't': viewedAt.millisecondsSinceEpoch,
      };

  RecentSong copyWith({int? songNumber, DateTime? viewedAt}) {
    return RecentSong(
      songNumber: songNumber ?? this.songNumber,
      viewedAt: viewedAt ?? this.viewedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentSong &&
          runtimeType == other.runtimeType &&
          songNumber == other.songNumber;

  @override
  int get hashCode => songNumber.hashCode;

  @override
  String toString() => 'RecentSong(songNumber: $songNumber, viewedAt: $viewedAt)';
}
