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

/// Beat-level corrections to a [SongNotation].
///
/// Correction, not composition. Every path into the app's notation is a
/// transcription and every transcription is lossy: OMR guesses a pitch,
/// mis-reads a duration, drops a note, invents one. Those four failures are what
/// these three operations answer — replace a beat, add one back, take one away.
/// Beaming, voices, articulations and dynamics are deliberately absent; that is
/// a score writer, an order of magnitude more work, for material that is always
/// being transcribed rather than written.
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
    verses[address.verse] =
        NotatedVerse(number: verse.number, measures: measures);

    return SongNotation(
      originalKey: notation.originalKey,
      timeSignature: notation.timeSignature,
      showTimeSignature: notation.showTimeSignature,
      verses: verses,
      pickup: notation.pickup,
    );
  }
}
