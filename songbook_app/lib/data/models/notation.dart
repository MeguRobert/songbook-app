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
    bool clearVolta = false,
  }) {
    return NotatedMeasure(
      beats: beats ?? this.beats,
      repeatStart: repeatStart ?? this.repeatStart,
      repeatEnd: repeatEnd ?? this.repeatEnd,
      lineBreakAfter: lineBreakAfter ?? this.lineBreakAfter,
      isPickup: isPickup ?? this.isPickup,
      // `copyWith(volta: null)` cannot take a bracket off: null falls through the
      // `??` and keeps the old number. That default is right everywhere else —
      // omitting a field must mean "leave it alone" — but it made "no longer
      // under a bracket" inexpressible, so a volta the OMR invented could not be
      // removed. [clearVolta] says it explicitly, which is better than the
      // alternative of spelling the constructor out at the call site: that is a
      // field-by-field rebuild, and this file's whole history is fields lost to
      // one of those.
      volta: clearVolta ? null : (volta ?? this.volta),
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

  /// Exists for the same reason [NotatedMeasure.copyWith] does: a pass that
  /// re-bars a verse changes [measures] and nothing else, and spelling out
  /// [number] alongside it makes the verse number a thing that pass can lose.
  ///
  /// The verse number identifies which words the notation belongs to, so losing
  /// it detaches the bars from the text they carry.
  NotatedVerse copyWith({
    int? number,
    List<NotatedMeasure>? measures,
  }) {
    return NotatedVerse(
      number: number ?? this.number,
      measures: measures ?? this.measures,
    );
  }

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

/// One voice of a multi-voice score, beyond the one being engraved.
///
/// Hymnal MusicXML is usually four-voice SATB while [SongNotation] renders a
/// single monophonic stream, so importing has always reduced a score to its top
/// line. The importer recovered the other three all along and the app then threw
/// them away — nothing stored them — so reading a bass line meant finding and
/// re-importing the source file.
@JsonSerializable()
class NotatedVoice {
  /// What to call this line in a picker: `Alto`, or the part name the file gave.
  final String name;

  /// Aligned measure-for-measure with the engraved stream, gaps filled with
  /// rests by the importer, so switching voices cannot shift the bar numbering.
  final List<NotatedMeasure> measures;

  const NotatedVoice({required this.name, required this.measures});

  factory NotatedVoice.fromJson(Map<String, dynamic> json) =>
      _$NotatedVoiceFromJson(json);

  Map<String, dynamic> toJson() => _$NotatedVoiceToJson(this);

  /// Exists for the same reason every other `copyWith` in this file does: a pass
  /// that re-bars a voice changes [measures] and must not be able to lose the
  /// name the voice picker shows.
  NotatedVoice copyWith({
    String? name,
    List<NotatedMeasure>? measures,
  }) {
    return NotatedVoice(
      name: name ?? this.name,
      measures: measures ?? this.measures,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotatedVoice &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          const ListEquality<NotatedMeasure>().equals(measures, other.measures);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(measures));
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

  /// The score's other voices — the alto, tenor and bass of an SATB hymn — kept
  /// so they are not lost, and so any one of them can be engraved in place of
  /// [verses] via [withVoice].
  ///
  /// Null rather than empty for a single-voice score, and for every song stored
  /// before this field existed. Renaming a JSON key has destroyed stored data
  /// here before, so this is only ever added, never changed.
  final List<NotatedVoice>? voices;

  const SongNotation({
    required this.originalKey,
    required this.timeSignature,
    this.showTimeSignature = true,
    required this.verses,
    this.pickup,
    this.voices,
  });

  /// The voice selection meaning "engrave them all at once, one staff each".
  ///
  /// Negative so it cannot collide with a real index however many voices a score
  /// grows, and so a stored 0 keeps meaning the melody. It is not a voice, and
  /// [engravedAs] deliberately does nothing with it: a grand staff needs the score
  /// as stored, with `verses` still the top line and `voices` still the rest.
  static const int allVoices = -1;

  /// Every voice this score holds, engraved one first.
  ///
  /// The engraved stream has no name of its own — it is whatever the importer
  /// reduced the score to — so it is called `Melody`, which is what it is for a
  /// singer choosing a line to read.
  List<String> get voiceNames =>
      ['Melody', ...?voices?.map((v) => v.name)];

  /// Whether there is anything to choose between.
  bool get hasMultipleVoices => (voices?.isNotEmpty ?? false);

  /// This score as it should be engraved when voice [index] is selected.
  ///
  /// Index 0 is the score unchanged; 1 and up select [voices] in order. The
  /// verse number is kept because it identifies which words the notation belongs
  /// to — a property of the song, not of the line singing it — and the voice
  /// list is carried through so the picker still has something to offer.
  ///
  /// **Apply this to the STORED notation, never to its own output.** It is a
  /// render-time projection, not a mutation: index 0 means "leave it alone", so
  /// `engravedAs(2).engravedAs(0)` gives back the bass line rather than the
  /// melody. The melody is not kept anywhere in the result — it is whatever
  /// `verses` held before the swap. Callers read `song.notation` fresh each
  /// build, which is where this is safe.
  ///
  /// An index out of range returns the score unchanged. A picker offering a
  /// voice a re-import has since removed should show the melody, not throw.
  SongNotation engravedAs(int index) {
    if (index == 0) return this;
    final all = voices;
    if (all == null || index < 1 || index > all.length) return this;

    final verse = verses.isEmpty ? null : verses.first;
    final structure = verse?.measures ?? const <NotatedMeasure>[];
    final chosen = all[index - 1].measures;

    return SongNotation(
      originalKey: originalKey,
      timeSignature: timeSignature,
      showTimeSignature: showTimeSignature,
      verses: [
        NotatedVerse(
          number: verse?.number ?? 1,
          measures: [
            for (var i = 0; i < chosen.length; i++)
              // A repeat sign, a volta bracket and a system break belong to the
              // BAR, not to the line singing it: every voice of a four-part
              // score shares them. Only the engraved stream is given them by the
              // importer, so without this the bass arrived with beats and
              // nothing else — no repeats, no voltas, and systems broken
              // somewhere different from the melody's.
              //
              // Built directly rather than with copyWith: the melody's bar has
              // to WIN, and `copyWith(volta: null)` cannot clear a value — it
              // falls through the `??` and keeps the old one. Every field of
              // NotatedMeasure is spelled out here on purpose, so a field added
              // to the model is a compile error in this list rather than one the
              // projection silently drops.
              if (i < structure.length)
                NotatedMeasure(
                  beats: chosen[i].beats,
                  repeatStart: structure[i].repeatStart,
                  repeatEnd: structure[i].repeatEnd,
                  lineBreakAfter: structure[i].lineBreakAfter,
                  isPickup: structure[i].isPickup,
                  volta: structure[i].volta,
                )
              else
                // A voice longer than the melody keeps its extra bars. The
                // importer pads voices to match, but a hand-edited payload need
                // not, and dropping bars would lose notes.
                chosen[i],
          ],
        ),
      ],
      pickup: pickup,
      voices: all,
    );
  }

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

  /// The whole score with one thing changed.
  ///
  /// The most load-bearing `copyWith` in this file, because the editor's every
  /// operation changes [verses] and must leave the other five fields exactly as
  /// they were. Rebuilding this class field by field has already cost real data
  /// twice: the MusicXML importer lost [NotatedMeasure.isPickup] that way, and
  /// the beat editor was silently dropping [voices] — a four-part score came back
  /// from one corrected note with its alto, tenor and bass gone, so reading the
  /// bass line meant finding and re-importing the source file.
  ///
  /// **Cannot clear a nullable field.** `copyWith(voices: null)` falls through
  /// the `??` and keeps the old list, which is right for every caller here — an
  /// edit to the melody must never be what deletes the other voices. Anything
  /// that genuinely needs to null one out passes an empty list (which behaves
  /// identically everywhere: [hasMultipleVoices] is false, [voiceNames] is just
  /// the melody, and [engravedAs] returns the score unchanged) or spells the
  /// constructor out, the way [engravedAs] does and for the same reason.
  SongNotation copyWith({
    String? originalKey,
    String? timeSignature,
    bool? showTimeSignature,
    List<NotatedVerse>? verses,
    List<NotatedBeat>? pickup,
    List<NotatedVoice>? voices,
  }) {
    return SongNotation(
      originalKey: originalKey ?? this.originalKey,
      timeSignature: timeSignature ?? this.timeSignature,
      showTimeSignature: showTimeSignature ?? this.showTimeSignature,
      verses: verses ?? this.verses,
      pickup: pickup ?? this.pickup,
      voices: voices ?? this.voices,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongNotation &&
          runtimeType == other.runtimeType &&
          originalKey == other.originalKey &&
          timeSignature == other.timeSignature &&
          showTimeSignature == other.showTimeSignature &&
          const ListEquality<NotatedVerse>().equals(verses, other.verses) &&
          const ListEquality<NotatedBeat>().equals(pickup, other.pickup) &&
          const ListEquality<NotatedVoice>().equals(voices, other.voices);

  @override
  int get hashCode => Object.hash(
        originalKey,
        timeSignature,
        showTimeSignature,
        Object.hashAll(verses),
        pickup == null ? null : Object.hashAll(pickup!),
        voices == null ? null : Object.hashAll(voices!),
      );
}
