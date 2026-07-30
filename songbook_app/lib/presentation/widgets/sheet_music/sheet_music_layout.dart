import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/engraving_constants.dart';
import '../../../data/models/notation.dart';

/// Positioned element on the sheet music
class PositionedElement {
  final double x;
  final double y;
  final double width;
  final double height;

  const PositionedElement({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Rect get rect => Rect.fromLTWH(x, y, width, height);
}

/// A positioned note with all rendering information
class PositionedNote extends PositionedElement {
  final NotatedBeat beat;
  final String transposedPitch;
  final String? transposedChord;
  final bool stemUp;
  final int staffLine; // Which line/space the note is on
  final int measureIndex; // Which measure this note belongs to
  final int beatIndex; // Which beat within the measure (for beam grouping)
  final int beamGroup; // Group ID for beaming (notes with same ID beam together)

  const PositionedNote({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.beat,
    required this.transposedPitch,
    this.transposedChord,
    required this.stemUp,
    required this.staffLine,
    this.measureIndex = 0,
    this.beatIndex = 0,
    this.beamGroup = -1,
  });
}

/// A positioned syllable with text and alignment
class PositionedSyllable {
  final String text;
  final double x;
  final double y;
  final double width;
  final bool isWordContinuation; // Has hyphen before
  final bool continuesWord; // Has hyphen after
  final int lineIndex; // Which lyric line (0 = first, 1 = second for stacked)

  const PositionedSyllable({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.isWordContinuation,
    required this.continuesWord,
    this.lineIndex = 0,
  });
}

/// A positioned chord symbol
class PositionedChord {
  final String chord;
  final double x;
  final double y;

  const PositionedChord({
    required this.chord,
    required this.x,
    required this.y,
  });
}

/// A positioned bar line
class PositionedBarLine {
  final double x;
  final double topY;
  final double bottomY;
  final bool isDouble;
  final bool isFinal;
  final bool repeatStart;
  final bool repeatEnd;

  /// Staff tops at which repeat dots belong, when this line serves more than one
  /// staff.
  ///
  /// A grand staff draws ONE bar line through the whole group, so the line's own
  /// [topY] is the top of the *group* and says nothing about where the staves
  /// inside it sit. Empty means the single-staff case, where [topY] is the staff
  /// top and is the only anchor there is.
  final List<double> repeatDotStaffTops;

  const PositionedBarLine({
    required this.x,
    required this.topY,
    required this.bottomY,
    this.isDouble = false,
    this.isFinal = false,
    this.repeatStart = false,
    this.repeatEnd = false,
    this.repeatDotStaffTops = const [],
  });

  /// The staff tops at which this line's repeat dots belong.
  ///
  /// Falls back to [topY] for a line serving a single staff, which is the only
  /// anchor there is in that case.
  List<double> get dotAnchors =>
      repeatDotStaffTops.isEmpty ? [topY] : repeatDotStaffTops;

  /// Exists so the normalisation pass that moves the last bar line out to the
  /// right edge cannot silently drop a field — the same mistake that has already
  /// cost [NotatedMeasure.isPickup] and nearly cost `voltas`.
  PositionedBarLine copyWith({double? x}) => PositionedBarLine(
        x: x ?? this.x,
        topY: topY,
        bottomY: bottomY,
        isDouble: isDouble,
        isFinal: isFinal,
        repeatStart: repeatStart,
        repeatEnd: repeatEnd,
        repeatDotStaffTops: repeatDotStaffTops,
      );
}

/// A positioned volta ("second-time bar") bracket.
///
/// One per run of measures sharing a [NotatedMeasure.volta] number, per system:
/// a bracket crossing a line break is drawn as two of these, which is what an
/// engraver does too. The hooks say which ends are real ends of the run rather
/// than the edge of a system, so neither half grows a hook it should not have.
class PositionedVolta {
  final int number;
  final double startX;
  final double endX;

  /// Top of the bracket. The horizontal stroke sits here; the hooks drop from
  /// it.
  final double y;

  /// The run begins here, so the left end turns down into the staff.
  final bool hasStartHook;

  /// The run ends here, so the right end turns down.
  ///
  /// Always true where a run ends. MusicXML distinguishes `stop` (hooked) from
  /// `discontinue` (open), but [NotatedMeasure] keeps only the number, so the
  /// difference is not available here. It is cosmetic.
  final bool hasEndHook;

  const PositionedVolta({
    required this.number,
    required this.startX,
    required this.endX,
    required this.y,
    required this.hasStartHook,
    required this.hasEndHook,
  });
}

/// Represents a single staff system (one line of music)
class StaffSystem {
  final double x;
  final double y;
  final double width;
  final List<PositionedNote> notes;
  final List<PositionedSyllable> syllables;
  final List<PositionedChord> chords;
  final List<PositionedBarLine> barLines;

  /// Volta brackets over this system, if any.
  final List<PositionedVolta> voltas;

  final int startMeasure;
  final int endMeasure;

  /// Which line of music this staff belongs to.
  ///
  /// Not the same as this system's index in [SheetMusicLayout.systems] once a
  /// grand staff is involved: four voices on one line are four systems sharing
  /// one index. The painter draws the time signature on the first line only, and
  /// "first" has to mean the line or three of the four staves would lose it.
  final int systemIndex;

  /// The clef this staff is read in. Treble for every single-voice score.
  final StaffClef clef;

  /// The name of the voice on this staff, drawn to the left of the clef, or null
  /// when there is only one staff and nothing to distinguish.
  ///
  /// Already localised by the caller: the engine has no `BuildContext`, and a
  /// part name may also have come from the imported file rather than from the
  /// app's own vocabulary.
  final String? label;

  const StaffSystem({
    required this.x,
    required this.y,
    required this.width,
    required this.notes,
    required this.syllables,
    required this.chords,
    required this.barLines,
    this.voltas = const [],
    required this.startMeasure,
    required this.endMeasure,
    this.systemIndex = 0,
    this.clef = StaffClef.treble,
    this.label,
  });

  /// Exists so the normalisation pass in [SheetMusicLayoutEngine] cannot
  /// silently drop a field.
  ///
  /// That pass rebuilds every system to widen it to the widest one, and it used
  /// to spell out each field — which made every field added here one the pass
  /// would lose. `voltas` would have been the first casualty; the same mistake
  /// already cost `NotatedMeasure.isPickup` once.
  StaffSystem copyWith({
    double? width,
    List<PositionedBarLine>? barLines,
    List<PositionedVolta>? voltas,
  }) {
    return StaffSystem(
      x: x,
      y: y,
      width: width ?? this.width,
      notes: notes,
      syllables: syllables,
      chords: chords,
      barLines: barLines ?? this.barLines,
      voltas: voltas ?? this.voltas,
      startMeasure: startMeasure,
      endMeasure: endMeasure,
      systemIndex: systemIndex,
      clef: clef,
      label: label,
    );
  }

  double get staffTop => y;
  double get staffBottom => y + EngravingConstants.staffHeight;
  double get lyricY => staffBottom + EngravingConstants.lyricBelowStaff;
  double get chordY => staffTop - EngravingConstants.chordAboveStaff;

  /// How many stacked lyric rows this system actually draws.
  ///
  /// Derived from the syllables rather than from the notation, because that is
  /// the question the spacing needs answered: a verse can declare three lyric
  /// lines and a given system still carry none of them.
  int get lyricLineCount => syllables.isEmpty
      ? 0
      : syllables.map((s) => s.lineIndex).reduce(math.max) + 1;

  /// The bottom of everything this system occupies, lyrics included.
  ///
  /// This is what the next system is placed below. It used to be a fixed sum
  /// that assumed exactly one lyric row — too much for an engraved score with no
  /// `<lyric>` elements at all, which is most imported ones, and too little for
  /// a hymn with three verses stacked under the notes.
  double get contentBottom {
    final lines = lyricLineCount;
    if (lines == 0) {
      return staffBottom + EngravingConstants.staffOnlyBelowStaff;
    }
    return staffBottom +
        EngravingConstants.lyricBelowStaff +
        (lines - 1) * EngravingConstants.lyricLineSpacing +
        EngravingConstants.lyricRowHeight;
  }
}

/// Layout result containing all positioned elements
class SheetMusicLayout {
  final double totalWidth;
  final double totalHeight;
  final List<StaffSystem> systems;
  final String key;
  final String timeSignature;
  final bool showTimeSignature;

  const SheetMusicLayout({
    required this.totalWidth,
    required this.totalHeight,
    required this.systems,
    required this.key,
    required this.timeSignature,
    this.showTimeSignature = true,
  });
}

/// One voice as the grand staff needs it: its bars, the clef it reads, and what
/// to call it at the left of its staff.
class _GrandVoice {
  final String label;
  final StaffClef clef;
  final List<NotatedMeasure> measures;

  const _GrandVoice({
    required this.label,
    required this.clef,
    required this.measures,
  });
}

/// The horizontal grid of one bar, shared by every voice in it.
///
/// Keyed by the offset from the start of the bar in 64th notes rather than in
/// beats: accumulating doubles and comparing them for equality is exactly how a
/// dotted-rhythm voice would quietly stop sharing the grid and drift out of
/// alignment with the others. Integers make coincidence exact.
class _MeasureGrid {
  final Map<int, double> _x;

  /// Where the bar's first note sits, so a volta bracket can be spanned from it.
  final double startX;

  /// Where the bar's content ends, before the bar line's own spacing.
  final double endX;

  const _MeasureGrid(this._x, this.startX, this.endX);

  /// 64ths per quarter note. Fine enough for anything the model can express: the
  /// shortest duration is a sixteenth and the longest modifier is a dot.
  static const int _ticksPerBeat = 64;

  static int ticksOf(NotatedBeat beat) =>
      (beat.actualBeats * _ticksPerBeat).round();

  /// The x for a moment in the bar. A tick the grid does not know cannot happen
  /// for a voice that was measured into it, so this falls back to the last known
  /// x rather than throwing — a hand-edited payload should render oddly, not
  /// crash.
  double xAt(int tick) => _x[tick] ?? (_x.isEmpty ? startX : _x.values.last);
}

/// Engine that calculates layout for sheet music notation
/// Implements optical spacing based on professional engraving standards
class SheetMusicLayoutEngine {
  final double availableWidth;
  final String Function(String pitch, int semitones) transposePitch;
  final String Function(String chord, int semitones) transposeChord;
  final bool showChords;

  // Cached text painters for accurate width measurement
  final Map<String, double> _textWidthCache = {};

  SheetMusicLayoutEngine({
    required this.availableWidth,
    required this.transposePitch,
    required this.transposeChord,
    this.showChords = true,
  });

  /// Calculate the complete layout for a song's notation
  SheetMusicLayout calculateLayout(
    SongNotation notation,
    int transposeSemitones,
  ) {
    final systems = <StaffSystem>[];
    final targetKey = transposeChord(notation.originalKey, transposeSemitones);

    // Reduce top padding when chords are hidden
    double currentY = showChords ? EngravingConstants.chordAboveStaff + 20 : 20;

    for (final verse in notation.verses) {
      final verseSystems = _layoutVerse(
        verse,
        currentY,
        transposeSemitones,
        notation.timeSignature,
        targetKey,
        systemIndexBase: systems.length,
      );
      systems.addAll(verseSystems);

      if (verseSystems.isNotEmpty) {
        currentY =
            verseSystems.last.contentBottom + EngravingConstants.systemSpacing;
      }
    }

    return _normalise(
      systems,
      notation,
      targetKey,
      leftEdge: EngravingConstants.leftMargin,
    );
  }

  /// Widen every system to the widest one, push each last bar line out to the
  /// right edge, and wrap the result up.
  ///
  /// Shared by the single-staff and grand-staff paths: both produce systems whose
  /// natural widths differ, and a page of music whose systems end at different x
  /// reads as broken.
  SheetMusicLayout _normalise(
    List<StaffSystem> systems,
    SongNotation notation,
    String targetKey, {
    required double leftEdge,
  }) {
    final totalHeight = systems.isEmpty
        ? 200.0
        // A trailing margin rather than another full system gap: nothing follows.
        : systems.last.contentBottom + EngravingConstants.staffLineSpacing * 2;

    // Calculate actual content width from widest system
    final maxSystemWidth = systems.isEmpty
        ? availableWidth
        : systems.map((s) => s.width).reduce((a, b) => a > b ? a : b);

    // Normalize all systems to the same width (the widest one)
    // Also move the final bar line to the right edge
    final normalizedSystems = systems.map((s) {
      // Calculate the right edge position
      final rightEdge = s.x + maxSystemWidth - EngravingConstants.rightMargin;

      // Adjust the last bar line to be at the right edge
      final lastX = s.barLines.isEmpty ? null : s.barLines.last.x;
      final adjustedBarLines = s.barLines.isNotEmpty
          ? [
              ...s.barLines.take(s.barLines.length - 1),
              s.barLines.last.copyWith(x: rightEdge),
            ]
          : s.barLines;

      // A bracket that ran to the old last bar line follows it out to the edge,
      // so the two do not end a system's width apart.
      final adjustedVoltas = lastX == null
          ? s.voltas
          : [
              for (final volta in s.voltas)
                if ((volta.endX - lastX).abs() < 0.5)
                  PositionedVolta(
                    number: volta.number,
                    startX: volta.startX,
                    endX: rightEdge,
                    y: volta.y,
                    hasStartHook: volta.hasStartHook,
                    hasEndHook: volta.hasEndHook,
                  )
                else
                  volta,
            ];

      return s.copyWith(
        width: maxSystemWidth,
        barLines: adjustedBarLines,
        voltas: adjustedVoltas,
      );
    }).toList();

    // Add some padding on the right
    final contentWidth = leftEdge + maxSystemWidth + EngravingConstants.rightMargin;

    return SheetMusicLayout(
      totalWidth: contentWidth,
      totalHeight: totalHeight,
      systems: normalizedSystems,
      key: targetKey,
      timeSignature: notation.timeSignature,
      showTimeSignature: notation.showTimeSignature,
    );
  }

  List<StaffSystem> _layoutVerse(
    NotatedVerse verse,
    double startY,
    int transposeSemitones,
    String timeSignature,
    String key, {
    int systemIndexBase = 0,
  }) {
    final systems = <StaffSystem>[];
    final measures = verse.measures;

    // Check if any measure has explicit line break markers
    final hasExplicitBreaks = measures.any((m) => m.lineBreakAfter);

    int measureIndex = 0;
    double currentY = startY;

    while (measureIndex < measures.length) {
      int endIndex;

      if (hasExplicitBreaks) {
        // Use explicit line breaks from the data
        endIndex = measureIndex + 1;
        while (endIndex < measures.length &&
               !measures[endIndex - 1].lineBreakAfter) {
          endIndex++;
        }
      } else {
        // Fall back to calculated measures per line
        final measuresPerLine = _calculateOptimalMeasuresPerLine(measures);
        endIndex = (measureIndex + measuresPerLine).clamp(0, measures.length);
      }

      final lineMeasures = measures.sublist(measureIndex, endIndex);

      final system = _layoutSystem(
        lineMeasures,
        currentY,
        measureIndex,
        endIndex - 1,
        transposeSemitones,
        true, // Show clef and key on every system
        endIndex >= measures.length, // Is last system
        key,
        // The volta on either side of this system, so a bracket that carries on
        // past a line break does not sprout a hook at the break.
        voltaBefore: measureIndex > 0 ? measures[measureIndex - 1].volta : null,
        voltaAfter: endIndex < measures.length ? measures[endIndex].volta : null,
        systemIndex: systemIndexBase + systems.length,
      );

      systems.add(system);

      measureIndex = endIndex;
      currentY = system.contentBottom + EngravingConstants.systemSpacing;
    }

    return systems;
  }

  // ==========================================================================
  // GRAND STAFF — every voice of a four-part score at once
  // ==========================================================================

  /// Engrave every voice of a multi-voice score simultaneously, on stacked
  /// staves sharing one horizontal grid.
  ///
  /// This could not be done by calling [calculateLayout] once per voice, and that
  /// is the whole difficulty: that path spaces each measure from *its own* notes,
  /// so a bar of four quarters and a bar of two halves come out different widths.
  /// Soprano and bass would then put their bar lines at different x and the score
  /// would read as wrong rather than as unfinished.
  ///
  /// So the horizontal positions are computed for all voices together, from the
  /// union of the moments at which any voice starts a note. A voice's note is
  /// placed at the x of the moment it begins, whoever else begins there.
  ///
  /// [voiceLabels] are the names to draw at the left of each staff, engraved
  /// stream first, and are expected to be localised already — the engine has no
  /// `BuildContext`. Defaults to [SongNotation.voiceNames].
  ///
  /// A single-voice score is delegated to [calculateLayout] unchanged: there is
  /// nothing to stack, and it must not pay for a grid or a label inset it does
  /// not need.
  SheetMusicLayout calculateGrandStaffLayout(
    SongNotation notation,
    int transposeSemitones, {
    List<String>? voiceLabels,
  }) {
    if (!notation.hasMultipleVoices) {
      return calculateLayout(notation, transposeSemitones);
    }

    final targetKey = transposeChord(notation.originalKey, transposeSemitones);
    final labels = voiceLabels ?? notation.voiceNames;
    final structure = notation.verses.isEmpty
        ? const <NotatedMeasure>[]
        : notation.verses.first.measures;
    final extra = notation.voices!;

    final parts = <_GrandVoice>[
      _GrandVoice(
        label: labels.isNotEmpty ? labels.first : 'Melody',
        clef: _clefFor(structure),
        measures: structure,
      ),
      for (var i = 0; i < extra.length; i++)
        _GrandVoice(
          label: i + 1 < labels.length ? labels[i + 1] : extra[i].name,
          clef: _clefFor(extra[i].measures),
          measures: extra[i].measures,
        ),
    ];

    // The bar count is the LONGEST voice, not the melody's. The importer pads
    // voices to match, but a hand-edited payload need not, and truncating to the
    // melody would drop notes rather than merely mis-space them.
    final barCount =
        parts.map((p) => p.measures.length).fold(0, (a, b) => math.max(a, b));
    if (barCount == 0) {
      return _normalise(const [], notation, targetKey,
          leftEdge: EngravingConstants.leftMargin);
    }

    // Room at the left for the widest voice name. Uniform across staves and
    // systems, so the staves stay left-aligned with each other.
    final labelWidth = parts
        .map((p) =>
            _measureTextWidth(p.label, EngravingConstants.staffLabelStyle))
        .fold(0.0, math.max);
    final leftEdge = EngravingConstants.leftMargin +
        labelWidth +
        EngravingConstants.staffLabelToClefSpace;

    // How many bars fit on a line is decided from the WIDEST voice in each bar:
    // a bass line of eight eighth notes under a soprano whole note needs the
    // room, and asking the melody alone would not know that.
    final widestPerBar = <NotatedMeasure>[
      for (var i = 0; i < barCount; i++) _widestMeasureAt(parts, i),
    ];

    final systems = <StaffSystem>[];
    double currentY = showChords ? EngravingConstants.chordAboveStaff + 20 : 20;
    var lineIndex = 0;
    var bar = 0;

    while (bar < barCount) {
      final end = _lineEnd(structure, widestPerBar, bar, barCount);
      final line = _layoutGrandLine(
        parts,
        bar,
        end,
        currentY,
        transposeSemitones,
        targetKey,
        structure: structure,
        systemIndex: lineIndex,
        isLastLine: end >= barCount,
        leftEdge: leftEdge,
      );
      systems.addAll(line);
      currentY = line.last.contentBottom + EngravingConstants.systemSpacing;
      bar = end;
      lineIndex++;
    }

    return _normalise(systems, notation, targetKey, leftEdge: leftEdge);
  }

  /// Which bar this line of music ends before.
  ///
  /// Explicit breaks come from the melody, because a system break belongs to the
  /// bar rather than to the line singing it — the same reason repeats and voltas
  /// do. Beyond the melody's own length there is nothing to ask, so the count
  /// falls through to the calculated one.
  int _lineEnd(
    List<NotatedMeasure> structure,
    List<NotatedMeasure> widestPerBar,
    int from,
    int barCount,
  ) {
    if (structure.any((m) => m.lineBreakAfter)) {
      var end = from + 1;
      while (end < barCount &&
          !(end - 1 < structure.length && structure[end - 1].lineBreakAfter)) {
        end++;
      }
      return end;
    }
    final perLine = _calculateOptimalMeasuresPerLine(widestPerBar);
    return (from + perLine).clamp(0, barCount);
  }

  /// The bar at [index] as engraved by whichever voice needs the most room for
  /// it. Used only to count bars per line.
  NotatedMeasure _widestMeasureAt(List<_GrandVoice> parts, int index) {
    NotatedMeasure widest = const NotatedMeasure(beats: []);
    var best = -1.0;
    for (final part in parts) {
      if (index >= part.measures.length) continue;
      final width = _estimateMeasureWidth(part.measures[index]);
      if (width > best) {
        best = width;
        widest = part.measures[index];
      }
    }
    return widest;
  }

  /// Which clef a voice reads, decided from where it actually sits.
  ///
  /// Derived from the notes rather than from the part's name, so a two-voice or
  /// five-voice score works, and so an SATB file that labels its parts in
  /// Hungarian is not mistaken for a soprano quartet. The test is which staff's
  /// middle the voice's median pitch is nearer — the treble staff centres on B4
  /// and the bass staff on D3, and a line put in the wrong one is nothing but
  /// ledger lines.
  StaffClef _clefFor(List<NotatedMeasure> measures) {
    final steps = <int>[];
    for (final measure in measures) {
      for (final beat in measure.beats) {
        final parsed = beat.parsedPitch;
        if (parsed == null) continue;
        final letter = parsed.$1.substring(0, 1);
        steps.add((parsed.$2 - 4) * 7 +
            (EngravingConstants.notePositions[letter] ?? 0));
      }
    }
    // An empty or all-rest voice has no opinion; the treble clef is the one every
    // other staff in this app already reads.
    if (steps.isEmpty) return StaffClef.treble;

    steps.sort();
    final median = steps.length.isOdd
        ? steps[steps.length ~/ 2].toDouble()
        : (steps[steps.length ~/ 2 - 1] + steps[steps.length ~/ 2]) / 2;

    // B4 and D3 in the same diatonic-steps-from-C4 units as above.
    const trebleCentre = 6;
    const bassCentre = -6;
    return (median - bassCentre).abs() < (median - trebleCentre).abs()
        ? StaffClef.bass
        : StaffClef.treble;
  }

  /// One line of music, as one staff per voice.
  ///
  /// The staves are built top down because each is placed below the previous
  /// one's [StaffSystem.contentBottom], which depends on how many lyric rows that
  /// staff actually drew. The bar lines are attached to the top staff afterwards,
  /// for the same reason: they run to the BOTTOM staff's lower line, which is not
  /// known until every staff has been placed.
  List<StaffSystem> _layoutGrandLine(
    List<_GrandVoice> parts,
    int firstBar,
    int endBar,
    double topY,
    int transposeSemitones,
    String key, {
    required List<NotatedMeasure> structure,
    required int systemIndex,
    required bool isLastLine,
    required double leftEdge,
  }) {
    // The structure bars this line covers, padded so a melody shorter than the
    // longest voice cannot index out of range.
    final lineStructure = <NotatedMeasure>[
      for (var bar = firstBar; bar < endBar; bar++)
        bar < structure.length
            ? structure[bar]
            : const NotatedMeasure(beats: []),
    ];

    // ---- the shared horizontal grid ----------------------------------------
    final keySignatureWidth = EngravingConstants.getKeySignatureWidth(key);
    final afterHead = leftEdge +
        EngravingConstants.clefWidth +
        EngravingConstants.clefToKeySpace +
        keySignatureWidth +
        EngravingConstants.keyToTimeSpace +
        EngravingConstants.timeToNoteSpace;
    final openingLineX = afterHead - 5;
    final opensRepeat = lineStructure.isNotEmpty && lineStructure.first.repeatStart;

    var cursor = afterHead;
    if (opensRepeat) cursor += EngravingConstants.repeatSignWidth;

    final grids = <_MeasureGrid>[];
    final barLineX = <double>[];
    for (var i = 0; i < lineStructure.length; i++) {
      final grid = _gridFor(parts, firstBar + i, cursor);
      grids.add(grid);
      cursor = grid.endX + EngravingConstants.measureSpacing / 2;
      if (lineStructure[i].repeatEnd) {
        cursor += EngravingConstants.repeatSignWidth;
      }
      barLineX.add(cursor);
      cursor += EngravingConstants.measureSpacing / 2;
      if (i + 1 < lineStructure.length && lineStructure[i + 1].repeatStart) {
        cursor += EngravingConstants.repeatSignWidth;
      }
    }
    final lineWidth = cursor - leftEdge;

    // ---- one staff per voice, on that grid ---------------------------------
    final staves = <StaffSystem>[];
    for (final part in parts) {
      final y = staves.isEmpty
          ? topY
          : staves.last.contentBottom + EngravingConstants.grandStaffSpacing;
      staves.add(_layoutGrandStaff(
        part,
        firstBar,
        endBar,
        y,
        transposeSemitones,
        grids,
        lineWidth: lineWidth,
        leftEdge: leftEdge,
        systemIndex: systemIndex,
        // Volta brackets sit above the whole group, so they belong to the top
        // staff and nowhere else. Chords and words are per staff — the melody
        // carries both in an imported score and the other voices carry neither,
        // which is exactly the right output.
        voltaStructure: staves.isEmpty ? lineStructure : null,
        voltaBefore: firstBar > 0 && firstBar - 1 < structure.length
            ? structure[firstBar - 1].volta
            : null,
        voltaAfter:
            endBar < structure.length ? structure[endBar].volta : null,
        measureStartX: [for (final grid in grids) grid.startX],
        measureEndX: barLineX,
      ));
    }

    // ---- one bar line through the whole group ------------------------------
    final staffTops = [for (final staff in staves) staff.staffTop];
    final groupTop = staves.first.staffTop;
    final groupBottom = staves.last.staffBottom;

    final lines = <PositionedBarLine>[
      PositionedBarLine(
        x: openingLineX,
        topY: groupTop,
        bottomY: groupBottom,
        repeatStart: opensRepeat,
        repeatDotStaffTops: staffTops,
      ),
      for (var i = 0; i < lineStructure.length; i++)
        () {
          final isFinal = i == lineStructure.length - 1 && isLastLine;
          final opensNext = i + 1 < lineStructure.length &&
              lineStructure[i + 1].repeatStart;
          return PositionedBarLine(
            x: barLineX[i],
            topY: groupTop,
            bottomY: groupBottom,
            isFinal: isFinal,
            isDouble: isFinal || lineStructure[i].repeatEnd || opensNext,
            repeatEnd: lineStructure[i].repeatEnd,
            repeatStart: opensNext,
            repeatDotStaffTops: staffTops,
          );
        }(),
    ];

    staves[0] = staves.first.copyWith(barLines: lines);
    return staves;
  }

  /// One voice's staff for one line, with every note placed on the shared grid.
  StaffSystem _layoutGrandStaff(
    _GrandVoice part,
    int firstBar,
    int endBar,
    double y,
    int transposeSemitones,
    List<_MeasureGrid> grids, {
    required double lineWidth,
    required double leftEdge,
    required int systemIndex,
    required List<NotatedMeasure>? voltaStructure,
    required int? voltaBefore,
    required int? voltaAfter,
    required List<double> measureStartX,
    required List<double> measureEndX,
  }) {
    final notes = <PositionedNote>[];
    final syllables = <PositionedSyllable>[];
    final chords = <PositionedChord>[];
    final staffBottom = y + EngravingConstants.staffHeight;
    var globalBeamGroup = 0;

    for (var i = 0; i < endBar - firstBar; i++) {
      final barIndex = firstBar + i;
      if (barIndex >= part.measures.length) continue;
      final measure = part.measures[barIndex];
      final grid = grids[i];
      final beamGroups = _calculateBeamGroupsForMeasure(measure.beats);

      var tick = 0;
      for (var j = 0; j < measure.beats.length; j++) {
        final beat = measure.beats[j];
        final x = grid.xAt(tick);
        tick += _MeasureGrid.ticksOf(beat);

        final transposedPitch = beat.isRest
            ? beat.pitch
            : transposePitch(beat.pitch, transposeSemitones);
        final noteY = beat.isRest
            ? y + EngravingConstants.staffHeight / 2
            : EngravingConstants.getYPositionForPitch(
                transposedPitch,
                staffBottom,
                clef: part.clef,
              );

        final localBeamGroup = beamGroups[j];
        final beamGroup =
            localBeamGroup >= 0 ? globalBeamGroup + localBeamGroup : -1;

        final note = PositionedNote(
          x: x,
          y: noteY - EngravingConstants.noteHeadHeight / 2,
          width: EngravingConstants.noteHeadWidth,
          height: EngravingConstants.noteHeadHeight,
          beat: beat,
          transposedPitch: transposedPitch,
          transposedChord: beat.chord != null
              ? transposeChord(beat.chord!, transposeSemitones)
              : null,
          stemUp: _calculateStemDirection(noteY, y),
          staffLine: _calculateStaffLine(noteY, y),
          measureIndex: barIndex,
          beatIndex: j,
          beamGroup: beamGroup,
        );
        notes.add(note);

        if (note.transposedChord != null) {
          chords.add(PositionedChord(
            chord: note.transposedChord!,
            x: x,
            y: y - EngravingConstants.chordAboveStaff,
          ));
        }

        final allSyllables = beat.allSyllables;
        for (var lineIdx = 0; lineIdx < allSyllables.length; lineIdx++) {
          final syllableText = allSyllables[lineIdx];
          if (syllableText.isEmpty) continue;

          final continuesWord = syllableText.endsWith('-');
          final displayText = continuesWord
              ? syllableText.substring(0, syllableText.length - 1)
              : syllableText;
          final textWidth =
              _measureTextWidth(displayText, EngravingConstants.lyricStyle);

          syllables.add(PositionedSyllable(
            text: displayText,
            x: x + EngravingConstants.noteHeadWidth / 2 - textWidth / 2,
            y: staffBottom +
                EngravingConstants.lyricBelowStaff +
                (lineIdx * EngravingConstants.lyricLineSpacing),
            width: textWidth,
            isWordContinuation: false,
            continuesWord: continuesWord,
            lineIndex: lineIdx,
          ));
        }
      }

      final maxLocalGroup = beamGroups.isEmpty
          ? -1
          : beamGroups.reduce((a, b) => a > b ? a : b);
      if (maxLocalGroup >= 0) globalBeamGroup += maxLocalGroup + 1;
    }

    return StaffSystem(
      x: leftEdge,
      y: y,
      width: lineWidth,
      notes: notes,
      syllables: syllables,
      chords: chords,
      barLines: const [],
      voltas: voltaStructure == null
          ? const []
          : _layoutVoltas(
              voltaStructure,
              measureStartX,
              measureEndX,
              staffTop: y,
              voltaBefore: voltaBefore,
              voltaAfter: voltaAfter,
            ),
      startMeasure: firstBar,
      endMeasure: endBar - 1,
      systemIndex: systemIndex,
      clef: part.clef,
      label: part.label,
    );
  }

  /// The shared grid for one bar: an x for every moment at which any voice starts
  /// a note.
  ///
  /// The widths are solved as constraints rather than accumulated, because a note
  /// can span several of those moments — a bass half note over two soprano
  /// quarters has to be at least as wide as a half note *in total*, without
  /// forcing either quarter wider than it needs to be. Constraints are applied
  /// shortest span first so the short notes set the grid and the long ones only
  /// top it up where it is genuinely too tight.
  _MeasureGrid _gridFor(
    List<_GrandVoice> parts,
    int barIndex,
    double startX,
  ) {
    final onsets = <int>{0};
    var endTick = 0;
    final demands = <({int from, int to, double width})>[];

    for (final part in parts) {
      if (barIndex >= part.measures.length) continue;
      var tick = 0;
      for (final beat in part.measures[barIndex].beats) {
        onsets.add(tick);
        final to = tick + _MeasureGrid.ticksOf(beat);
        demands.add((from: tick, to: to, width: _beatWidth(beat)));
        tick = to;
      }
      if (tick > endTick) endTick = tick;
    }

    final slots = onsets.where((t) => t < endTick).toList()..sort();
    if (slots.isEmpty) slots.add(0);

    int slotAtOrAfter(int tick) {
      for (var i = 0; i < slots.length; i++) {
        if (slots[i] >= tick) return i;
      }
      return slots.length;
    }

    final resolved = <({int from, int to, double width})>[
      for (final demand in demands)
        (
          from: slots.indexOf(demand.from),
          to: math.max(
              slotAtOrAfter(demand.to), slots.indexOf(demand.from) + 1),
          width: demand.width,
        ),
    ]..sort((a, b) => (a.to - a.from).compareTo(b.to - b.from));

    final gaps = List<double>.filled(slots.length, 0.0);
    for (final demand in resolved) {
      if (demand.from < 0) continue;
      var have = 0.0;
      for (var k = demand.from; k < demand.to; k++) {
        have += gaps[k];
      }
      if (have >= demand.width) continue;
      if (have <= 0) {
        final each = demand.width / (demand.to - demand.from);
        for (var k = demand.from; k < demand.to; k++) {
          gaps[k] = each;
        }
      } else {
        final scale = demand.width / have;
        for (var k = demand.from; k < demand.to; k++) {
          gaps[k] *= scale;
        }
      }
    }

    final x = <int, double>{};
    var at = startX;
    for (var i = 0; i < slots.length; i++) {
      x[slots[i]] = at;
      at += gaps[i];
    }
    return _MeasureGrid(x, startX, at);
  }

  /// How much room one beat needs, before anything else is allowed to share it.
  ///
  /// The same rules the single-staff path applies inline: optical spacing by
  /// duration, widened to fit the syllable under it, plus room for an accidental
  /// and a dot.
  double _beatWidth(NotatedBeat beat) {
    var width = EngravingConstants.minNoteSpacing *
        _getOpticalSpacingFactor(beat.duration);
    for (final syllable in beat.allSyllables) {
      if (syllable.isEmpty) continue;
      width = math.max(
        width,
        _measureTextWidth(
              syllable.replaceAll('-', ''),
              EngravingConstants.lyricStyle,
            ) +
            16,
      );
    }
    if (_hasAccidental(beat.pitch)) {
      width += EngravingConstants.accidentalSpace;
    }
    if (beat.dotted) {
      width += EngravingConstants.dotOffset + EngravingConstants.dotRadius * 2;
    }
    return width;
  }

  /// Spans a bracket over each run of consecutive measures sharing a volta
  /// number.
  ///
  /// A run is the bracket: MusicXML marks one by its two ends, but the importer
  /// has already spread the number across every measure the ends enclose, so
  /// grouping equal neighbours recovers the same thing — and it recovers it
  /// per system, which is what has to be drawn.
  ///
  /// [voltaBefore] and [voltaAfter] are the numbers on the measures either side
  /// of this system. When one matches the run at that edge, the run is
  /// continuing rather than beginning or ending, and gets no hook there.
  List<PositionedVolta> _layoutVoltas(
    List<NotatedMeasure> measures,
    List<double> startX,
    List<double> endX, {
    required double staffTop,
    int? voltaBefore,
    int? voltaAfter,
  }) {
    final voltas = <PositionedVolta>[];
    // Clear of the chord row, so a volta and a chord symbol never collide.
    final y = staffTop -
        EngravingConstants.chordAboveStaff -
        (showChords ? EngravingConstants.staffLineSpacing * 1.6 : 0);

    var i = 0;
    while (i < measures.length) {
      final number = measures[i].volta;
      if (number == null) {
        i++;
        continue;
      }

      var last = i;
      while (last + 1 < measures.length && measures[last + 1].volta == number) {
        last++;
      }

      voltas.add(PositionedVolta(
        number: number,
        startX: startX[i] - EngravingConstants.measureSpacing / 2,
        endX: endX[last],
        y: y,
        hasStartHook: !(i == 0 && voltaBefore == number),
        hasEndHook: !(last == measures.length - 1 && voltaAfter == number),
      ));

      i = last + 1;
    }
    return voltas;
  }

  /// Calculate optimal measures per line considering:
  /// - Available width
  /// - Note density
  /// - Lyric lengths
  int _calculateOptimalMeasuresPerLine(List<NotatedMeasure> measures) {
    final contentWidth = availableWidth -
        EngravingConstants.leftMargin -
        EngravingConstants.rightMargin -
        EngravingConstants.clefWidth -
        EngravingConstants.clefToKeySpace -
        EngravingConstants.keyToTimeSpace -
        EngravingConstants.timeToNoteSpace;

    // Calculate width needed for each measure
    final measureWidths = measures.map(_estimateMeasureWidth).toList();
    final avgMeasureWidth = measureWidths.reduce((a, b) => a + b) / measureWidths.length;

    // Calculate based on available width with some flexibility
    int measuresPerLine = (contentWidth / avgMeasureWidth).floor();

    // Ensure reasonable range: 2-4 measures typically looks best
    measuresPerLine = measuresPerLine.clamp(2, 4);

    // If measures are very dense, reduce per line
    final maxBeatsPerMeasure = measures
        .map((m) => m.beats.length)
        .reduce((a, b) => a > b ? a : b);
    if (maxBeatsPerMeasure > 6 && measuresPerLine > 2) {
      measuresPerLine = 2;
    }

    return measuresPerLine;
  }

  /// Estimate measure width using optical spacing
  /// Not mathematically proportional - uses log scale for more natural appearance
  double _estimateMeasureWidth(NotatedMeasure measure) {
    double width = EngravingConstants.measureSpacing;

    for (final beat in measure.beats) {
      // Optical spacing: use logarithmic scale rather than linear
      // This gives shorter notes slightly more space relative to their duration
      final durationFactor = _getOpticalSpacingFactor(beat.duration);
      width += EngravingConstants.minNoteSpacing * durationFactor;

      // Add space for accidentals in pitch
      if (_hasAccidental(beat.pitch)) {
        width += EngravingConstants.accidentalSpace;
      }

      // Add space for dots
      if (beat.dotted) {
        width += EngravingConstants.dotOffset + EngravingConstants.dotRadius * 2;
      }
    }

    return width;
  }

  /// Get optical spacing factor (non-linear)
  /// Based on traditional engraving practice where shorter notes
  /// get proportionally more space than strict mathematical ratio
  double _getOpticalSpacingFactor(NoteDuration duration) {
    switch (duration) {
      case NoteDuration.whole:
        return 3.5; // Not 4x, slightly compressed
      case NoteDuration.half:
        return 2.2; // Not 2x, slightly more
      case NoteDuration.quarter:
        return 1.4; // Base unit, slightly more than 1
      case NoteDuration.eighth:
        return 1.0; // Base for eighth notes
      case NoteDuration.sixteenth:
        return 0.8; // Not 0.5x, more readable
    }
  }

  bool _hasAccidental(String pitch) {
    return pitch.contains('#') || pitch.contains('b');
  }

  StaffSystem _layoutSystem(
    List<NotatedMeasure> measures,
    double y,
    int startMeasureIndex,
    int endMeasureIndex,
    int transposeSemitones,
    bool showClefAndKey,
    bool isLastSystem,
    String key, {
    int? voltaBefore,
    int? voltaAfter,
    required int systemIndex,
  }) {
    final notes = <PositionedNote>[];
    final syllables = <PositionedSyllable>[];
    final chords = <PositionedChord>[];
    final barLines = <PositionedBarLine>[];

    double x = EngravingConstants.leftMargin;
    final staffBottom = y + EngravingConstants.staffHeight;
    int globalBeamGroup = 0;

    // Reserve space for clef, key signature, time signature
    if (showClefAndKey) {
      final keySignatureWidth = EngravingConstants.getKeySignatureWidth(key);
      x += EngravingConstants.clefWidth +
           EngravingConstants.clefToKeySpace +
           keySignatureWidth +
           EngravingConstants.keyToTimeSpace +
           EngravingConstants.timeToNoteSpace;
    }

    // Add initial bar line.
    //
    // A repeat opening on the system's first measure belongs here: there is no
    // earlier line to hang it on, and an engraver puts `||:` at the head of the
    // system rather than inventing a bar.
    final opensRepeat = measures.isNotEmpty && measures.first.repeatStart;
    barLines.add(PositionedBarLine(
      x: x - 5,
      topY: y,
      bottomY: staffBottom,
      repeatStart: opensRepeat,
    ));
    // Push the first note clear of the dots the painter will draw to the right
    // of that line.
    if (opensRepeat) x += EngravingConstants.repeatSignWidth;

    // Where each measure begins and ends horizontally, so a volta bracket can
    // be spanned over a run of them afterwards.
    final measureStartX = <double>[];
    final measureEndX = <double>[];

    // Layout each measure
    for (int i = 0; i < measures.length; i++) {
      final measure = measures[i];
      final isLastMeasure = i == measures.length - 1 && isLastSystem;
      final measureIndex = startMeasureIndex + i;
      measureStartX.add(x);

      // Calculate beam groups for this measure
      // In 4/4 time, beam eighth notes in groups of 4 (half-bar) or 2 (per beat)
      final beamGroups = _calculateBeamGroupsForMeasure(measure.beats);

      // Layout beats in this measure with optical spacing
      for (int j = 0; j < measure.beats.length; j++) {
        final beat = measure.beats[j];
        final transposedPitch = beat.isRest
            ? beat.pitch
            : transposePitch(beat.pitch, transposeSemitones);

        final noteY = beat.isRest
            ? y + EngravingConstants.staffHeight / 2
            : EngravingConstants.getYPositionForPitch(transposedPitch, staffBottom);

        // Determine initial stem direction (may be overridden for beamed groups)
        final stemUp = _calculateStemDirection(noteY, y);

        // Assign beam group (using global counter + local group offset)
        final localBeamGroup = beamGroups[j];
        final beamGroup = localBeamGroup >= 0 ? globalBeamGroup + localBeamGroup : -1;

        final note = PositionedNote(
          x: x,
          y: noteY - EngravingConstants.noteHeadHeight / 2,
          width: EngravingConstants.noteHeadWidth,
          height: EngravingConstants.noteHeadHeight,
          beat: beat,
          transposedPitch: transposedPitch,
          transposedChord: beat.chord != null
              ? transposeChord(beat.chord!, transposeSemitones)
              : null,
          stemUp: stemUp,
          staffLine: _calculateStaffLine(noteY, y),
          measureIndex: measureIndex,
          beatIndex: j,
          beamGroup: beamGroup,
        );

        notes.add(note);

        // Add chord if present
        if (note.transposedChord != null) {
          chords.add(PositionedChord(
            chord: note.transposedChord!,
            x: x,
            y: y - EngravingConstants.chordAboveStaff,
          ));
        }

        // Add syllables if present (centered under note)
        // Support both single syllable and stacked syllables
        final allSyllables = beat.allSyllables;
        for (int lineIdx = 0; lineIdx < allSyllables.length; lineIdx++) {
          final syllableText = allSyllables[lineIdx];
          if (syllableText.isEmpty) continue;

          final continuesWord = syllableText.endsWith('-');
          final displayText = continuesWord
              ? syllableText.substring(0, syllableText.length - 1)
              : syllableText;

          // Calculate text width for centering
          final textWidth = _measureTextWidth(
            displayText,
            EngravingConstants.lyricStyle,
          );

          // Stack lyrics vertically, one row per verse on the note.
          final lyricY = staffBottom +
              EngravingConstants.lyricBelowStaff +
              (lineIdx * EngravingConstants.lyricLineSpacing);

          syllables.add(PositionedSyllable(
            text: displayText,
            x: x + EngravingConstants.noteHeadWidth / 2 - textWidth / 2,
            y: lyricY,
            width: textWidth,
            isWordContinuation: false,
            continuesWord: continuesWord,
            lineIndex: lineIdx,
          ));
        }

        // Apply optical spacing
        final spacingFactor = _getOpticalSpacingFactor(beat.duration);
        double noteSpacing = EngravingConstants.minNoteSpacing * spacingFactor;

        // Adjust spacing based on widest syllable if present
        for (final syllableText in beat.allSyllables) {
          if (syllableText.isNotEmpty) {
            final syllableWidth = _measureTextWidth(
              syllableText.replaceAll('-', ''),
              EngravingConstants.lyricStyle,
            );
            noteSpacing = math.max(noteSpacing, syllableWidth + 16);
          }
        }

        x += noteSpacing;
      }

      // Update global beam group counter for next measure.
      //
      // `fold`, not `reduce`: a measure can have no beats in it at all, and
      // reduce on an empty list throws. That is not a hypothetical shape — a
      // page read by optical music recognition returns bars that are entirely
      // rests, and bars whose staff lines were found but whose contents were
      // not. One such bar used to take down the whole subtree, and in a release
      // build a thrown exception is drawn as Flutter's default ErrorWidget: a
      // plain grey rectangle where the music should be, with nothing said
      // anywhere. -1 is the "no beam group" value the loop above already uses.
      final maxLocalGroup =
          beamGroups.fold<int>(-1, (best, g) => g > best ? g : best);
      if (maxLocalGroup >= 0) {
        globalBeamGroup += maxLocalGroup + 1;
      }

      // Add bar line after measure.
      //
      // A closing repeat needs its dots to the LEFT of the line, so the space
      // goes in before it; an opening repeat for the next measure needs them to
      // the right, so that space goes in after.
      x += EngravingConstants.measureSpacing / 2;
      if (measure.repeatEnd) x += EngravingConstants.repeatSignWidth;
      measureEndX.add(x);
      // One line serves two measures, so it carries the closing repeat of the
      // measure behind it AND the opening repeat of the one ahead — `:||:`, the
      // shape a hymn whose refrain repeats straight into the next verse needs.
      final opensNext = i + 1 < measures.length && measures[i + 1].repeatStart;
      barLines.add(PositionedBarLine(
        x: x,
        topY: y,
        bottomY: staffBottom,
        isFinal: isLastMeasure,
        isDouble: isLastMeasure || measure.repeatEnd || opensNext,
        repeatEnd: measure.repeatEnd,
        repeatStart: opensNext,
      ));
      x += EngravingConstants.measureSpacing / 2;
      if (opensNext) x += EngravingConstants.repeatSignWidth;
    }

    return StaffSystem(
      x: EngravingConstants.leftMargin,
      y: y,
      width: x - EngravingConstants.leftMargin,
      notes: notes,
      syllables: syllables,
      chords: chords,
      barLines: barLines,
      voltas: _layoutVoltas(
        measures,
        measureStartX,
        measureEndX,
        staffTop: y,
        voltaBefore: voltaBefore,
        voltaAfter: voltaAfter,
      ),
      startMeasure: startMeasureIndex,
      endMeasure: endMeasureIndex,
      systemIndex: systemIndex,
    );
  }

  /// Calculate beam groups for notes in a measure
  /// Returns a list of group IDs (-1 for non-beamable notes)
  /// Groups eighth notes in sets of 4 (or less at measure end)
  List<int> _calculateBeamGroupsForMeasure(List<NotatedBeat> beats) {
    final groups = List<int>.filled(beats.length, -1);
    int currentGroup = 0;
    int beamableCount = 0;

    for (int i = 0; i < beats.length; i++) {
      final beat = beats[i];
      final isBeamable = !beat.isRest &&
          (beat.duration == NoteDuration.eighth ||
           beat.duration == NoteDuration.sixteenth);

      if (isBeamable) {
        groups[i] = currentGroup;
        beamableCount++;

        // Start new group after 4 beamable notes (standard grouping in 4/4)
        if (beamableCount >= 4) {
          currentGroup++;
          beamableCount = 0;
        }
      } else {
        // Non-beamable note breaks the beam group
        if (beamableCount > 0) {
          currentGroup++;
          beamableCount = 0;
        }
      }
    }

    return groups;
  }

  /// Calculate stem direction based on note position
  /// Notes on or above the middle line get down stems
  /// Notes below the middle line get up stems
  bool _calculateStemDirection(double noteY, double staffTop) {
    final middleLineY = staffTop + EngravingConstants.staffHeight / 2;
    // Note: larger Y = lower on screen = below middle = stem up
    return noteY > middleLineY;
  }

  int _calculateStaffLine(double noteY, double staffTop) {
    final relativeY = noteY - staffTop;
    return (relativeY / (EngravingConstants.staffLineSpacing / 2)).round();
  }

  /// Measure text width with caching
  double _measureTextWidth(String text, TextStyle style) {
    final cacheKey = '${text}_${style.fontSize}';
    if (_textWidthCache.containsKey(cacheKey)) {
      return _textWidthCache[cacheKey]!;
    }

    // Use TextPainter for accurate measurement
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final width = textPainter.width;
    _textWidthCache[cacheKey] = width;
    return width;
  }
}
