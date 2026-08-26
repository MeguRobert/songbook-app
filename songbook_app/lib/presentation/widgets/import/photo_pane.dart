import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// The photograph a reading came from, beside the reading.
///
/// The gold editor in `tools/ocr_harness` has had this from the start and it is
/// the single thing that makes correcting a page tractable: a chord in the wrong
/// column, a lost accent, a row read as lyrics are all obvious next to the page
/// and all invisible without it. The app threw the bytes away as soon as the
/// reader was done with them.
///
/// Zoomable, because the reason to look is usually one character. Nothing is
/// stored: these bytes live as long as the screen does and are never uploaded -
/// the words reader runs in the browser and the database has no column for an
/// image.
class PhotoPane extends StatelessWidget {
  const PhotoPane({
    super.key,
    required this.bytes,
    required this.height,
    this.name,
  });

  final Uint8List bytes;
  final double height;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.importSectionPhoto,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: InteractiveViewer(
              maxScale: 8,
              // Clipped rather than free: the page is being compared with the
              // reading beside it, and a photograph escaping its own box over
              // the top of that is worse than not being able to fling it about.
              clipBehavior: Clip.hardEdge,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                // A picked file that decodes to nothing must not take the review
                // surface down with it - the reading is already in hand.
                errorBuilder: (context, error, stack) => Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [if (name != null) name!, l10n.importPhotoZoomHint].join(' \u00b7 '),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
