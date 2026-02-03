import 'package:flutter/material.dart';
import '../../../data/models/notation.dart';
import '../../../data/models/song.dart';
import '../../../domain/services/transposition_service.dart';
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

  /// Called when notation is not available
  final Widget? fallback;

  const SheetMusicRenderer({
    super.key,
    required this.song,
    required this.notation,
    this.transpose = 0,
    this.fallback,
  });

  @override
  State<SheetMusicRenderer> createState() => _SheetMusicRendererState();
}

class _SheetMusicRendererState extends State<SheetMusicRenderer> {
  final TranspositionService _transpositionService = const TranspositionService();

  @override
  void initState() {
    super.initState();
    _calculateLayout();
  }

  @override
  void didUpdateWidget(SheetMusicRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notation != widget.notation ||
        oldWidget.transpose != widget.transpose) {
      _calculateLayout();
    }
  }

  void _calculateLayout() {
    // We'll calculate layout in build using LayoutBuilder for width
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutEngine = SheetMusicLayoutEngine(
          availableWidth: constraints.maxWidth,
          transposePitch: _transposePitch,
          transposeChord: _transposeChord,
        );

        final layout = layoutEngine.calculateLayout(
          widget.notation,
          widget.transpose,
        );

        return InteractiveViewer(
          constrained: false,
          minScale: 0.5,
          maxScale: 3.0,
          boundaryMargin: const EdgeInsets.all(100),
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Song header
                _buildHeader(context),

                const SizedBox(height: 16),

                // Sheet music canvas with RepaintBoundary for performance
                RepaintBoundary(
                  child: SizedBox(
                    width: layout.totalWidth,
                    height: layout.totalHeight,
                    child: CustomPaint(
                      painter: SheetMusicPainter(
                        layout: layout,
                        noteColor: theme.brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF333333),
                        staffColor: theme.brightness == Brightness.dark
                            ? Colors.white70
                            : const Color(0xFF333333),
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
