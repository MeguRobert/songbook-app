import 'package:flutter/material.dart';

/// Window-width breakpoints, and the wrapper that caps content against them.
///
/// This app is a PWA: the same screens render on a 390-wide phone and in a
/// 1900-wide desktop browser window. Left alone, a `Column` of text fields fills
/// whatever it is given, so the sign-in form arrived on desktop as three
/// metre-wide inputs — legible, technically correct, and clearly broken.
///
/// The numbers live here and nowhere else. A max width sprinkled inline at each
/// call site drifts within a release: two screens end up 480 and 560 wide for no
/// reason anyone can reconstruct, and nobody notices because each one looks fine
/// on its own.

/// Window widths at which the layout should change.
///
/// These are Material 3's window size class boundaries, kept to the two this app
/// actually distinguishes. `compact` is the phone/desktop line: below it the
/// window *is* the content, and constraining anything would only take space away
/// from a screen that has none to spare.
abstract final class AppBreakpoints {
  /// Above this, the window is wider than a phone and content needs a cap.
  static const double compact = 600;

  /// Above this there is room for a persistent side navigation instead of a
  /// bottom bar. Nothing uses it yet — see the note on [ContentPane].
  static const double expanded = 840;
}

/// How wide content is allowed to get on a window wider than [AppBreakpoints].
///
/// Shaped by what the content *is*, not by which screen shows it, so two screens
/// with the same kind of content cannot disagree.
abstract final class ContentWidths {
  /// A column of form controls: text fields, buttons, a submit.
  ///
  /// A text field wider than this is harder to use, not easier — the caret ends
  /// up far from the label it belongs to, and a 12-character email address
  /// floats in a metre of empty box.
  static const double form = 480;

  /// A vertical list of rows, tiles or prose.
  ///
  /// Wider than [form] because a row carries a leading icon, a title, a subtitle
  /// and a trailing control, and squeezing those into 480 wraps the subtitles.
  static const double list = 800;
}

/// Centres [child] and caps how wide it may get on a large window.
///
/// Below [AppBreakpoints.compact] this returns [child] **unchanged** — not
/// wrapped in a no-op `Center`. That is deliberate: phones are the majority of
/// this app's traffic, and a cap that is merely arithmetically inert there could
/// still change layout, because `Center` hands its child *loose* constraints
/// where a scroll viewport hands it *tight* ones, and a `Column` with
/// `CrossAxisAlignment.stretch` reads that difference. Returning the child
/// untouched makes "mobile is exactly as it was" structural rather than a claim
/// about constraint arithmetic.
///
/// Place this *inside* a scroll view, around the scroll view's child, rather than
/// around the scroll view itself: the scrollbar then stays at the window edge
/// where the pointer expects it, instead of floating in the middle of the page
/// against the content.
///
/// Not handled here: the bottom [NavigationBar], which spreads four destinations
/// across the full window on desktop. The idiomatic fix is a [NavigationRail]
/// above [AppBreakpoints.expanded], but that is a navigation change rather than a
/// width cap, so it is left as a decision rather than made silently.
class ContentPane extends StatelessWidget {
  const ContentPane({
    required this.child,
    this.maxWidth = ContentWidths.form,
    super.key,
  });

  /// A pane for a column of form controls.
  const ContentPane.form({required Widget child, Key? key})
      : this(child: child, maxWidth: ContentWidths.form, key: key);

  /// A pane for a list of rows, tiles or prose.
  const ContentPane.list({required Widget child, Key? key})
      : this(child: child, maxWidth: ContentWidths.list, key: key);

  final Widget child;

  /// The widest [child] may become once the window clears
  /// [AppBreakpoints.compact].
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // Window width, not the incoming constraints: "is this a desktop browser or
    // a phone" is a property of the window, and reading it here avoids putting a
    // LayoutBuilder — which cannot answer intrinsic-size queries — in the middle
    // of every form.
    if (MediaQuery.sizeOf(context).width <= AppBreakpoints.compact) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
