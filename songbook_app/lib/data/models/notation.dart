import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';

part 'notation.g.dart';

// Every class in this file carries value equality over ALL of its fields,
// including its lists. Notation used to be built once at load time and only
// ever read, so identity equality was invisible; the song import and the
// beat-level correction editor both mutate it, and a `copyWith` that compares
// equal to its own original is a change no widget or provider can see.

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

  /// Lyric syllable to display under this note (single line)
  final String? syllable;

  /// Multiple lyric syllables for stacked display (e.g., verse 1 and verse 2)
  final List<String>? syllables;

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
    this.syllables,
    this.chord,
    this.tieStart = false,
    this.tieEnd = false,
    this.dotted = false,
  });

  /// Returns all syllables (from syllables array or single syllable)
  List<String> get allSyllables {
    if (syllables != null && syllables!.isNotEmpty) {
      return syllables!;
    }
    if (syllable != null) {
      return [syllable!];
    }
    return [];
  }

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
    List<String>? syllables,
    String? chord,
    bool? tieStart,
    bool? tieEnd,
    bool? dotted,
  }) {
    return NotatedBeat(
      pitch: pitch ?? this.pitch,
      duration: duration ?? this.duration,
      syllable: syllable ?? this.syllable,
      syllables: syllables ?? this.syllables,
      chord: chord ?? this.chord,
      tieStart: tieStart ?? this.tieStart,
      tieEnd: tieEnd ?? this.tieEnd,
      dotted: dotted ?? this.dotted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotatedBeat &&
          runtimeType == other.runtimeType &&
          pitch == other.pitch &&
          duration == other.duration &&
          syllable == other.syllable &&
          const ListEquality<String>().equals(syllables, other.syllables) &&
          chord == other.chord &&
          tieStart == other.tieStart &&
          tieEnd == other.tieEnd &&
          dotted == other.dotted;

  @override
  int get hashCode => Object.hash(
        pitch,
        duration,
        syllable,
        syllables == null ? null : Object.hashAll(syllables!),
        chord,
        tieStart,
        tieEnd,
        dotted,
      );
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

  /// Whether this bar is an anacrusis — a pickup/upbeat, deliberately shorter
  /// than the time signature.
  ///
  /// The renderer needs nothing from this: measures are spaced from their
  /// content, so a short bar already engraves narrow. It exists because a short
  /// bar is otherwise ambiguous — it is either a legitimate upbeat or a bar
  /// where the transcription lost a beat, and those want opposite treatment.
  /// The correction editor flags the second in red, and would flag every upbeat
  /// hymn with it. MusicXML states which it is (`implicit="yes"`); this carries
  /// that answer instead of guessing from the beat count.
  @JsonKey(defaultValue: false)
  final bool isPickup;

  /// The volta (second-time bar) bracket this measure sits under, or null.
  ///
  /// Carried per measure rather than as a span, so a bracket needs no separate
  /// start/end bookkeeping: a run of measures sharing a number *is* the bracket,
  /// and the layout engine draws the hook where the run begins and ends. That
  /// also survives line breaking for free — half a bracket on each of two
  /// systems is what an engraver does anyway.
  final int? volta;

  const NotatedMeasure({
    required this.beats,
    this.repeatStart = false,
    this.repeatEnd = false,
    this.lineBreakAfter = false,
    this.isPickup = false,
    this.volta,
  });

  factory NotatedMeasure.fromJson(Map<String, dynamic> json) =>
      _$NotatedMeasureFromJson(json);

  Map<String, dynamic> toJson() => _$NotatedMeasureToJson(this);

  /// Total beats in this measure
  double get totalBeats => beats.fold(0.0, (sum, beat) => sum + beat.actualBeats);

  /// Exists so the passes that rebuild a measure to change one thing cannot
  /// silently drop the rest.
  ///
  /// The MusicXML importer's line-break pass rebuilt measures field by field,
  /// which meant every field added here was one that pass would lose — and
  /// [isPickup] was lost exactly that way before this existed.
  NotatedMeasure copyWith({
    List<NotatedBeat>? beats,
    bool? repeatStart,
    bool? repeatEnd,
    bool? lineBreakAfter,
    bool? isPickup,
    int? volta,
  }) {
    return NotatedMeasure(
      beats: beats ?? this.beats,
      repeatStart: repeatStart ?? this.repeatStart,
      repeatEnd: repeatEnd ?? this.repeatEnd,
      lineBreakAfter: lineBreakAfter ?? this.lineBreakAfter,
      isPickup: isPickup ?? this.isPickup,
      volta: volta ?? this.volta,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotatedMeasure &&
          runtimeType == other.runtimeType &&
          const ListEquality<NotatedBeat>().equals(beats, other.beats) &&
          repeatStart == other.repeatStart &&
          repeatEnd == other.repeatEnd &&
          lineBreakAfter == other.lineBreakAfter &&
          isPickup == other.isPickup &&
          volta == other.volta;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(beats),
        repeatStart,
        repeatEnd,
        lineBreakAfter,
        isPickup,
        volta,
      );
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotatedVerse &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          const ListEquality<NotatedMeasure>().equals(measures, other.measures);

  @override
  int get hashCode => Object.hash(number, Object.hashAll(measures));
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

  /// Pickup measure (anacrusis) beats before the first full measure.
  ///
  /// **Superseded, and never populated by anything.** No importer writes it, no
  /// bundled song declares it, and neither the renderer nor the layout engine
  /// reads it — verified across `lib/`, `songs.json` and `tools/`.
  ///
  /// It is redundant by construction: an anacrusis *is* a measure with fewer
  /// beats, measures are spaced from their content so a short one already
  /// engraves narrow, and [NotatedMeasure.isPickup] carries the only thing a
  /// short bar cannot say for itself — whether it is short on purpose. Kept
  /// solely so a payload that somehow contains the key still decodes.
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongNotation &&
          runtimeType == other.runtimeType &&
          originalKey == other.originalKey &&
          timeSignature == other.timeSignature &&
          showTimeSignature == other.showTimeSignature &&
          const ListEquality<NotatedVerse>().equals(verses, other.verses) &&
          const ListEquality<NotatedBeat>().equals(pickup, other.pickup);

  @override
  int get hashCode => Object.hash(
        originalKey,
        timeSignature,
        showTimeSignature,
        Object.hashAll(verses),
        pickup == null ? null : Object.hashAll(pickup!),
      );
}
