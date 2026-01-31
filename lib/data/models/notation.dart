import 'package:json_annotation/json_annotation.dart';

part 'notation.g.dart';

/// Duration of a musical note
enum NoteDuration {
  @JsonValue('whole')
  whole,
  @JsonValue('half')
  half,
  @JsonValue('quarter')
  quarter,
  @JsonValue('eighth')
  eighth,
  @JsonValue('sixteenth')
  sixteenth,
}

extension NoteDurationExtension on NoteDuration {
  /// Returns the beat value (1.0 for quarter note in 4/4)
  double get beats {
    switch (this) {
      case NoteDuration.whole:
        return 4.0;
      case NoteDuration.half:
        return 2.0;
      case NoteDuration.quarter:
        return 1.0;
      case NoteDuration.eighth:
        return 0.5;
      case NoteDuration.sixteenth:
        return 0.25;
    }
  }

  /// Returns the relative spacing multiplier
  double get spacingMultiplier {
    switch (this) {
      case NoteDuration.whole:
        return 4.0;
      case NoteDuration.half:
        return 2.5;
      case NoteDuration.quarter:
        return 1.5;
      case NoteDuration.eighth:
        return 1.0;
      case NoteDuration.sixteenth:
        return 0.75;
    }
  }
}

/// Represents a single note or rest in the notation
@JsonSerializable()
class NotatedBeat {
  /// Pitch in scientific notation (e.g., "C4", "Bb5", "F#3")
  /// Use "R" for rest
  final String pitch;

  /// Duration of the note
  final NoteDuration duration;

  /// Lyric syllable to display under this note
  final String? syllable;

  /// Chord symbol to display above this note
  final String? chord;

  /// Whether this note starts a tie
  @JsonKey(defaultValue: false)
  final bool tieStart;

  /// Whether this note ends a tie
  @JsonKey(defaultValue: false)
  final bool tieEnd;

  /// Whether this is a dotted note (1.5x duration)
  @JsonKey(defaultValue: false)
  final bool dotted;

  const NotatedBeat({
    required this.pitch,
    required this.duration,
    this.syllable,
    this.chord,
    this.tieStart = false,
    this.tieEnd = false,
    this.dotted = false,
  });

  factory NotatedBeat.fromJson(Map<String, dynamic> json) =>
      _$NotatedBeatFromJson(json);

  Map<String, dynamic> toJson() => _$NotatedBeatToJson(this);

  /// Returns true if this is a rest
  bool get isRest => pitch.toUpperCase() == 'R';

  /// Parses the pitch into note name and octave
  (String note, int octave)? get parsedPitch {
    if (isRest) return null;

    final match = RegExp(r'^([A-Ga-g][#b]?)(\d)$').firstMatch(pitch);
    if (match == null) return null;

    return (match.group(1)!.toUpperCase(), int.parse(match.group(2)!));
  }

  /// Returns the actual duration considering dotted flag
  double get actualBeats => dotted ? duration.beats * 1.5 : duration.beats;

  NotatedBeat copyWith({
    String? pitch,
    NoteDuration? duration,
    String? syllable,
    String? chord,
    bool? tieStart,
    bool? tieEnd,
    bool? dotted,
  }) {
    return NotatedBeat(
      pitch: pitch ?? this.pitch,
      duration: duration ?? this.duration,
      syllable: syllable ?? this.syllable,
      chord: chord ?? this.chord,
      tieStart: tieStart ?? this.tieStart,
      tieEnd: tieEnd ?? this.tieEnd,
      dotted: dotted ?? this.dotted,
    );
  }
}

/// Represents a measure (bar) in the notation
@JsonSerializable()
class NotatedMeasure {
  /// Beats within this measure
  final List<NotatedBeat> beats;

  /// Whether to show a repeat sign at the start
  @JsonKey(defaultValue: false)
  final bool repeatStart;

  /// Whether to show a repeat sign at the end
  @JsonKey(defaultValue: false)
  final bool repeatEnd;

  /// Whether the layout engine should insert a line break after this measure
  @JsonKey(defaultValue: false)
  final bool lineBreakAfter;

  const NotatedMeasure({
    required this.beats,
    this.repeatStart = false,
    this.repeatEnd = false,
    this.lineBreakAfter = false,
  });

  factory NotatedMeasure.fromJson(Map<String, dynamic> json) =>
      _$NotatedMeasureFromJson(json);

  Map<String, dynamic> toJson() => _$NotatedMeasureToJson(this);

  /// Total beats in this measure
  double get totalBeats => beats.fold(0.0, (sum, beat) => sum + beat.actualBeats);
}

/// Represents a verse with musical notation
@JsonSerializable()
class NotatedVerse {
  /// Verse number
  final int number;

  /// Measures in this verse
  final List<NotatedMeasure> measures;

  const NotatedVerse({
    required this.number,
    required this.measures,
  });

  factory NotatedVerse.fromJson(Map<String, dynamic> json) =>
      _$NotatedVerseFromJson(json);

  Map<String, dynamic> toJson() => _$NotatedVerseToJson(this);

  /// Gets all beats from all measures
  List<NotatedBeat> get allBeats =>
      measures.expand((m) => m.beats).toList();
}

/// Complete notation data for a song
@JsonSerializable()
class SongNotation {
  /// The original key of the notation
  final String originalKey;

  /// Time signature (e.g., "4/4", "3/4")
  final String timeSignature;

  /// Whether to display the time signature on the staff
  @JsonKey(defaultValue: true)
  final bool showTimeSignature;

  /// Notated verses (usually just verse 1 with full notation)
  final List<NotatedVerse> verses;

  /// Pickup measure (anacrusis) beats before first full measure
  final List<NotatedBeat>? pickup;

  const SongNotation({
    required this.originalKey,
    required this.timeSignature,
    this.showTimeSignature = true,
    required this.verses,
    this.pickup,
  });

  factory SongNotation.fromJson(Map<String, dynamic> json) =>
      _$SongNotationFromJson(json);

  Map<String, dynamic> toJson() => _$SongNotationToJson(this);

  /// Parses the time signature into (beats per measure, beat unit)
  (int beatsPerMeasure, int beatUnit) get parsedTimeSignature {
    final parts = timeSignature.split('/');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Gets beats per measure
  int get beatsPerMeasure => parsedTimeSignature.$1;
}
