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

  const PositionedBarLine({
    required this.x,
    required this.topY,
    required this.bottomY,
    this.isDouble = false,
    this.isFinal = false,
    this.repeatStart = false,
    this.repeatEnd = false,
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
  final int startMeasure;
  final int endMeasure;

  const StaffSystem({
    required this.x,
    required this.y,
    required this.width,
    required this.notes,
    required this.syllables,
    required this.chords,
    required this.barLines,
    required this.startMeasure,
    required this.endMeasure,
  });

  double get staffTop => y;
  double get staffBottom => y + EngravingConstants.staffHeight;
  double get lyricY => staffBottom + EngravingConstants.lyricBelowStaff;
  double get chordY => staffTop - EngravingConstants.chordAboveStaff;
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

/// Engine that calculates layout for sheet music notation
/// Implements optical spacing based on professional engraving standards
class SheetMusicLayoutEngine {
  final double availableWidth;
  final String Function(String pitch, int semitones) transposePitch;
  final String Function(String chord, int semitones) transposeChord;

  // Cached text painters for accurate width measurement
  final Map<String, double> _textWidthCache = {};

  SheetMusicLayoutEngine({
    required this.availableWidth,
    required this.transposePitch,
    required this.transposeChord,
  });

  /// Calculate the complete layout for a song's notation
  SheetMusicLayout calculateLayout(
    SongNotation notation,
    int transposeSemitones,
  ) {
    final systems = <StaffSystem>[];
    final targetKey = transposeChord(notation.originalKey, transposeSemitones);

    double currentY = EngravingConstants.chordAboveStaff + 20;

    for (final verse in notation.verses) {
      final verseSystems = _layoutVerse(
        verse,
        currentY,
        transposeSemitones,
        notation.timeSignature,
        targetKey,
      );
      systems.addAll(verseSystems);

      if (verseSystems.isNotEmpty) {
        currentY = verseSystems.last.staffBottom +
            EngravingConstants.lyricBelowStaff +
            30 +
            EngravingConstants.systemSpacing;
      }
    }

    final totalHeight = systems.isEmpty
        ? 200.0
        : systems.last.staffBottom +
            EngravingConstants.lyricBelowStaff +
            50;

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
      final adjustedBarLines = s.barLines.isNotEmpty
          ? [
              ...s.barLines.take(s.barLines.length - 1),
              PositionedBarLine(
                x: rightEdge,
                topY: s.barLines.last.topY,
                bottomY: s.barLines.last.bottomY,
                isDouble: s.barLines.last.isDouble,
                isFinal: s.barLines.last.isFinal,
                repeatStart: s.barLines.last.repeatStart,
                repeatEnd: s.barLines.last.repeatEnd,
              ),
            ]
          : s.barLines;

      return StaffSystem(
        x: s.x,
        y: s.y,
        width: maxSystemWidth,
        notes: s.notes,
        syllables: s.syllables,
        chords: s.chords,
        barLines: adjustedBarLines,
        startMeasure: s.startMeasure,
        endMeasure: s.endMeasure,
      );
    }).toList();

    // Add some padding on the right
    final contentWidth = EngravingConstants.leftMargin + maxSystemWidth + EngravingConstants.rightMargin;

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
    String key,
  ) {
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
      );

      systems.add(system);

      measureIndex = endIndex;
      currentY = system.staffBottom +
          EngravingConstants.lyricBelowStaff +
          30 +
          EngravingConstants.systemSpacing;
    }

    return systems;
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
    String key,
  ) {
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

    // Add initial bar line
    barLines.add(PositionedBarLine(
      x: x - 5,
      topY: y,
      bottomY: staffBottom,
    ));

    // Layout each measure
    for (int i = 0; i < measures.length; i++) {
      final measure = measures[i];
      final isLastMeasure = i == measures.length - 1 && isLastSystem;
      final measureIndex = startMeasureIndex + i;

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

          // Stack lyrics vertically (18px apart for each line)
          final lyricLineSpacing = 18.0;
          final lyricY = staffBottom + EngravingConstants.lyricBelowStaff +
                        (lineIdx * lyricLineSpacing);

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

      // Update global beam group counter for next measure
      final maxLocalGroup = beamGroups.reduce((a, b) => a > b ? a : b);
      if (maxLocalGroup >= 0) {
        globalBeamGroup += maxLocalGroup + 1;
      }

      // Add bar line after measure
      x += EngravingConstants.measureSpacing / 2;
      barLines.add(PositionedBarLine(
        x: x,
        topY: y,
        bottomY: staffBottom,
        isFinal: isLastMeasure,
        isDouble: isLastMeasure || measure.repeatEnd,
        repeatEnd: measure.repeatEnd,
      ));
      x += EngravingConstants.measureSpacing / 2;
    }

    return StaffSystem(
      x: EngravingConstants.leftMargin,
      y: y,
      width: x - EngravingConstants.leftMargin,
      notes: notes,
      syllables: syllables,
      chords: chords,
      barLines: barLines,
      startMeasure: startMeasureIndex,
      endMeasure: endMeasureIndex,
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
