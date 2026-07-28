import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'notation.dart';
import 'song_id.dart';
import 'verse.dart';

part 'song.g.dart';

/// Origin information for a song or tune
@JsonSerializable()
class Origin {
  final String? place;
  final int? year;

  const Origin({this.place, this.year});

  factory Origin.fromJson(Map<String, dynamic> json) => _$OriginFromJson(json);

  Map<String, dynamic> toJson() => _$OriginToJson(this);

  String? get displayString {
    if (place == null && year == null) return null;
    if (place != null && year != null) return '$place, $year';
    return place ?? year?.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Origin &&
          runtimeType == other.runtimeType &&
          place == other.place &&
          year == other.year;

  @override
  int get hashCode => place.hashCode ^ year.hashCode;
}

/// Tune information for a song
@JsonSerializable()
class Tune {
  final String? name;
  final Origin? origin;

  const Tune({this.name, this.origin});

  factory Tune.fromJson(Map<String, dynamic> json) => _$TuneFromJson(json);

  Map<String, dynamic> toJson() => _$TuneToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tune &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          origin == other.origin;

  @override
  int get hashCode => name.hashCode ^ origin.hashCode;
}

/// Sheet music configuration
@JsonSerializable()
class SheetMusic {
  /// Type of sheet music file (svg, musicxml)
  final String type;

  /// Base path without key suffix (e.g., "assets/sheet_music/151")
  final String basePath;

  const SheetMusic({
    required this.type,
    required this.basePath,
  });

  factory SheetMusic.fromJson(Map<String, dynamic> json) =>
      _$SheetMusicFromJson(json);

  Map<String, dynamic> toJson() => _$SheetMusicToJson(this);

  /// Gets the full path for a specific key
  String getPathForKey(String key) => '${basePath}_$key.$type';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SheetMusic &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          basePath == other.basePath;

  @override
  int get hashCode => type.hashCode ^ basePath.hashCode;
}

/// Represents a complete song with all metadata and verses
@JsonSerializable()
class Song {
  /// Unique song number in the hymnal
  final int number;

  /// Song title
  final String title;

  /// Biblical or other reference (e.g., "Zsolt 6")
  final String? reference;

  /// Origin information
  final Origin? origin;

  /// Tune information
  final Tune? tune;

  /// Original key of the song (e.g., "Bb", "G")
  final String originalKey;

  /// Time signature (e.g., "4/4", "3/4")
  final String? timeSignature;

  /// Sheet music configuration (legacy SVG-based)
  final SheetMusic? sheetMusic;

  /// Structured notation data for custom rendering
  final SongNotation? notation;

  /// Song verses
  final List<Verse> verses;

  /// Tags for categorization and search
  @JsonKey(defaultValue: [])
  final List<String> tags;

  /// Book/hymnal this song belongs to (e.g., "Zsoltárok", "Dicséretek").
  /// Null when the song has not been assigned to a book.
  final String? book;

  const Song({
    required this.number,
    required this.title,
    this.reference,
    this.origin,
    this.tune,
    required this.originalKey,
    this.timeSignature,
    this.sheetMusic,
    this.notation,
    required this.verses,
    this.tags = const [],
    this.book,
  });

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);

  Map<String, dynamic> toJson() => _$SongToJson(this);

  /// How everything else in the app refers to this song.
  ///
  /// Every song in the catalogue today comes from a bundled hymnal, so its
  /// identity is derived from [number]. When locally authored songs land this
  /// becomes a stored field defaulting to the same thing — the point of routing
  /// all references through [SongId] now is that nothing downstream has to
  /// change when it does.
  SongId get id => SongId.hymnal(number);

  /// Gets the first verse (typically has notation)
  Verse? get firstVerse => verses.isNotEmpty ? verses.first : null;

  /// Gets verses without notation (2nd verse onwards typically)
  List<Verse> get additionalVerses =>
      verses.where((v) => !v.hasNotation).toList();

  /// Returns true if this song has sheet music (legacy SVG)
  bool get hasSheetMusic => sheetMusic != null;

  /// Returns true if this song has structured notation data
  bool get hasNotation => notation != null;

  /// Returns true if this song has chord data
  bool get hasChords =>
      verses.any((v) => v.lines.any((l) => l.chords.isNotEmpty));

  /// Returns true if this song has been assigned to a book
  bool get hasBook => book != null && book!.isNotEmpty;

  /// Formatted display number (e.g., "151")
  String get displayNumber => number.toString();

  Song copyWith({
    int? number,
    String? title,
    String? reference,
    Origin? origin,
    Tune? tune,
    String? originalKey,
    String? timeSignature,
    SheetMusic? sheetMusic,
    SongNotation? notation,
    List<Verse>? verses,
    List<String>? tags,
    String? book,
  }) {
    return Song(
      number: number ?? this.number,
      title: title ?? this.title,
      reference: reference ?? this.reference,
      origin: origin ?? this.origin,
      tune: tune ?? this.tune,
      originalKey: originalKey ?? this.originalKey,
      timeSignature: timeSignature ?? this.timeSignature,
      sheetMusic: sheetMusic ?? this.sheetMusic,
      notation: notation ?? this.notation,
      verses: verses ?? this.verses,
      tags: tags ?? this.tags,
      book: book ?? this.book,
    );
  }

  /// Value equality over ALL fields.
  ///
  /// This compared `number` and nothing else, so any two songs sharing a number
  /// were interchangeable — a song whose tags, verses or book had changed was
  /// indistinguishable from the original. That is the identity-only-equality
  /// trap behind the setlist bug, and it becomes unusable once songs are
  /// editable: an edited song must not equal its own previous version.
  ///
  /// Depends on [SongNotation] and [Verse] carrying value equality too;
  /// both were fixed alongside this.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          title == other.title &&
          reference == other.reference &&
          origin == other.origin &&
          tune == other.tune &&
          originalKey == other.originalKey &&
          timeSignature == other.timeSignature &&
          sheetMusic == other.sheetMusic &&
          notation == other.notation &&
          book == other.book &&
          const ListEquality<Verse>().equals(verses, other.verses) &&
          const ListEquality<String>().equals(tags, other.tags);

  @override
  int get hashCode => Object.hash(
        number,
        title,
        reference,
        origin,
        tune,
        originalKey,
        timeSignature,
        sheetMusic,
        notation,
        book,
        Object.hashAll(verses),
        Object.hashAll(tags),
      );

  @override
  String toString() => 'Song(number: $number, title: $title)';
}
