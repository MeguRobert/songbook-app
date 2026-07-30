import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/song.dart';
import '../../../../data/models/verse.dart';
import '../../../../data/models/lyric_line.dart';
import '../../../../data/models/chord_position.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../../providers/settings_provider.dart';

/// Widget for displaying song lyrics with chords
class ChordView extends ConsumerWidget {
  final Song song;
  final int transpose;
  final double textScale;
  final bool showChords;

  /// Optional external controller so the song view can drive auto-scroll.
  /// When null, the inner [SingleChildScrollView] manages its own scrolling.
  final ScrollController? scrollController;

  const ChordView({
    required this.song,
    required this.transpose,
    this.textScale = 1.0,
    this.showChords = true,
    this.scrollController,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseFontSize = ref.watch(fontSizeProvider);
    final fontSize = baseFontSize * textScale;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Every line here is a plain Text, which paints characters and offers no
    // selection at all — so there was no way to get a verse out of the app and
    // into a message. SelectionArea makes all of its descendants selectable AND
    // spans them, so one drag can take a whole verse rather than a line at a
    // time. A vertical drag still scrolls; selection begins with a long press,
    // which is also what keeps auto-scroll usable.
    return SelectionArea(
      child: SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Song metadata
            if (song.reference != null) ...[
              Text(
                song.reference!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Verses
            for (int i = 0; i < song.verses.length; i++) ...[
              _buildVerse(
                context,
                ref,
                song.verses[i],
                fontSize,
                showChords,
                isDark,
              ),
              if (i < song.verses.length - 1) const SizedBox(height: 24),
            ],

            // Origin info at bottom
            if (song.origin?.displayString != null ||
                song.tune?.name != null) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 8),
              if (song.tune?.name != null)
                Text(
                  l10n.sheetTune(
                      '${song.tune!.name}${song.tune!.origin?.displayString != null ? ' (${song.tune!.origin!.displayString})' : ''}'),
                  style: theme.textTheme.bodySmall,
                ),
              if (song.origin?.displayString != null)
                Text(
                  l10n.sheetOrigin(song.origin!.displayString!),
                  style: theme.textTheme.bodySmall,
                ),
            ],
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildVerse(
    BuildContext context,
    WidgetRef ref,
    Verse verse,
    double fontSize,
    bool showChords,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verse number
        Text(
          '${verse.number}.',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        // Verse content.
        //
        // Gated on having structured lines, NOT on [Verse.hasNotation]. Those
        // two coincide for every bundled song — verse 1 carries both engraved
        // notation and chord-positioned lines — which hid the conflation.
        // An imported song has chords and no notation, and the old condition
        // could not express that: it fell through to a plain-text branch and
        // silently dropped every chord.
        //
        // [_buildLine] already renders a chordless line as plain text, so it
        // is the right destination for structured lines either way.
        if (verse.lines.isNotEmpty)
          ...verse.lines.map((line) => _buildLine(
                context,
                ref,
                line,
                fontSize,
                showChords,
                isDark,
              ))
        else if (verse.plainText != null)
          Text(
            verse.plainText!,
            style: TextStyle(fontSize: fontSize, height: 1.6),
          ),
      ],
    );
  }

  Widget _buildLine(
    BuildContext context,
    WidgetRef ref,
    LyricLine line,
    double fontSize,
    bool showChords,
    bool isDark,
  ) {
    if (!showChords || line.chords.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          line.text,
          style: TextStyle(fontSize: fontSize, height: 1.6),
        ),
      );
    }

    // Transpose chords if needed
    final transpositionService = ref.read(transpositionServiceProvider);
    final targetKey = transpositionService.calculateTargetKey(
      song.originalKey,
      transpose,
    );
    final transposedChords = line.chords.map((cp) {
      return ChordPosition(
        chord: transpositionService.transposeChord(
          cp.chord,
          transpose,
          targetKey: targetKey,
        ),
        position: cp.position,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chord line
          _buildChordLine(context, line.text, transposedChords, fontSize, isDark),
          // Lyric line
          Text(
            line.text,
            style: TextStyle(fontSize: fontSize, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildChordLine(
    BuildContext context,
    String text,
    List<ChordPosition> chords,
    double fontSize,
    bool isDark,
  ) {
    // Build a text widget that positions chords above the correct characters
    final chordFontSize = fontSize * 0.75;
    final charWidth = fontSize * 0.55; // Approximate character width

    // Sort chords by position
    final sortedChords = List<ChordPosition>.from(chords)
      ..sort((a, b) => a.position.compareTo(b.position));

    // Build chord display with proper spacing
    final chordWidgets = <Widget>[];
    int currentPos = 0;

    for (final cp in sortedChords) {
      // Add spacing before chord if needed
      if (cp.position > currentPos) {
        final spacerWidth = (cp.position - currentPos) * charWidth;
        chordWidgets.add(SizedBox(width: spacerWidth));
      }

      // Add chord
      chordWidgets.add(
        Text(
          cp.chord,
          style: TextStyle(
            fontSize: chordFontSize,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.chordDark : AppColors.chordLight,
          ),
        ),
      );

      // Update position (chord takes up space)
      currentPos = cp.position + cp.chord.length;
    }

    return SizedBox(
      height: chordFontSize + 4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: chordWidgets,
      ),
    );
  }
}
