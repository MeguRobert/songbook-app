import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/view_config.dart';
import '../../../providers/providers.dart';
import '../../../providers/song_provider.dart';

/// Bottom sheet widget containing all song control sections.
///
/// Organized into three labeled sections:
/// - View: Preset chips (Sheet Music, Chords, Lyrics) + Custom toggles
/// - Transpose: +/- buttons with key display and reset
/// - Text Size: A-/A+ buttons with scale percentage
class SongControlsSheet extends ConsumerStatefulWidget {
  final String originalKey;

  const SongControlsSheet({
    required this.originalKey,
    super.key,
  });

  @override
  ConsumerState<SongControlsSheet> createState() => _SongControlsSheetState();
}

class _SongControlsSheetState extends ConsumerState<SongControlsSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewConfig = ref.watch(effectiveViewConfigProvider);
    final transpose = ref.watch(transposeProvider);
    final textScale = ref.watch(textScaleProvider);
    final transpositionService = ref.read(transpositionServiceProvider);
    final songViewNotifier = ref.read(songViewProvider.notifier);

    final targetKey = transpositionService.calculateTargetKey(
      widget.originalKey,
      transpose,
    );
    final hasTranspose = transpose != 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Section
                _SectionHeader(text: 'VIEW', theme: theme),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.piano, size: 18),
                          SizedBox(width: 6),
                          Text('Sheet Music'),
                        ],
                      ),
                      selected: viewConfig.isSheetMusicPreset,
                      onSelected: (_) {
                        songViewNotifier.setPreset(const ViewConfig.sheetMusic());
                      },
                    ),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.music_note, size: 18),
                          SizedBox(width: 6),
                          Text('Chords'),
                        ],
                      ),
                      selected: viewConfig.isChordsPreset,
                      onSelected: (_) {
                        songViewNotifier.setPreset(const ViewConfig.chords());
                      },
                    ),
                    ChoiceChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.text_snippet, size: 18),
                          SizedBox(width: 6),
                          Text('Lyrics'),
                        ],
                      ),
                      selected: viewConfig.isLyricsOnlyPreset,
                      onSelected: (_) {
                        songViewNotifier.setPreset(const ViewConfig.lyricsOnly());
                      },
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Transpose Section
                _SectionHeader(text: 'TRANSPOSE', theme: theme),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: songViewNotifier.transposeDown,
                      tooltip: 'Transpose down',
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            targetKey,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (hasTranspose)
                            Text(
                              '${transpose > 0 ? '+' : ''}$transpose',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: songViewNotifier.transposeUp,
                      tooltip: 'Transpose up',
                    ),
                  ],
                ),
                if (hasTranspose) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: songViewNotifier.resetTranspose,
                      child: Text('Reset to ${widget.originalKey}'),
                    ),
                  ),
                ],

                const Divider(height: 32),

                // Text Size Section
                _SectionHeader(text: 'TEXT SIZE', theme: theme),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: songViewNotifier.decreaseTextScale,
                      child: Semantics(
                        label: 'Decrease text size',
                        excludeSemantics: true,
                        child: const Text(
                          'A-',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${(textScale * 100).round()}%',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: songViewNotifier.increaseTextScale,
                      child: Semantics(
                        label: 'Increase text size',
                        excludeSemantics: true,
                        child: const Text(
                          'A+',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Bottom padding for safe area
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header widget for labeled sections
class _SectionHeader extends StatelessWidget {
  final String text;
  final ThemeData theme;

  const _SectionHeader({
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
