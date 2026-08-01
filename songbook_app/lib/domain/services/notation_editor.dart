import '../../data/models/notation.dart';

/// Where a beat sits inside a [SongNotation]: which notated verse, which measure
/// of it, which beat of that measure.
///
/// A value type, not a pair of ints passed around: the editor screen keeps one
/// in state to mark the row being edited, and identity equality would have made
/// that selection never match itself after a rebuild.
class BeatAddress {
  final int verse;
  final int measure;
  final int beat;

  const BeatAddress({
    required this.verse,
    required this.measure,
    required this.beat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeatAddress &&
          runtimeType == other.runtimeType &&
          verse == other.verse &&
          measure == other.measure &&
          beat == other.beat;

  @override
  int get hashCode => Object.hash(verse, measure, beat);

  @override
  String toString() => 'BeatAddress($verse/$measure/$beat)';
}

/// Which measure of which notated verse. The address a bar-level edit takes.
///
/// Separate from [BeatAddress] rather than a supertype of it, because a bar edit
/// genuinely has no beat to name and an unused `beat: 0` would read as one.
class MeasureAddress {
  final int verse;
  final int measure;

  const MeasureAddress({required this.verse, required this.measure});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeasureAddress &&
          runtimeType == other.runtimeType &&
          verse == other.verse &&
          measure == other.measure;

  @override
  int get hashCode => Object.hash(verse, measure);

  @override
  String toString() => 'MeasureAddress($verse/$measure)';
}

/// Replacing measures `[from, to)` of a measure list with [replacement].
///
/// Every bar-level operation here is one of these, which is what lets a single
/// pass apply the same structural change to the melody and to each of the
/// score's other voices: the closure is handed each voice's OWN measure list and
/// recomputes the replacement from it, so a bar that holds two half notes in the
/// bass and four quarters in the melody still comes out as the same bar.
class _Splice {
  final int from;
  final int to;
  final List<NotatedMeasure> replacement;

  const _Splice(this.from, this.to, this.replacement);

  /// Changes nothing. What an index that does not resolve returns — a voice a
  /// hand-edited payload left shorter than the melody must not throw.
  static const none = _Splice(0, 0, []);
}

/// Corrections to a [SongNotation] — to a beat, and to the bars around it.
///
/// Correction, not composition. Every path into the app's notation is a
/// transcription and every transcription is lossy: OMR guesses a pitch,
/// mis-reads a duration, drops a note, invents one — and, most damagingly, puts
/// the bar lines in the wrong places. The beat operations answer the first four:
/// replace a beat, add one back, take one away. The measure operations answer the
/// fifth, which nothing else could: on the real `SÉ-90` Audiveris output every
/// system came back as a SINGLE measure, six bars of 18 beats in 4/4, and no
/// amount of correcting individual notes fixes that. [splitMeasure] and
/// [mergeMeasureIntoPrevious] move bar lines; [insertMeasureAfter] and
/// [deleteMeasure] add and remove whole bars.
///
/// Still not a score writer. Beaming, note entry from a blank staff,
/// articulations and dynamics remain deliberately absent — an order of magnitude
/// more work, for material that is always being transcribed rather than written.
///
/// Every operation returns a NEW notation and never mutates its argument, which
/// is what lets a widget or provider see the change: the notation classes carry
/// value equality over all their fields, so an edited beat propagates all the
/// way up to `Song.==` returning false.
///
/// An address that does not resolve is a no-op returning the notation unchanged
/// — the same silent-fallback convention `SetlistRepository` uses for an unknown
/// id. A stale index comes from a screen that rebuilt under the edit, not from a
/// programming error, so it must not throw in the user's face.
class NotationEditor {
  const NotationEditor();

  /// Replaces the beat at [address] with [beat].
  SongNotation replaceBeat(
    SongNotation notation,
    BeatAddress address,
    NotatedBeat beat,
  ) {
    return _editBeats(notation, address, (beats) {
      final next = [...beats];
      next[address.beat] = beat;
      return next;
    });
  }

  /// Inserts a copy of the beat at [address] directly after it.
  ///
  /// A note the OMR missed almost always sits next to one it read correctly, so
  /// the neighbour's pitch and duration are the closest starting point — and
  /// correcting one field beats entering four.
  ///
  /// The syllable, chord and ties are deliberately NOT copied. The lyric belongs
  /// to the note that was already there, so copying it would print the syllable
  /// twice; and a copied `tieStart` would leave a tie running into a note that
  /// is not the one it was tied to. `dotted` is copied, because it is part of
  /// the duration rather than an annotation on it.
  SongNotation insertBeatAfter(SongNotation notation, BeatAddress address) {
    return _editBeats(notation, address, (beats) {
      final source = beats[address.beat];
      return [...beats]..insert(
          address.beat + 1,
          NotatedBeat(
            pitch: source.pitch,
            duration: source.duration,
            dotted: source.dotted,
          ),
        );
    });
  }

  /// Removes the beat at [address].
  ///
  /// The measure stays even when it empties. Measures are the unit the layout
  /// engine breaks systems on, and the MusicXML importer keeps empty ones
  /// deliberately so the voices it retained stay measure-aligned — dropping one
  /// here would desynchronise them. An empty bar is recoverable; a missing bar
  /// silently shifts everything after it.
  SongNotation deleteBeat(SongNotation notation, BeatAddress address) {
    return _editBeats(
        notation, address, (beats) => [...beats]..removeAt(address.beat));
  }

  /// Starts a new measure at [address], so the addressed beat becomes the first
  /// beat of the bar after the split.
  ///
  /// The most valuable operation in this class. Audiveris returned one measure
  /// per system on the real `SÉ-90` output — six bars of 18 beats in 4/4 — and a
  /// reader staring at that needs a bar line, not a corrected note. Repeating
  /// this at the fourth beat walks an over-long bar down to 4/4 bars and leaves
  /// the remainder as its own bar, which is exactly what `--rebar` does on the
  /// Python side and what the validator names.
  ///
  /// No note is added, removed or reordered: only where the bar line falls.
  SongNotation splitMeasure(SongNotation notation, BeatAddress address) {
    final measure = _measureAt(
        notation, MeasureAddress(verse: address.verse, measure: address.measure));
    if (measure == null) return notation;
    // Before the first beat there is nothing to move into a new bar, and the
    // result would be an empty first half. Past the last is a stale address.
    if (address.beat < 1 || address.beat >= measure.beats.length) return notation;

    // Where the new bar line falls, in beats from the start of the bar. The other
    // voices are split by TIME rather than by beat index: they hold a different
    // number of notes over the same span, so beat 2 of the melody and beat 2 of
    // the bass are not the same moment.
    final offset = measure.beats
        .take(address.beat)
        .fold<double>(0, (sum, beat) => sum + beat.actualBeats);

    return _restructure(notation, address.verse, (measures) {
      if (address.measure >= measures.length) return _Splice.none;
      final target = measures[address.measure];
      final at = target == measure
          ? address.beat
          : _boundaryAt(target.beats, offset);
      return _Splice(
          address.measure, address.measure + 1, _halves(target, at));
    });
  }

  /// Folds the measure at [address] into the one before it.
  ///
  /// The inverse of [splitMeasure], and the other half of mis-barring: OMR reads
  /// one bar as two when a system breaks inside it, and a bar line in the wrong
  /// place is invisible on the staff — the two halves just look narrow.
  ///
  /// A no-op on the first measure, which has nothing before it.
  SongNotation mergeMeasureIntoPrevious(
      SongNotation notation, MeasureAddress address) {
    if (_measureAt(notation, address) == null) return notation;
    if (address.measure < 1) return notation;
    final expected = notation.beatsPerMeasure;

    return _restructure(notation, address.verse, (measures) {
      if (address.measure >= measures.length) return _Splice.none;
      return _Splice(
        address.measure - 1,
        address.measure + 1,
        [_joined(measures[address.measure - 1], measures[address.measure], expected)],
      );
    });
  }

  /// Adds a bar directly after the one at [address].
  SongNotation insertMeasureAfter(
          SongNotation notation, MeasureAddress address) =>
      _insertMeasure(notation, address, after: true);

  /// Adds a bar directly in front of the one at [address].
  ///
  /// The only way to regain a bar ahead of the first. OMR routinely mishandles
  /// the opening bar of a page, and a dropped anacrusis is the commonest case.
  SongNotation insertMeasureBefore(
          SongNotation notation, MeasureAddress address) =>
      _insertMeasure(notation, address, after: false);

  /// Removes the measure at [address] and everything in it.
  ///
  /// The only way out of the empty bar [deleteBeat] leaves behind on purpose, and
  /// the fix for a bar OMR invented outright.
  ///
  /// The last measure of a verse stays: an empty measure list gives the layout
  /// engine nothing to lay out, and there would be no row left to insert a bar
  /// from — a dead end with no way back.
  SongNotation deleteMeasure(SongNotation notation, MeasureAddress address) {
    if (_measureAt(notation, address) == null) return notation;
    if (notation.verses[address.verse].measures.length <= 1) return notation;

    return _restructure(notation, address.verse, (measures) {
      if (address.measure >= measures.length) return _Splice.none;
      return _Splice(address.measure, address.measure + 1, const []);
    });
  }

  /// Sets everything about the bar at [address] that is not a note.
  ///
  /// Repeat signs, volta brackets, system breaks and the pickup declaration all
  /// belong to the measure, and an imported score frequently gets them wrong —
  /// `MusicXmlImporter` had no `<barline>` case at all until recently, so every
  /// repeat in an older import was simply dropped. The editor preserved them and
  /// could not change them, and there is no other way to correct them.
  ///
  /// Every flag is required rather than optional-and-merged, because this is the
  /// one place they are all edited together: the sheet always knows the complete
  /// answer, and a `null` here would be ambiguous between "off" and "unchanged".
  /// [volta] is genuinely nullable — null means no bracket.
  ///
  /// The other voices are deliberately untouched: these properties belong to the
  /// bar rather than to the line singing it, only the engraved stream carries
  /// them, and `engravedAs` projects them onto whichever voice is being read.
  SongNotation setMeasureFlags(
    SongNotation notation,
    MeasureAddress address, {
    required bool repeatStart,
    required bool repeatEnd,
    required bool lineBreakAfter,
    required bool isPickup,
    required int? volta,
  }) {
    final measure = _measureAt(notation, address);
    if (measure == null) return notation;

    final measures = [...notation.verses[address.verse].measures];
    measures[address.measure] = measure.copyWith(
      repeatStart: repeatStart,
      repeatEnd: repeatEnd,
      lineBreakAfter: lineBreakAfter,
      isPickup: isPickup,
      volta: volta,
      clearVolta: volta == null,
    );

    final verses = [...notation.verses];
    verses[address.verse] =
        notation.verses[address.verse].copyWith(measures: measures);
    return notation.copyWith(verses: verses);
  }

  /// Relabels voice [index] of the score's other voices.
  ///
  /// Audiveris names parts `P1`, `P2`, `P3`, and those names are exactly what the
  /// voice picker in the song controls offers a singer choosing a line to read.
  ///
  /// A blank name is ignored rather than written: a voice with no label is one the
  /// picker cannot offer at all.
  SongNotation renameVoice(SongNotation notation, int index, String name) {
    final voices = notation.voices;
    if (voices == null || index < 0 || index >= voices.length) return notation;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return notation;

    final next = [...voices];
    next[index] = voices[index].copyWith(name: trimmed);
    return notation.copyWith(voices: next);
  }

  /// Drops voice [index] from the score.
  ///
  /// For a voice the OMR invented — Audiveris produces phantom parts from staff
  /// artefacts. Destructive, and the reason nothing is written until Save.
  ///
  /// Removing the last one leaves an EMPTY list rather than null, because
  /// `copyWith` cannot write null and does not need to: an empty list behaves
  /// identically everywhere — `hasMultipleVoices` is false, `voiceNames` is just
  /// the melody, and `engravedAs` returns the score unchanged for any index.
  SongNotation removeVoice(SongNotation notation, int index) {
    final voices = notation.voices;
    if (voices == null || index < 0 || index >= voices.length) return notation;
    return notation.copyWith(voices: [...voices]..removeAt(index));
  }

  SongNotation _insertMeasure(
    SongNotation notation,
    MeasureAddress address, {
    required bool after,
  }) {
    if (_measureAt(notation, address) == null) return notation;
    final at = after ? address.measure + 1 : address.measure;
    // One rest, not an empty bar. `deleteBeat` leaves empty bars behind
    // deliberately and the beat list has no row to address in one, so an empty
    // bar is a bar you can never put a note into. A single rest at the beat unit
    // gives the list a row, the edit sheet turns it into a note, and
    // `insertBeatAfter` fills the rest of the bar from there.
    //
    // No flags are carried over from the neighbour: an inherited repeat sign
    // would appear where the score has none, and an inherited `isPickup` would
    // quietly exempt the new bar from the one check that catches a lost beat.
    final blank = NotatedMeasure(beats: [
      NotatedBeat(pitch: 'R', duration: _beatUnit(notation)),
    ]);

    return _restructure(
        notation, address.verse, (measures) => _Splice(at, at, [blank]));
  }

  /// The note value one beat of [notation]'s time signature lasts.
  static NoteDuration _beatUnit(SongNotation notation) =>
      switch (notation.parsedTimeSignature.$2) {
        1 => NoteDuration.whole,
        2 => NoteDuration.half,
        8 => NoteDuration.eighth,
        16 => NoteDuration.sixteenth,
        _ => NoteDuration.quarter,
      };

  /// [measure] cut in two at beat [at].
  ///
  /// A bar's opening belongs to the first half and its close to the second:
  /// `repeatStart` opens a bar, while `repeatEnd` and a system break close one.
  /// A bar carrying `:‖:` therefore becomes a repeated section two bars long,
  /// which is what the signs meant in the first place.
  static List<NotatedMeasure> _halves(NotatedMeasure measure, int at) => [
        measure.copyWith(
          beats: measure.beats.sublist(0, at),
          repeatEnd: false,
          lineBreakAfter: false,
        ),
        measure.copyWith(
          beats: measure.beats.sublist(at),
          repeatStart: false,
          // Never the second half. `isPickup` means "short on purpose", and the
          // editor answers it by showing neither the arithmetic nor the warning —
          // so a bar in the MIDDLE of the score wearing it would be a damaged bar
          // hidden behind the flag that exists to tell the two apart. Only the
          // first half can still be the anacrusis; a volta bracket, by contrast,
          // is a run of bars sharing a number, so both halves stay under it.
          isPickup: false,
        ),
      ];

  /// [previous] with [current]'s beats appended.
  static NotatedMeasure _joined(
    NotatedMeasure previous,
    NotatedMeasure current,
    int expected,
  ) {
    final beats = [...previous.beats, ...current.beats];
    final total = beats.fold<double>(0, (sum, b) => sum + b.actualBeats);

    return previous.copyWith(
      beats: beats,
      // The merged bar starts where `previous` did and ends where `current` did,
      // so it keeps the first's opening and the second's close.
      repeatEnd: current.repeatEnd,
      lineBreakAfter: current.lineBreakAfter,
      // Whichever bracket it was under, preferring the one it starts in. Silently
      // dropping a volta is the worse failure of the two — an imported score
      // frequently gets them wrong and this editor is the only way to fix them.
      volta: previous.volta ?? current.volta,
      // Whether a SHORT bar is an upbeat or a bar the transcription damaged is
      // exactly the ambiguity `isPickup` exists to answer, and this does not
      // touch that. But an anacrusis is by definition shorter than a full bar, so
      // a merged bar that now meets the signature is not one whatever it used to
      // be — and leaving the flag on would exempt a full bar from the arithmetic
      // for good.
      isPickup: previous.isPickup && total < expected - 0.001,
    );
  }

  /// The beat index in [beats] at which a bar line [offset] beats into the bar
  /// falls.
  ///
  /// A note that straddles the line stays in the FIRST bar: it starts before the
  /// line, and it cannot be divided without splitting the note in two, which
  /// would either lose a note or invent one.
  static int _boundaryAt(List<NotatedBeat> beats, double offset) {
    var elapsed = 0.0;
    for (var i = 0; i < beats.length; i++) {
      if (elapsed >= offset - 0.001) return i;
      elapsed += beats[i].actualBeats;
    }
    return beats.length;
  }

  /// The measure at [address], or null if the address does not resolve.
  static NotatedMeasure? _measureAt(
      SongNotation notation, MeasureAddress address) {
    if (address.verse < 0 || address.verse >= notation.verses.length) return null;
    final measures = notation.verses[address.verse].measures;
    if (address.measure < 0 || address.measure >= measures.length) return null;
    return measures[address.measure];
  }

  /// Applies [splice] to the measures of verse [verseIndex] **and to the same
  /// position in every one of the score's other voices**.
  ///
  /// The voices are aligned measure for measure — the contract the MusicXML
  /// importer establishes by rest-padding them, and what `engravedAs` relies on
  /// to hand a bass line the melody's repeats, voltas and system breaks. A bar
  /// added to or removed from the melody alone would shift every later bar of
  /// every other voice by one, so the bass would be handed the wrong bar's
  /// repeat sign and the score would read as wrong rather than as unfinished.
  ///
  /// [splice] is called once per measure list and recomputes from the list it is
  /// given, which is what makes one closure correct for all of them.
  SongNotation _restructure(
    SongNotation notation,
    int verseIndex,
    _Splice Function(List<NotatedMeasure> measures) splice,
  ) {
    if (verseIndex < 0 || verseIndex >= notation.verses.length) return notation;
    final verse = notation.verses[verseIndex];

    final verses = [...notation.verses];
    verses[verseIndex] =
        verse.copyWith(measures: _spliced(verse.measures, splice(verse.measures)));

    final voices = notation.voices;
    if (voices == null) return notation.copyWith(verses: verses);

    return notation.copyWith(
      verses: verses,
      voices: [
        for (final voice in voices)
          voice.copyWith(
              measures: _spliced(voice.measures, splice(voice.measures))),
      ],
    );
  }

  static List<NotatedMeasure> _spliced(
    List<NotatedMeasure> measures,
    _Splice splice,
  ) {
    if (splice.from < 0 ||
        splice.to > measures.length ||
        splice.from > splice.to) {
      return measures;
    }
    return [...measures]
      ..replaceRange(splice.from, splice.to, splice.replacement);
  }

  /// Applies [transform] to the beats of the measure at [address], rebuilding
  /// the notation around it and leaving everything else identical.
  ///
  /// The bounds check covers [address.beat] as well, so `transform` may index it
  /// directly.
  SongNotation _editBeats(
    SongNotation notation,
    BeatAddress address,
    List<NotatedBeat> Function(List<NotatedBeat> beats) transform,
  ) {
    if (address.verse < 0 || address.verse >= notation.verses.length) {
      return notation;
    }
    final verse = notation.verses[address.verse];
    if (address.measure < 0 || address.measure >= verse.measures.length) {
      return notation;
    }
    final measure = verse.measures[address.measure];
    if (address.beat < 0 || address.beat >= measure.beats.length) {
      return notation;
    }

    final measures = [...verse.measures];
    // copyWith, not a fresh NotatedMeasure: this changes the beats and nothing
    // else, and spelling out the other fields made every field added to the
    // model a field an edit would silently drop. It already had — `isPickup`
    // and `volta` were both being lost here, so correcting one note in an
    // upbeat bar came back flagged as a bar the transcription had damaged.
    measures[address.measure] =
        measure.copyWith(beats: transform(measure.beats));

    final verses = [...notation.verses];
    verses[address.verse] = verse.copyWith(measures: measures);

    // copyWith all the way up, for the third time in this file's history. Spelled
    // out, this dropped `voices` — added to the model after this code was
    // written — so a four-part score came back from one corrected note with its
    // alto, tenor and bass gone, and reading the bass line meant finding and
    // re-importing the source file.
    return notation.copyWith(verses: verses);
  }
}
