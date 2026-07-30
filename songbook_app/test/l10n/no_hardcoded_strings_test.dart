import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Catches user-facing English left behind in a screen that is supposed to be
/// translated.
///
/// This exists because the extraction pass missed things three times in a row —
/// two section headings and a line of capo advice — and each time it took a
/// browser and a Hungarian screenshot to notice. A screen half in one language
/// is worse than a screen honestly in the other, and nothing else fails when it
/// happens: the app compiles, every test passes, and the words just sit there.
///
/// Heuristic, deliberately. It flags a literal that *looks* like a sentence or a
/// heading — capitalised or ALL-CAPS, and more than one word — inside a widget
/// slot that puts text on screen. Anything it cannot judge is listed in
/// [_allowed] with a reason, so the exceptions stay visible instead of the rule
/// being weakened.

/// Files whose user-facing strings have been moved into the ARBs. Add a file
/// here as it is translated; that is the point — the list is the claim.
const _localised = [
  'lib/app.dart',
  'lib/presentation/widgets/scaffold_with_nav_bar.dart',
  'lib/presentation/screens/song_list/song_list_screen.dart',
  'lib/presentation/screens/song_list/widgets/searchable_app_bar.dart',
  'lib/presentation/screens/song_list/widgets/recent_searches_list.dart',
  'lib/presentation/screens/song_view/song_view_screen.dart',
  'lib/presentation/screens/song_view/widgets/song_controls_sheet.dart',
  'lib/presentation/screens/song_view/widgets/setlist_nav_bar.dart',
  'lib/presentation/screens/favorites/favorites_screen.dart',
];

/// Literals that are not interface text, with the reason each is here.
const _allowed = <String>{
  'Songbook App', // package description in a doc comment
};

/// Widget slots that put a string in front of the user.
final _slots = RegExp(
  r"""(?:Text|Tooltip|SemanticsLabel)\(\s*'((?:[^'\\]|\\.)*)'"""
  r"""|(?:tooltip|label|title|hintText|labelText|semanticsLabel)\s*:\s*'((?:[^'\\]|\\.)*)'""",
);

/// Looks like interface prose rather than a key name, a font family or a symbol.
bool _looksLikeSentence(String value) {
  final text = value.trim();
  if (text.length < 4) return false;
  if (_allowed.contains(text)) return false;
  // A single word is usually a musical key, a font, or a chord — not a sentence.
  final words = text.split(RegExp(r'\s+'));
  final isAllCaps = text == text.toUpperCase() &&
      RegExp(r'[A-Z]{3,}').hasMatch(text);
  if (words.length < 2 && !isAllCaps) return false;
  // Must start like English prose.
  return RegExp(r'^[A-Z]').hasMatch(text);
}

void main() {
  test('no English is left on a translated screen', () {
    final offenders = <String>[];

    for (final path in _localised) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is listed but missing');

      // Whole-file, not line-by-line: a `Text(` and its literal are routinely on
      // separate lines, and a per-line scan silently skips exactly those.
      // Comment lines are stripped first — they are prose about the code.
      final source = file
          .readAsLinesSync()
          .map((l) => l.trimLeft().startsWith('//') ? '' : l)
          .join('\n');

      for (final match in _slots.allMatches(source)) {
        final value = match.group(1) ?? match.group(2) ?? '';
        if (!_looksLikeSentence(value)) continue;
        final line = source.substring(0, match.start).split('\n').length;
        offenders.add('$path:$line  "$value"');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these belong in lib/l10n/app_en.arb:\n${offenders.join('\n')}',
    );
  });
}
