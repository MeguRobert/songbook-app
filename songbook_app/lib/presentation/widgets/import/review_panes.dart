import 'package:flutter/material.dart';

import '../content_pane.dart';

/// The photograph beside the reading, or above it when there is no room.
///
/// The whole point of keeping the photograph is that a reading is checked
/// against the page it came from, not admired on its own, so the two share a
/// row wherever they fit. Under [sideBySideAt] they stack, photograph first: a
/// phone is where photos get taken, and scrolling past the page to reach the
/// reading is the right order there.
///
/// Its own widget, with its own test, because the breakpoint is a number that
/// has already been wrong once without anything noticing. It shipped at 900.
/// The import screen sits in a [ContentPane.list], which caps it at
/// [ContentWidths.list] and pads it by 16 a side, so the widest this is ever
/// given on a desktop is 768 - and the side-by-side branch was dead code from
/// the day it was written. Every widget test passed; it was found by building
/// the app and opening it in a browser 1400 wide. The number now lives here
/// with the arithmetic beside it, and the test pins it under what the pane can
/// deliver.
class ReviewPanes extends StatelessWidget {
  const ReviewPanes({super.key, required this.preview, this.photo});

  /// The rendered reading - the real song view, so what is approved here is
  /// what will be shown later.
  final Widget preview;

  /// The page it was read from, or null when the reading was pasted.
  final Widget? photo;

  /// The narrowest width at which the two sit side by side.
  ///
  /// 720: two panes of 352 and a 16 gutter. That is a phone's width each,
  /// which is the width the song view is designed for, and enough of the
  /// photograph to see which row a chord belongs to; the pane zooms for the
  /// rest. Anything above `ContentWidths.list - 32` could never be reached.
  static const double sideBySideAt = 720;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    if (photo == null) return preview;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < sideBySideAt) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [photo, const SizedBox(height: 12), preview],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: photo),
            const SizedBox(width: 16),
            Expanded(child: preview),
          ],
        );
      },
    );
  }
}
