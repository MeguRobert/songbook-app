import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/engraving_constants.dart';
import '../../../data/models/notation.dart';
import 'sheet_music_layout.dart';

/// Custom painter for rendering sheet music notation
/// Implements professional engraving standards based on:
/// - SMuFL (Standard Music Font Layout) specification
/// - Ted Ross "The Art of Music Engraving"
/// - Elaine Gould "Behind Bars"
class SheetMusicPainter extends CustomPainter {
  final SheetMusicLayout layout;
  final Color noteColor;
  final Color staffColor;
  final bool showChords;
  final double textScale;

  // Cached Paint objects for performance
  late final Paint _staffLinePaint;
  late final Paint _stemPaint;
  late final Paint _beamPaint;
  late final Paint _barLinePaint;
  late final Paint _thickBarLinePaint;
  late final Paint _legerLinePaint;
  late final Paint _tiePaint;

  /// Colour for lyric syllables and their hyphens.
  ///
  /// Separate from [noteColor] because these are drawn from
  /// [EngravingConstants.lyricStyle], whose colour is baked in for the light
  /// theme. Left unthemed, the lyrics under the staff — and the chord symbols
  /// and time signature below — stayed near-black on a dark background and
  /// were effectively unreadable, while the notes around them were white.
  final Color lyricColor;

  /// Colour for chord symbols above the staff.
  final Color chordColor;

  /// Intentionally muted relative to [lyricColor] — it is metadata, not music.

  SheetMusicPainter({
    required this.layout,
    this.noteColor = const Color(0xFF333333),
    this.staffColor = const Color(0xFF333333),
    this.lyricColor = const Color(0xFF333333),
    this.chordColor = const Color(0xFF1565C0),
    this.showChords = true,
    this.textScale = 1.0,
  }) {
    _initializePaints();
  }

  void _initializePaints() {
    _staffLinePaint = Paint()
      ..color = staffColor
      ..strokeWidth = EngravingConstants.staffLineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    _stemPaint = Paint()
      ..color = noteColor
      ..strokeWidth = EngravingConstants.stemThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    _beamPaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.fill;

    _barLinePaint = Paint()
      ..color = noteColor
      ..strokeWidth = EngravingConstants.barLineThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    _thickBarLinePaint = Paint()
      ..color = noteColor
      ..strokeWidth = EngravingConstants.thickBarLineThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    _legerLinePaint = Paint()
      ..color = staffColor
      ..strokeWidth = EngravingConstants.legerLineThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    _tiePaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(textScale);

    for (final system in layout.systems) {
      // The first LINE of music, which in a grand staff is several systems — so
      // this asks the system, rather than counting the list as it used to. An
      // index would have put the time signature on the top voice only and
      // silently denied it to the other three.
      final isFirstSystem = system.systemIndex == 0;

      _drawStaffLines(canvas, system);

      // Draw clef and key signature on every system
      _drawStaffLabel(canvas, system);
      _drawClef(canvas, system);
      _drawKeySignature(canvas, system, layout.key);

      // Time signature only on first system
      if (isFirstSystem && layout.showTimeSignature) {
        _drawTimeSignature(canvas, system, layout.timeSignature);
      }

      _drawBarLines(canvas, system);
      _drawVoltas(canvas, system);
      _drawNotesWithBeams(canvas, system);
      _drawTies(canvas, system);
      if (showChords) _drawChords(canvas, system);
      _drawLyrics(canvas, system);
    }

    canvas.restore();
  }

  void _drawStaffLines(Canvas canvas, StaffSystem system) {
    final startX = system.x;
    final endX = system.x + system.width;

    for (int i = 0; i < EngravingConstants.staffLines; i++) {
      final y = system.y + i * EngravingConstants.staffLineSpacing;
      canvas.drawLine(Offset(startX, y), Offset(endX, y), _staffLinePaint);
    }
  }

  void _drawClef(Canvas canvas, StaffSystem system) {
    final x = system.x + 2;
    // Each clef's baseline is its own reference line: the G line for the treble
    // clef (2nd from the bottom), the F line for the bass clef (4th from the
    // bottom). Since a music font draws both from that baseline, the 0.58-of-
    // height offset that puts the G clef's curl on the G line puts the F clef's
    // dots on the F line without any per-glyph adjustment.
    final anchorLineY = system.y +
        EngravingConstants.staffLineSpacing * system.clef.anchorLineFromTop;

    final textPainter = TextPainter(
      text: TextSpan(
        text: system.clef.glyph,
        style: TextStyle(
          fontSize: EngravingConstants.staffLineSpacing * 4, // Scale to staff height
          fontFamily: 'Bravura',
          color: noteColor,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    final clefY = anchorLineY - textPainter.height * 0.58;
    textPainter.paint(canvas, Offset(x, clefY));
  }

  /// The voice's name, to the left of the clef.
  ///
  /// Only a grand staff sets one \u2014 four identical staves with nothing to tell
  /// them apart is the one way this feature could be actively unhelpful. The
  /// layout engine has already reserved the room for it, so this draws
  /// right-aligned back from the staff's left edge and cannot collide with the
  /// clef.
  void _drawStaffLabel(Canvas canvas, StaffSystem system) {
    final label = system.label;
    if (label == null) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: EngravingConstants.staffLabelStyle.copyWith(color: lyricColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        system.x -
            EngravingConstants.staffLabelToClefSpace -
            textPainter.width,
        system.y + EngravingConstants.staffHeight / 2 - textPainter.height / 2,
      ),
    );
  }

  void _drawKeySignature(Canvas canvas, StaffSystem system, String key) {
    final numAccidentals = EngravingConstants.keySignatures[key] ?? 0;
    if (numAccidentals == 0) return;

    final isFlat = numAccidentals < 0;
    final count = numAccidentals.abs();
    final positions = isFlat
        ? EngravingConstants.flatPositions
        : EngravingConstants.sharpPositions;

    double x = system.x + EngravingConstants.clefWidth + EngravingConstants.clefToKeySpace;

    for (int i = 0; i < count && i < positions.length; i++) {
      // Bass-clef accidentals sit one diatonic step lower than their treble
      // counterparts — F# on the fourth line rather than the top one.
      final position = positions[i] + system.clef.keyPositionOffset;
      final y = system.y +
          EngravingConstants.staffHeight / 2 -
          position * (EngravingConstants.staffLineSpacing / 2);

      if (isFlat) {
        _drawFlat(canvas, x, y);
        x += EngravingConstants.flatWidth;
      } else {
        _drawSharp(canvas, x, y);
        x += EngravingConstants.sharpWidth;
      }
    }
  }

  void _drawFlat(Canvas canvas, double x, double y) {
    // SMuFL flat: U+E260
    const flatSymbol = '\uE260';
    final textPainter = TextPainter(
      text: TextSpan(
        text: flatSymbol,
        style: TextStyle(
          fontSize: EngravingConstants.staffLineSpacing * 2.5,
          fontFamily: 'Bravura',
          color: noteColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(x - textPainter.width / 2, y - textPainter.height * 0.5));
  }

  void _drawSharp(Canvas canvas, double x, double y) {
    // SMuFL sharp: U+E262
    const sharpSymbol = '\uE262';
    final textPainter = TextPainter(
      text: TextSpan(
        text: sharpSymbol,
        style: TextStyle(
          fontSize: EngravingConstants.staffLineSpacing * 2.5,
          fontFamily: 'Bravura',
          color: noteColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(x - textPainter.width / 2, y - textPainter.height * 0.5));
  }

  void _drawTimeSignature(Canvas canvas, StaffSystem system, String timeSig) {
    final parts = timeSig.split('/');
    if (parts.length != 2) return;

    final keySignatureWidth = EngravingConstants.getKeySignatureWidth(layout.key);
    final x = system.x + EngravingConstants.clefWidth +
        EngravingConstants.clefToKeySpace +
        keySignatureWidth +
        EngravingConstants.keyToTimeSpace;

    _drawTimeSigNumber(canvas, parts[0], x, system.y + 8);
    _drawTimeSigNumber(
      canvas,
      parts[1],
      x,
      system.y + EngravingConstants.staffLineSpacing * 2 + 8,
    );
  }

  void _drawTimeSigNumber(Canvas canvas, String number, double x, double y) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: number,
        style: EngravingConstants.timeSigStyle.copyWith(color: noteColor),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y));
  }

  void _drawBarLines(Canvas canvas, StaffSystem system) {
    for (final barLine in system.barLines) {
      if (barLine.repeatStart || barLine.repeatEnd) {
        _drawRepeatBarLine(canvas, barLine);
      } else if (barLine.isFinal) {
        // Final bar: thin line, thick line
        canvas.drawLine(
          Offset(barLine.x - EngravingConstants.barLineSeparation -
              EngravingConstants.thickBarLineThickness / 2, barLine.topY),
          Offset(barLine.x - EngravingConstants.barLineSeparation -
              EngravingConstants.thickBarLineThickness / 2, barLine.bottomY),
          _barLinePaint,
        );
        canvas.drawLine(
          Offset(barLine.x, barLine.topY),
          Offset(barLine.x, barLine.bottomY),
          _thickBarLinePaint,
        );
      } else {
        canvas.drawLine(
          Offset(barLine.x, barLine.topY),
          Offset(barLine.x, barLine.bottomY),
          _barLinePaint,
        );
      }
    }
  }

  /// A repeat sign: a thick line, with a thin line and two dots on whichever
  /// side or sides the repeat faces.
  ///
  /// Both flags can be set on one line — the `:‖:` of a hymn whose refrain
  /// repeats straight into the next verse — so the two halves are drawn
  /// independently rather than as three mutually exclusive cases. The layout
  /// engine has already reserved [EngravingConstants.repeatSignWidth] on the
  /// relevant side, so nothing here lands on a note head.
  void _drawRepeatBarLine(Canvas canvas, PositionedBarLine barLine) {
    final dotPaint = Paint()
      ..color = noteColor
      ..style = PaintingStyle.fill;

    // The thick line sits ON the bar line's own x; everything else hangs off it.
    canvas.drawLine(
      Offset(barLine.x, barLine.topY),
      Offset(barLine.x, barLine.bottomY),
      _thickBarLinePaint,
    );

    final offset = EngravingConstants.barLineSeparation +
        EngravingConstants.thickBarLineThickness / 2;
    const dotRadius = 2.5;

    void half(int direction) {
      final thinX = barLine.x + direction * (offset + 8);
      canvas.drawLine(
        Offset(thinX, barLine.topY),
        Offset(thinX, barLine.bottomY),
        _barLinePaint,
      );
      final dotX = barLine.x + direction * (offset + 16);
      // A pair per staff this line serves. In a grand staff the line's own topY
      // is the top of the GROUP, so anchoring the dots to it would put all four
      // pairs inside the soprano staff.
      for (final staffTop in barLine.dotAnchors) {
        // The two dots straddle the middle staff line, in the spaces either side
        // of it — where every engraver puts them.
        canvas.drawCircle(
          Offset(dotX, staffTop + EngravingConstants.staffLineSpacing * 1.5),
          dotRadius,
          dotPaint,
        );
        canvas.drawCircle(
          Offset(dotX, staffTop + EngravingConstants.staffLineSpacing * 2.5),
          dotRadius,
          dotPaint,
        );
      }
    }

    // A closing repeat faces backwards, an opening one forwards.
    if (barLine.repeatEnd) half(-1);
    if (barLine.repeatStart) half(1);
  }

  /// Volta ("second-time bar") brackets: a horizontal stroke above the staff
  /// with its number at the left, hooked down at whichever ends are real ends of
  /// the run.
  void _drawVoltas(Canvas canvas, StaffSystem system) {
    if (system.voltas.isEmpty) return;

    final bracketPaint = Paint()
      ..color = noteColor
      ..strokeWidth = EngravingConstants.barLineThickness
      ..style = PaintingStyle.stroke;

    // Hook length: deep enough to read as a bracket, short of the staff so it
    // never crosses the top line.
    final hookDepth = EngravingConstants.staffLineSpacing * 1.2;

    for (final volta in system.voltas) {
      canvas.drawLine(
        Offset(volta.startX, volta.y),
        Offset(volta.endX, volta.y),
        bracketPaint,
      );
      if (volta.hasStartHook) {
        canvas.drawLine(
          Offset(volta.startX, volta.y),
          Offset(volta.startX, volta.y + hookDepth),
          bracketPaint,
        );
      }
      if (volta.hasEndHook) {
        canvas.drawLine(
          Offset(volta.endX, volta.y),
          Offset(volta.endX, volta.y + hookDepth),
          bracketPaint,
        );
      }

      // The number goes inside the bracket at its left end — but only on the
      // half that starts the run, or a bracket split by a line break would be
      // numbered twice.
      if (!volta.hasStartHook) continue;
      final label = TextPainter(
        text: TextSpan(
          text: '${volta.number}.',
          style: EngravingConstants.chordStyle.copyWith(color: noteColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(volta.startX + 4, volta.y + 1));
    }
  }

  /// Draw notes with proper beaming algorithm
  void _drawNotesWithBeams(Canvas canvas, StaffSystem system) {
    // Group notes for beaming
    final beamGroups = _groupNotesForBeaming(system.notes);

    for (final group in beamGroups) {
      if (group.length == 1) {
        final note = group.first;
        if (note.beat.isRest) {
          _drawRest(canvas, note);
        } else {
          _drawNoteHead(canvas, note);
          _drawStem(canvas, note);
          _drawLedgerLines(canvas, note, system);
          // Single beamable note gets a flag
          if (_isBeamable(note)) {
            _drawFlag(canvas, note);
          }
        }
      } else {
        // Draw beamed group
        _drawBeamedGroup(canvas, group, system);
      }
    }
  }

  bool _isBeamable(PositionedNote note) {
    return !note.beat.isRest &&
        (note.beat.duration == NoteDuration.eighth ||
            note.beat.duration == NoteDuration.sixteenth);
  }

  /// Group notes for beaming using pre-calculated beam groups from layout
  List<List<PositionedNote>> _groupNotesForBeaming(List<PositionedNote> notes) {
    final groups = <List<PositionedNote>>[];
    final beamGroupMap = <int, List<PositionedNote>>{};

    // Group notes by their beamGroup ID
    for (final note in notes) {
      if (note.beamGroup >= 0 && _isBeamable(note)) {
        beamGroupMap.putIfAbsent(note.beamGroup, () => []).add(note);
      }
    }

    // Process notes in order, creating groups
    int currentBeamGroup = -1;
    List<PositionedNote> currentGroup = [];

    for (final note in notes) {
      if (note.beamGroup >= 0 && _isBeamable(note)) {
        // This note belongs to a beam group
        if (note.beamGroup != currentBeamGroup) {
          // Finish previous group if any
          if (currentGroup.isNotEmpty) {
            groups.add(List.from(currentGroup));
            currentGroup = [];
          }
          currentBeamGroup = note.beamGroup;
        }
        currentGroup.add(note);
      } else {
        // Non-beamable note or no beam group
        if (currentGroup.isNotEmpty) {
          groups.add(List.from(currentGroup));
          currentGroup = [];
          currentBeamGroup = -1;
        }
        groups.add([note]);
      }
    }

    // Don't forget the last group
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  void _drawBeamedGroup(
      Canvas canvas, List<PositionedNote> group, StaffSystem system) {
    if (group.isEmpty) return;

    // Calculate optimal stem direction for the group
    final stemUp = _calculateGroupStemDirection(group, system);

    // Calculate beam slant following Ross rules
    final beamSlant = _calculateBeamSlant(group, stemUp);

    // Draw note heads and ledger lines first
    for (final note in group) {
      _drawNoteHead(canvas, note);
      _drawLedgerLines(canvas, note, system);
    }

    // Calculate stem endpoints
    final stemEnds = _calculateStemEndsForBeam(group, stemUp, beamSlant);

    // Draw stems
    for (int i = 0; i < group.length; i++) {
      final note = group[i];
      final noteHeadCenterY = note.y + EngravingConstants.noteHeadHeight / 2;
      final stemX = stemUp
          ? note.x + EngravingConstants.noteHeadWidth - 1
          : note.x + 1;

      canvas.drawLine(
        Offset(stemX, noteHeadCenterY),
        stemEnds[i],
        _stemPaint,
      );
    }

    // Draw primary beam
    _drawBeam(canvas, stemEnds.first, stemEnds.last, stemUp);

    // Draw secondary beam for sixteenth notes
    if (group.any((n) => n.beat.duration == NoteDuration.sixteenth)) {
      final offset = stemUp
          ? EngravingConstants.beamThickness + EngravingConstants.beamSpacing
          : -(EngravingConstants.beamThickness + EngravingConstants.beamSpacing);

      _drawBeam(
        canvas,
        Offset(stemEnds.first.dx, stemEnds.first.dy + offset),
        Offset(stemEnds.last.dx, stemEnds.last.dy + offset),
        stemUp,
      );
    }
  }

  /// Calculate stem direction for a beamed group
  /// Uses the "furthest from middle" rule per standard engraving practice
  bool _calculateGroupStemDirection(
      List<PositionedNote> group, StaffSystem system) {
    final middleY = system.y + EngravingConstants.staffHeight / 2;

    double maxDistanceAbove = 0;
    double maxDistanceBelow = 0;

    for (final note in group) {
      final noteY = note.y + EngravingConstants.noteHeadHeight / 2;
      final distance = noteY - middleY;

      if (distance > 0) {
        // Note is below middle line
        maxDistanceBelow = math.max(maxDistanceBelow, distance);
      } else {
        // Note is above middle line
        maxDistanceAbove = math.max(maxDistanceAbove, -distance);
      }
    }

    // If furthest note is below middle, stems go up
    // If furthest note is above middle, stems go down
    // If tied, default to stems down
    return maxDistanceBelow >= maxDistanceAbove;
  }

  /// Calculate beam slant following Ross beam rules
  double _calculateBeamSlant(List<PositionedNote> group, bool stemUp) {
    if (group.length < 2) return 0;

    final firstNote = group.first;
    final lastNote = group.last;

    // Calculate interval in staff positions
    final firstY = firstNote.y + EngravingConstants.noteHeadHeight / 2;
    final lastY = lastNote.y + EngravingConstants.noteHeadHeight / 2;
    final interval =
        ((lastY - firstY) / (EngravingConstants.staffLineSpacing / 2)).abs();

    // Calculate slant based on interval
    double slant;
    if (interval <= 1) {
      // Seconds: minimal slant
      slant = EngravingConstants.minBeamSlant;
    } else if (interval >= 7) {
      // Seventh or more: maximum slant
      slant = EngravingConstants.maxBeamSlant;
    } else {
      // Proportional slant for other intervals
      slant = EngravingConstants.minBeamSlant +
          (interval - 1) * EngravingConstants.beamSlantPerPosition;
      slant = slant.clamp(
          EngravingConstants.minBeamSlant, EngravingConstants.maxBeamSlant);
    }

    // Direction of slant based on melodic direction
    if (lastY > firstY) {
      // Descending melody: beam slants down
      return stemUp ? slant : -slant;
    } else if (lastY < firstY) {
      // Ascending melody: beam slants up
      return stemUp ? -slant : slant;
    }

    return 0; // Same pitch, flat beam
  }

  List<Offset> _calculateStemEndsForBeam(
      List<PositionedNote> group, bool stemUp, double totalSlant) {
    if (group.isEmpty) return [];

    final stemEnds = <Offset>[];
    final firstNote = group.first;
    final lastNote = group.last;

    // Calculate base stem end position
    final firstNoteY = firstNote.y + EngravingConstants.noteHeadHeight / 2;
    final baseStemEndY = stemUp
        ? firstNoteY - EngravingConstants.stemLength
        : firstNoteY + EngravingConstants.stemLength;

    // Calculate horizontal span
    final firstX = stemUp
        ? firstNote.x + EngravingConstants.noteHeadWidth - 1
        : firstNote.x + 1;
    final lastX = stemUp
        ? lastNote.x + EngravingConstants.noteHeadWidth - 1
        : lastNote.x + 1;
    final horizontalSpan = lastX - firstX;

    for (final note in group) {
      final stemX = stemUp
          ? note.x + EngravingConstants.noteHeadWidth - 1
          : note.x + 1;

      // Interpolate Y position along the beam
      final progress = horizontalSpan > 0 ? (stemX - firstX) / horizontalSpan : 0.0;
      final stemEndY = baseStemEndY + totalSlant * progress;

      stemEnds.add(Offset(stemX, stemEndY));
    }

    return stemEnds;
  }

  void _drawBeam(Canvas canvas, Offset start, Offset end, bool stemUp) {
    final thickness = EngravingConstants.beamThickness;
    final offset = stemUp ? thickness : -thickness;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy)
      ..lineTo(end.dx, end.dy + offset)
      ..lineTo(start.dx, start.dy + offset)
      ..close();

    canvas.drawPath(path, _beamPaint);
  }

  void _drawNoteHead(Canvas canvas, PositionedNote note) {
    // Draw accidental if present
    _drawNoteAccidental(canvas, note);

    final isHollow = note.beat.duration == NoteDuration.whole ||
        note.beat.duration == NoteDuration.half;

    final paint = Paint()
      ..color = noteColor
      ..style = isHollow ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = isHollow ? 2 : 0;

    final centerX = note.x + EngravingConstants.noteHeadWidth / 2;
    final centerY = note.y + EngravingConstants.noteHeadHeight / 2;

    canvas.save();
    canvas.translate(centerX, centerY);
    canvas.rotate(EngravingConstants.noteHeadRotation);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: EngravingConstants.noteHeadWidth,
      height: EngravingConstants.noteHeadHeight,
    );

    canvas.drawOval(rect, paint);
    canvas.restore();

    // Draw dot if dotted
    if (note.beat.dotted) {
      final dotPaint = Paint()
        ..color = noteColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(
          note.x + EngravingConstants.noteHeadWidth + EngravingConstants.dotOffset,
          note.y + EngravingConstants.noteHeadHeight / 2,
        ),
        EngravingConstants.dotRadius,
        dotPaint,
      );
    }
  }

  void _drawNoteAccidental(Canvas canvas, PositionedNote note) {
    final pitch = note.beat.pitch;
    if (pitch == 'R') return; // Rest has no accidental

    // Determine what accidental to show based on key signature
    final accidentalType = _getAccidentalToShow(pitch, layout.key);
    if (accidentalType == null) return;

    final accidentalY = note.y + EngravingConstants.noteHeadHeight / 2;
    final accidentalWidth = accidentalType == 'sharp'
        ? EngravingConstants.sharpWidth
        : EngravingConstants.flatWidth;
    final accidentalX = note.x - EngravingConstants.accidentalSpace - accidentalWidth;

    switch (accidentalType) {
      case 'sharp':
        _drawSharp(canvas, accidentalX, accidentalY);
        break;
      case 'flat':
        _drawFlat(canvas, accidentalX, accidentalY);
        break;
      case 'natural':
        _drawNatural(canvas, accidentalX, accidentalY);
        break;
    }
  }

  /// Determine if an accidental should be shown for this note in the given key
  /// Returns 'sharp', 'flat', 'natural', or null if no accidental needed
  String? _getAccidentalToShow(String pitch, String key) {
    if (pitch.length < 2) return null;

    final noteLetter = pitch[0].toUpperCase();
    final hasSharpInPitch = pitch.contains('#');
    final hasFlatInPitch = pitch.length >= 2 && pitch[1] == 'b';

    // Get sharps/flats in the key signature
    final keyAccidentals = EngravingConstants.keySignatures[key] ?? 0;

    // Notes that are sharp in sharp keys (order: F C G D A E B)
    const sharpOrder = ['F', 'C', 'G', 'D', 'A', 'E', 'B'];
    // Notes that are flat in flat keys (order: B E A D G C F)
    const flatOrder = ['B', 'E', 'A', 'D', 'G', 'C', 'F'];

    bool noteIsFlatInKey = false;
    bool noteIsSharpInKey = false;

    if (keyAccidentals < 0) {
      // Flat key - check if this note is flat in the key
      final numFlats = keyAccidentals.abs();
      noteIsFlatInKey = flatOrder.take(numFlats).contains(noteLetter);
    } else if (keyAccidentals > 0) {
      // Sharp key - check if this note is sharp in the key
      noteIsSharpInKey = sharpOrder.take(keyAccidentals).contains(noteLetter);
    }

    // Determine what to show
    if (hasSharpInPitch) {
      // Note has sharp - show it unless already sharp in key
      if (!noteIsSharpInKey) return 'sharp';
    } else if (hasFlatInPitch) {
      // Note has flat - show it unless already flat in key
      if (!noteIsFlatInKey) return 'flat';
    } else {
      // Natural note - show natural sign if key says it should be sharp/flat
      if (noteIsFlatInKey || noteIsSharpInKey) return 'natural';
    }

    return null;
  }

  void _drawNatural(Canvas canvas, double x, double y) {
    // SMuFL natural: U+E261
    const naturalSymbol = '\uE261';
    final textPainter = TextPainter(
      text: TextSpan(
        text: naturalSymbol,
        style: TextStyle(
          fontFamily: 'Bravura',
          fontSize: EngravingConstants.staffLineSpacing * 2.5,
          color: noteColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x, y - textPainter.height / 2));
  }

  void _drawStem(Canvas canvas, PositionedNote note) {
    if (note.beat.duration == NoteDuration.whole) return;

    final noteHeadCenterY = note.y + EngravingConstants.noteHeadHeight / 2;

    double stemX;
    double stemEndY;

    if (note.stemUp) {
      stemX = note.x + EngravingConstants.noteHeadWidth - 1;
      stemEndY = noteHeadCenterY - EngravingConstants.stemLength;
    } else {
      stemX = note.x + 1;
      stemEndY = noteHeadCenterY + EngravingConstants.stemLength;
    }

    canvas.drawLine(
      Offset(stemX, noteHeadCenterY),
      Offset(stemX, stemEndY),
      _stemPaint,
    );
  }

  void _drawFlag(Canvas canvas, PositionedNote note) {
    if (note.beat.duration != NoteDuration.eighth &&
        note.beat.duration != NoteDuration.sixteenth) {
      return;
    }

    final noteHeadCenterY = note.y + EngravingConstants.noteHeadHeight / 2;
    final stemX = note.stemUp
        ? note.x + EngravingConstants.noteHeadWidth - 1
        : note.x + 1;
    final stemEndY = note.stemUp
        ? noteHeadCenterY - EngravingConstants.stemLength
        : noteHeadCenterY + EngravingConstants.stemLength;

    final paint = Paint()
      ..color = noteColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final flagLength = 15.0;
    final direction = note.stemUp ? 1 : -1;

    // First flag
    final path = Path();
    path.moveTo(stemX, stemEndY);
    path.quadraticBezierTo(
      stemX + 10,
      stemEndY + direction * 8,
      stemX + flagLength,
      stemEndY + direction * 15,
    );
    canvas.drawPath(path, paint);

    // Second flag for sixteenth
    if (note.beat.duration == NoteDuration.sixteenth) {
      final path2 = Path();
      path2.moveTo(stemX, stemEndY + direction * 8);
      path2.quadraticBezierTo(
        stemX + 10,
        stemEndY + direction * 16,
        stemX + flagLength,
        stemEndY + direction * 23,
      );
      canvas.drawPath(path2, paint);
    }
  }

  void _drawLedgerLines(Canvas canvas, PositionedNote note, StaffSystem system) {
    final noteCenterY = note.y + EngravingConstants.noteHeadHeight / 2;
    final staffTop = system.y;
    final staffBottom = system.staffBottom;
    final spacing = EngravingConstants.staffLineSpacing;
    final extension = EngravingConstants.legerLineExtension;

    // Ledger lines above staff
    double y = staffTop - spacing;
    while (y >= noteCenterY - spacing / 2) {
      canvas.drawLine(
        Offset(note.x - extension, y),
        Offset(note.x + EngravingConstants.noteHeadWidth + extension, y),
        _legerLinePaint,
      );
      y -= spacing;
    }

    // Ledger lines below staff
    y = staffBottom + spacing;
    while (y <= noteCenterY + spacing / 2) {
      canvas.drawLine(
        Offset(note.x - extension, y),
        Offset(note.x + EngravingConstants.noteHeadWidth + extension, y),
        _legerLinePaint,
      );
      y += spacing;
    }
  }

  void _drawRest(Canvas canvas, PositionedNote note) {
    final paint = Paint()
      ..color = noteColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final x = note.x + EngravingConstants.noteHeadWidth / 2;
    final y = note.y;

    switch (note.beat.duration) {
      case NoteDuration.whole:
        final rect = Rect.fromLTWH(x - 6, y - 5, 12, 6);
        canvas.drawRect(rect, paint..style = PaintingStyle.fill);
        break;

      case NoteDuration.half:
        final rect = Rect.fromLTWH(x - 6, y, 12, 6);
        canvas.drawRect(rect, paint..style = PaintingStyle.fill);
        break;

      case NoteDuration.quarter:
        final path = Path();
        path.moveTo(x, y - 10);
        path.lineTo(x + 5, y - 5);
        path.lineTo(x - 3, y + 2);
        path.lineTo(x + 5, y + 10);
        canvas.drawPath(path, paint);
        break;

      case NoteDuration.eighth:
        canvas.drawCircle(Offset(x, y), 3, paint..style = PaintingStyle.fill);
        canvas.drawLine(Offset(x, y), Offset(x - 5, y + 10), paint);
        break;

      case NoteDuration.sixteenth:
        canvas.drawCircle(
            Offset(x, y - 3), 2.5, paint..style = PaintingStyle.fill);
        canvas.drawCircle(
            Offset(x, y + 5), 2.5, paint..style = PaintingStyle.fill);
        canvas.drawLine(Offset(x, y - 3), Offset(x - 4, y + 2), paint);
        canvas.drawLine(Offset(x, y + 5), Offset(x - 4, y + 10), paint);
        break;
    }
  }

  void _drawTies(Canvas canvas, StaffSystem system) {
    for (int i = 0; i < system.notes.length - 1; i++) {
      final note = system.notes[i];
      if (note.beat.tieStart) {
        final nextNote = system.notes[i + 1];
        _drawTie(canvas, note, nextNote);
      }
    }
  }

  void _drawTie(Canvas canvas, PositionedNote startNote, PositionedNote endNote) {
    final startX = startNote.x + EngravingConstants.noteHeadWidth;
    final endX = endNote.x;
    final midX = (startX + endX) / 2;

    final noteY = startNote.y + EngravingConstants.noteHeadHeight / 2;
    final tieAbove = !startNote.stemUp;
    final tieOffset = EngravingConstants.tieOffset;
    final tieHeight = EngravingConstants.minTieHeight;

    final startY = tieAbove ? noteY - tieOffset : noteY + tieOffset;
    final endY = startY;
    final controlY = tieAbove ? startY - tieHeight : startY + tieHeight;

    // Draw tie as a curved shape
    final path = Path()
      ..moveTo(startX, startY)
      ..quadraticBezierTo(midX, controlY, endX, endY);

    // Create the thickness by drawing a slightly offset curve
    final innerControlY = tieAbove
        ? controlY + EngravingConstants.tieMidpointThickness
        : controlY - EngravingConstants.tieMidpointThickness;

    final innerPath = Path()
      ..moveTo(endX, endY)
      ..quadraticBezierTo(midX, innerControlY, startX, startY);

    final combinedPath = Path()
      ..addPath(path, Offset.zero)
      ..addPath(innerPath, Offset.zero)
      ..close();

    canvas.drawPath(combinedPath, _tiePaint);
  }

  void _drawChords(Canvas canvas, StaffSystem system) {
    for (final chord in system.chords) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: chord.chord,
          style: EngravingConstants.chordStyle.copyWith(color: chordColor),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(chord.x, chord.y));
    }
  }

  void _drawLyrics(Canvas canvas, StaffSystem system) {
    for (int i = 0; i < system.syllables.length; i++) {
      final syllable = system.syllables[i];

      final textPainter = TextPainter(
        text: TextSpan(
          text: syllable.text,
          style: EngravingConstants.lyricStyle.copyWith(color: lyricColor),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(syllable.x, syllable.y));

      // Draw hyphen between syllables if word continues
      // Only draw hyphen to next syllable on same line index
      if (syllable.continuesWord) {
        // Find next syllable with same line index
        PositionedSyllable? nextSyllable;
        for (int j = i + 1; j < system.syllables.length; j++) {
          if (system.syllables[j].lineIndex == syllable.lineIndex) {
            nextSyllable = system.syllables[j];
            break;
          }
        }

        if (nextSyllable != null) {
          final hyphenX = syllable.x +
              syllable.width +
              (nextSyllable.x - syllable.x - syllable.width) / 2 -
              3;

          final hyphenPainter = TextPainter(
            text: TextSpan(
              text: '-',
              style: EngravingConstants.lyricStyle.copyWith(color: lyricColor),
            ),
            textDirection: TextDirection.ltr,
          );
          hyphenPainter.layout();
          hyphenPainter.paint(canvas, Offset(hyphenX, syllable.y));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant SheetMusicPainter oldDelegate) {
    return oldDelegate.layout != layout ||
        oldDelegate.noteColor != noteColor ||
        oldDelegate.staffColor != staffColor ||
        // Every colour must be compared, or toggling the theme leaves the
        // canvas showing the previous palette until something else repaints.
        oldDelegate.lyricColor != lyricColor ||
        oldDelegate.chordColor != chordColor ||
        oldDelegate.showChords != showChords ||
        oldDelegate.textScale != textScale;
  }
}
