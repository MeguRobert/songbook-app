import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../data/models/song.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/sheet_music/sheet_music_renderer.dart';

/// Widget for displaying sheet music
/// Uses the new custom renderer when notation data is available,
/// falls back to legacy SVG rendering otherwise.
class SheetMusicViewWidget extends ConsumerWidget {
  final Song song;
  final int transpose;
  final bool showChords;
  final double textScale;

  /// Engrave every voice of a four-part score at once, on stacked staves.
  ///
  /// Requires [song] to carry its notation as STORED — see
  /// [SheetMusicRenderer.grandStaff]. The legacy SVG path ignores this: a
  /// pre-rendered image is whatever it is.
  final bool grandStaff;

  const SheetMusicViewWidget({
    required this.song,
    required this.transpose,
    this.showChords = true,
    this.textScale = 1.0,
    this.grandStaff = false,
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
      showChords: showChords,
      textScale: textScale,
      grandStaff: grandStaff,
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

    final legacyView = SingleChildScrollView(
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
    final l10n = AppLocalizations.of(context);

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
              l10n.sheetKey(targetKey),
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
                  l10n.sheetTransposedFrom(song.originalKey),
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
            l10n.sheetTime(song.timeSignature!),
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildSheetMusic(BuildContext context, String targetKey) {
    final svgPath = song.sheetMusic!.getPathForKey(targetKey);
    final originalPath = song.sheetMusic!.getPathForKey(song.originalKey);

    return FutureBuilder<({String? svg, bool isOriginalFallback})>(
      future: _loadSheetMusicWithFallback(svgPath, originalPath, targetKey, song.originalKey),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.svg == null) {
          return _buildNoSheetMusic(context);
        }

        final result = snapshot.data!;

        return Column(
          children: [
            if (result.isOriginalFallback)
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
                        AppLocalizations.of(context)
                            .sheetMissingForKey(targetKey, song.originalKey),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            SvgPicture.string(
              result.svg!,
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
            AppLocalizations.of(context).sheetNoneForSong,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).sheetNotAvailableHint,
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
    final l10n = AppLocalizations.of(context);

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
    );
  }

  Future<({String? svg, bool isOriginalFallback})> _loadSheetMusicWithFallback(
    String transposedPath,
    String originalPath,
    String targetKey,
    String originalKey,
  ) async {
    // If not transposed, just try loading the original
    if (targetKey == originalKey) {
      final svg = await _tryLoadSvg(originalPath);
      return (svg: svg, isOriginalFallback: false);
    }
    // Try transposed first
    final transposedSvg = await _tryLoadSvg(transposedPath);
    if (transposedSvg != null) {
      return (svg: transposedSvg, isOriginalFallback: false);
    }
    // Fall back to original
    final originalSvg = await _tryLoadSvg(originalPath);
    if (originalSvg != null) {
      return (svg: originalSvg, isOriginalFallback: true);
    }
    // Nothing available — null means "not found at all"
    return (svg: null, isOriginalFallback: false);
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
