import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../data/models/song.dart';
import '../../../providers/providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/sheet_music/sheet_music_renderer.dart';

/// Widget for displaying sheet music
/// Uses the new custom renderer when notation data is available,
/// falls back to legacy SVG rendering otherwise.
class SheetMusicViewWidget extends ConsumerWidget {
  final Song song;
  final int transpose;

  const SheetMusicViewWidget({
    required this.song,
    required this.transpose,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(fontSizeProvider);

    // Use the new custom renderer if notation data is available
    if (song.hasNotation) {
      if (kDebugMode) {
        debugPrint('[SheetMusicView] Song ${song.number}: Using CUSTOM Canvas renderer (notation available)');
      }
      return _buildCustomRenderer(context, ref);
    }

    // Fall back to legacy SVG rendering
    if (kDebugMode) {
      debugPrint('[SheetMusicView] Song ${song.number}: Using LEGACY SVG renderer (no notation data)');
    }
    return _buildLegacyView(context, ref, fontSize);
  }

  Widget _buildCustomRenderer(BuildContext context, WidgetRef ref) {
    final renderer = SheetMusicRenderer(
      song: song,
      notation: song.notation!,
      transpose: transpose,
    );

    // Add debug badge in debug mode
    if (kDebugMode) {
      return Stack(
        children: [
          renderer,
          Positioned(
            top: 4,
            right: 4,
            child: _buildRendererBadge(context, isCanvas: true),
          ),
        ],
      );
    }

    return renderer;
  }

  Widget _buildRendererBadge(BuildContext context, {required bool isCanvas}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isCanvas ? Colors.green.withValues(alpha: 0.8) : Colors.orange.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isCanvas ? 'Canvas' : 'SVG',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLegacyView(BuildContext context, WidgetRef ref, double fontSize) {
    final transpositionService = ref.read(transpositionServiceProvider);
    final targetKey = transpositionService.calculateTargetKey(
      song.originalKey,
      transpose,
    );

    final legacyView = InteractiveViewer(
      constrained: false,
      minScale: 0.5,
      maxScale: 3.0,
      boundaryMargin: const EdgeInsets.all(100),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Song header
            _buildHeader(context, targetKey),
            const SizedBox(height: 24),

            // Sheet music (if available)
            if (song.hasSheetMusic)
              _buildSheetMusic(context, targetKey)
            else
              _buildNoSheetMusic(context),

            const SizedBox(height: 24),

            // Additional verses as plain text
            for (final verse
                in song.verses.where((v) => !v.hasNotation)) ...[
              _buildPlainVerse(context, verse, fontSize),
              const SizedBox(height: 16),
            ],

            // Metadata footer
            _buildMetadataFooter(context),
          ],
        ),
      ),
    );

    // Add debug badge in debug mode
    if (kDebugMode) {
      return Stack(
        children: [
          legacyView,
          Positioned(
            top: 4,
            right: 4,
            child: _buildRendererBadge(context, isCanvas: false),
          ),
        ],
      );
    }

    return legacyView;
  }

  Widget _buildHeader(BuildContext context, String targetKey) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reference
        if (song.reference != null)
          Text(
            song.reference!,
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
            if (transpose != 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Transposed from ${song.originalKey}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (song.timeSignature != null)
          Text(
            'Time: ${song.timeSignature}',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildSheetMusic(BuildContext context, String targetKey) {
    final svgPath = song.sheetMusic!.getPathForKey(targetKey);
    final originalPath = song.sheetMusic!.getPathForKey(song.originalKey);

    return FutureBuilder<String>(
      // Try to load the transposed version first
      future: _tryLoadSvg(svgPath).then((svg) {
        if (svg != null) return svg;
        // Fall back to original key
        return _tryLoadSvg(originalPath).then((svg) => svg ?? '');
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildNoSheetMusic(context);
        }

        return Column(
          children: [
            if (transpose != 0 && !svgPath.contains(targetKey))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing original key (${song.originalKey}). '
                        'Transpose to $targetKey manually.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            SvgPicture.string(
              snapshot.data!,
              fit: BoxFit.contain,
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoSheetMusic(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
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

  Widget _buildPlainVerse(BuildContext context, verse, double fontSize) {
    final theme = Theme.of(context);

    return Column(
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
          style: TextStyle(fontSize: fontSize, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildMetadataFooter(BuildContext context) {
    final theme = Theme.of(context);

    if (song.origin?.displayString == null && song.tune?.name == null) {
      return const SizedBox.shrink();
    }

    return Column(
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
    );
  }

  Future<String?> _tryLoadSvg(String path) async {
    try {
      final svgString = await rootBundle.loadString(path);
      return svgString;
    } catch (_) {
      return null;
    }
  }
}

// Keep the old name for backwards compatibility
typedef SheetMusicView = SheetMusicViewWidget;
