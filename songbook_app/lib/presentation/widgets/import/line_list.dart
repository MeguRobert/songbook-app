import 'package:flutter/material.dart';

import '../../../domain/services/chord_sheet_parser.dart';
import '../../../l10n/app_localizations.dart';

/// The parsed lines of an import, each one correctable.
///
/// The measurement harness has a gold editor (`tools/ocr_harness edit`) that is
/// plainly better at fixing a photographed page than this app was: it shows the
/// photograph beside the parsed lines, says which rows it reads as chords, and
/// lets you fix one at a time. This screen had a paste box and a rendered
/// preview, so the only way to correct a row the reader got wrong was to retype
/// monospaced text in a text field and hope the columns still lined up.
///
/// That is backwards. The editor exists for nine photographs; the app is for
/// every photograph anyone ever takes.
///
/// Two things can be done to a row, and they are not equally useful:
///
/// * **Tap a chord to correct it.** This is the common repair by a wide margin.
///   The reader misreads a glyph now and then — `Csus2` comes back as `5US2` on
///   `125-nincs-mas-isten` — and once the token is right the parser classifies
///   the row correctly on its own, with nothing overridden and a real chord in
///   storage.
/// * **Say what kind a whole row is.** For the residue: a row the rule cannot be
///   talked into reading correctly. It sets a [LineKinds] entry, and it says
///   nothing about what the row's tokens mean, so a token that is not a chord
///   symbol still reaches storage as one. That is why the token edit is the
///   primary action and this is the fallback.
class LineList extends StatelessWidget {
  const LineList({
    super.key,
    required this.text,
    required this.kinds,
    required this.onKind,
    required this.onToken,
    this.parser = const ChordSheetParser(),
  });

  /// The sheet as typed or read. Line indexes below are into this, split on
  /// newlines, counting blanks — the same indexes [LineKinds] uses.
  final String text;

  /// Which lines somebody overruled the parser about.
  final LineKinds kinds;

  /// Called with a line index and the kind chosen, or null to hand that line
  /// back to the parser.
  final void Function(int index, LineKind? kind) onKind;

  /// Called with a line index, the token's column in that line, and the token,
  /// when a chip is tapped.
  final void Function(int index, int column, String token) onToken;

  final ChordSheetParser parser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final lines = text.split(RegExp(r'\r\n|\r|\n'));

    final rows = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Blank lines are verse breaks and carry nothing to correct. Shown as a
      // gap so the row numbers still match what is in the box.
      if (line.trim().isEmpty) {
        rows.add(const SizedBox(height: 10));
        continue;
      }
      rows.add(_Row(
        index: i,
        line: line,
        // The one place this asks the parser, so the badge and the preview
        // cannot disagree about a row.
        isChords: kinds.isChords(i) ?? parser.isChordLine(line),
        overridden: kinds.kindOf(i) != null,
        parser: parser,
        onKind: onKind,
        onToken: onToken,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.importLinesHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.index,
    required this.line,
    required this.isChords,
    required this.overridden,
    required this.parser,
    required this.onKind,
    required this.onToken,
  });

  final int index;
  final String line;
  final bool isChords;
  final bool overridden;
  final ChordSheetParser parser;
  final void Function(int index, LineKind? kind) onKind;
  final void Function(int index, int column, String token) onToken;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solid when a person chose, outlined when the parser did. The
          // difference matters: one of them is evidence and the other is a
          // guess, and only the guess is worth arguing with.
          Tooltip(
            message: overridden ? l10n.importLineOverridden : '',
            child: _Badge(
              label: isChords
                  ? l10n.importLineKindChords
                  : l10n.importLineKindLyric,
              solid: overridden,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: isChords
                ? _Chips(
                    line: line,
                    parser: parser,
                    onTap: (column, token) => onToken(index, column, token),
                  )
                : Text(
                    line.trimRight(),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13),
                  ),
          ),
          const SizedBox(width: 8),
          // The current kind is selected, and tapping it hands the row back to
          // the parser rather than doing nothing - so an override can always be
          // undone by the control that made it.
          _KindButton(
            label: l10n.importLineKindChords,
            selected: isChords,
            onPressed: () => onKind(index, isChords ? null : LineKind.chords),
          ),
          _KindButton(
            label: l10n.importLineKindLyric,
            selected: !isChords,
            onPressed: () => onKind(index, isChords ? LineKind.lyric : null),
          ),
        ],
      ),
    );
  }
}

/// A chord row's tokens, each tappable.
///
/// Laid out as chips rather than monospaced text on purpose: the columns are
/// what the *preview* is for, and a row of touch targets is what this is for.
class _Chips extends StatelessWidget {
  const _Chips({required this.line, required this.parser, required this.onTap});

  final String line;
  final ChordSheetParser parser;
  final void Function(int column, String token) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final (token, column) in parser.tokensIn(line))
          InkWell(
            onTap: () => onTap(column, token),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                token,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  // A token the rule cannot spell is marked, because that is the
                  // one worth tapping. It still reaches storage as a chord if the
                  // row is chords, which is the point of saying so here.
                  color: parser.isChordToken(token)
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.error,
                  decoration: parser.isChordToken(token)
                      ? null
                      : TextDecoration.underline,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.solid});

  final String label;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: solid ? theme.colorScheme.secondaryContainer : null,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: solid
              ? theme.colorScheme.onSecondaryContainer
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: solid ? FontWeight.bold : null,
        ),
      ),
    );
  }
}

class _KindButton extends StatelessWidget {
  const _KindButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor:
            selected ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}
