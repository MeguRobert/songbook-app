import 'package:flutter/material.dart';
import '../../../data/models/notation.dart';
import '../../../data/models/song.dart';
import '../../../domain/services/transposition_service.dart';
import 'notation_palette.dart';
import 'sheet_music_layout.dart';
import 'sheet_music_painter.dart';

/// A widget that renders sheet music notation with support for
/// transposition, zoom, and pan.
class SheetMusicRenderer extends StatefulWidget {
  /// The song being displayed
  final Song song;

  /// Notation data for the song
  final SongNotation notation;

  /// Number of semitones to transpose
  final int transpose;

  /// Whether to show chord symbols above the staff
  final bool showChords;

  /// Called when notation is not available
  final Widget? fallback;

  /// Scale factor applied to the rendered notation (A+/A-, pinch, etc.)
  final double textScale;

  const SheetMusicRenderer({
    super.key,
    required this.song,
    required this.notation,
    this.transpose = 0,
    this.showChords = true,
    this.fallback,
    this.textScale = 1.0,
  });

  @override
  State<SheetMusicRenderer> createState() => _SheetMusicRendererState();
}

class _SheetMusicRendererState extends State<SheetMusicRenderer> {
  final TranspositionService _transpositionService = const TranspositionService();
  final ScrollController _vScrollController = ScrollController();
  final ScrollController _hScrollController = ScrollController();

  // Cached layout. The engraving layout (note positions, line wrapping) is
  // INDEPENDENT of textScale — zoom is applied purely as a visual scale
  // (canvas.scale + a scaled SizedBox), so the layout is recomputed only when
  // the width, notation, transpose or chord visibility change, never on zoom.
  // This is what makes zooming smooth: no relayout/re-wrap per zoom step.
  SheetMusicLayout? _layout;
  double? _layoutWidth;
  SongNotation? _layoutNotation;
  int? _layoutTranspose;
  bool? _layoutShowChords;

  @override
  void dispose() {
    _vScrollController.dispose();
    _hScrollController.dispose();
    super.dispose();
  }

  SheetMusicLayout _layoutFor(double width) {
    if (_layout == null ||
        _layoutWidth != width ||
        _layoutNotation != widget.notation ||
        _layoutTranspose != widget.transpose ||
        _layoutShowChords != widget.showChords) {
      final engine = SheetMusicLayoutEngine(
        availableWidth: width,
        transposePitch: _transposePitch,
        transposeChord: _transposeChord,
        showChords: widget.showChords,
      );
      _layout = engine.calculateLayout(widget.notation, widget.transpose);
      _layoutWidth = width;
      _layoutNotation = widget.notation;
      _layoutTranspose = widget.transpose;
      _layoutShowChords = widget.showChords;
    }
    return _layout!;
  }

  String _transposePitch(String pitch, int semitones) {
    if (semitones == 0) return pitch;

    // Parse pitch (e.g., "Bb4" -> note="Bb", octave=4)
    final match = RegExp(r'^([A-Ga-g][#b]?)(\d)$').firstMatch(pitch);
    if (match == null) return pitch;

    final note = match.group(1)!;
    final octave = int.parse(match.group(2)!);

    // Transpose just the note part
    final transposedNote = _transpositionService.transposeChord(
      note,
      semitones,
      targetKey: _transpositionService.calculateTargetKey(
        widget.notation.originalKey,
        semitones,
      ),
    );

    // Calculate new octave based on semitone movement
    final originalIndex = _getNoteIndex(note);
    final newIndex = _getNoteIndex(transposedNote);

    int newOctave = octave;
    if (semitones > 0 && newIndex < originalIndex) {
      newOctave++; // Wrapped around to next octave
    } else if (semitones < 0 && newIndex > originalIndex) {
      newOctave--; // Wrapped around to previous octave
    }

    // Handle multiple octave jumps
    newOctave += semitones ~/ 12;

    return '$transposedNote$newOctave';
  }

  int _getNoteIndex(String note) {
    final upper = note.toUpperCase();

    // Normalize enharmonic equivalents
    const normalizedNotes = {
      'C': 0, 'C#': 1, 'DB': 1, 'D': 2, 'D#': 3, 'EB': 3,
      'E': 4, 'F': 5, 'F#': 6, 'GB': 6, 'G': 7, 'G#': 8,
      'AB': 8, 'A': 9, 'A#': 10, 'BB': 10, 'B': 11,
    };

    return normalizedNotes[upper] ?? 0;
  }

  String _transposeChord(String chord, int semitones) {
    return _transpositionService.transposeChord(
      chord,
      semitones,
      targetKey: _transpositionService.calculateTargetKey(
        widget.notation.originalKey,
        semitones,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NotationPalette.of(theme);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Lay out once at the viewport width — NOT divided by textScale — so the
        // music never re-wraps as it zooms. Zoom is a pure visual scale below.
        final layout = _layoutFor(constraints.maxWidth);
        final scaledWidth = layout.totalWidth * widget.textScale;

        return Scrollbar(
          controller: _vScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _vScrollController,
            // Horizontal scroll for when the zoomed sheet is wider than the
            // viewport. minWidth keeps it centered while it still fits.
            child: Scrollbar(
              controller: _hScrollController,
              thumbVisibility: scaledWidth > constraints.maxWidth,
              notificationPredicate: (n) => n.depth == 1,
              child: SingleChildScrollView(
                controller: _hScrollController,
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: scaledWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Song header
                          _buildHeader(context),

                          const SizedBox(height: 16),

                          // Sheet music canvas with RepaintBoundary for
                          // performance. The canvas is invisible to the
                          // accessibility tree, so a Semantics label describes
                          // it for screen-reader users (06-01). Sizing is
                          // scaled by textScale for smooth zoom (04-04).
                          Semantics(
                            label:
                                'Sheet music notation for ${widget.song.title}',
                            image: true,
                            child: RepaintBoundary(
                              child: SizedBox(
                                width: scaledWidth,
                                height: layout.totalHeight * widget.textScale,
                                child: CustomPaint(
                                  painter: SheetMusicPainter(
                                    layout: layout,
                                    noteColor: palette.note,
                                    staffColor: palette.staff,
                                    lyricColor: palette.lyric,
                                    chordColor: palette.chord,
                                    headerColor: palette.header,
                                    showChords: widget.showChords,
                                    textScale: widget.textScale,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Additional verses without notation
                          ..._buildAdditionalVerses(context),

                          // Metadata footer
                          _buildFooter(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final targetKey = _transpositionService.calculateTargetKey(
      widget.notation.originalKey,
      widget.transpose,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reference
          if (widget.song.reference != null)
            Text(
              widget.song.reference!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.textTheme.bodySmall?.color,
              ),
            ),

          // Key information
          Row(
            children: [
              Text(
                'Key: $targetKey',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.transpose != 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Transposed ${widget.transpose > 0 ? '+' : ''}${widget.transpose}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (widget.song.timeSignature != null)
            Text(
              'Time: ${widget.song.timeSignature}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  List<Widget> _buildAdditionalVerses(BuildContext context) {
    final theme = Theme.of(context);
    final additionalVerses = widget.song.verses.where((v) => !v.hasNotation);

    return additionalVerses.map((verse) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${verse.number}.',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              verse.plainText ?? verse.displayText,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final song = widget.song;

    if (song.origin?.displayString == null && song.tune?.name == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          if (song.tune?.name != null)
            Text(
              'Tune: ${song.tune!.name}${song.tune!.origin?.displayString != null ? ' (${song.tune!.origin!.displayString})' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          if (song.origin?.displayString != null)
            Text(
              'Origin: ${song.origin!.displayString}',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// A wrapper widget that handles songs with or without notation data
class SheetMusicView extends StatelessWidget {
  final Song song;
  final SongNotation? notation;
  final int transpose;

  const SheetMusicView({
    super.key,
    required this.song,
    this.notation,
    this.transpose = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (notation == null) {
      return _buildNoNotation(context);
    }

    return SheetMusicRenderer(
      song: song,
      notation: notation!,
      transpose: transpose,
    );
  }

  Widget _buildNoNotation(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Sheet music not available',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Switch to chord view to see lyrics with chords',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }
}
