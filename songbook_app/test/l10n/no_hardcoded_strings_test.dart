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
  'lib/presentation/screens/notation_editor/notation_editor_screen.dart',
  'lib/presentation/screens/settings/settings_screen.dart',
  'lib/presentation/screens/setlists/setlists_screen.dart',
  'lib/presentation/screens/setlists/setlist_detail_screen.dart',
  'lib/presentation/screens/import/import_song_screen.dart',
  'lib/presentation/screens/song_view/widgets/tag_editor_sheet.dart',
  'lib/presentation/screens/song_list/widgets/filter_sheets.dart',
  'lib/presentation/screens/presentation/presentation_screen.dart',
  'lib/presentation/widgets/sheet_music/sheet_music_renderer.dart',
  'lib/presentation/screens/song_view/widgets/chord_view.dart',
  'lib/presentation/screens/song_view/widgets/sheet_music_view.dart',
  'lib/router/app_router.dart',
  'lib/presentation/screens/admin/admin_gate.dart',
  'lib/presentation/screens/admin/admin_overview_screen.dart',
  'lib/presentation/screens/admin/admin_users_screen.dart',
  'lib/presentation/screens/admin/admin_user_detail_screen.dart',
  'lib/presentation/screens/admin/admin_settings_screen.dart',
  'lib/presentation/screens/admin/role_label.dart',
];

/// Literals that are not interface text, with the reason each is here.
const _allowed = <String>{
  'Songbook App', // package description in a doc comment
  // Language names labelling the three guidelines boxes in admin settings.
  // Deliberately NOT translated: each labels a field holding that language's own
  // text, so it is an endonym — a Hungarian speaker looks for "Magyar", not
  // "Hungarian". Translating them would make the label change language while the
  // box underneath it did not.
  'Magyar',
  'Română',
  'English',
};

/// Widget slots that put a string in front of the user.
final _slots = RegExp(
  r"""(?:Text|Tooltip|SemanticsLabel)\(\s*'((?:[^'\\]|\\.)*)'"""
  r"""|(?:tooltip|label|title|hintText|labelText|semanticsLabel)\s*:\s*'((?:[^'\\]|\\.)*)'""",
);

/// A domain service handing a *sentence* to something that will be displayed.
///
/// The other direction again, for the half of the app the sweep above cannot
/// see. `ChordSheetParser` and `MusicXmlImporter` reach the user too — their
/// warnings and errors are printed on the import screen — but they are pure
/// domain code with no `BuildContext`, so they used to build their own English.
/// Nothing failed: `warnings.add('...')` is not a widget slot, so both guards
/// above looked straight past it, which is how these outlasted every earlier
/// extraction pass and stayed English while all 21 screens were translated.
///
/// They report `ImportNotice` codes now. This is what keeps it that way — and
/// it sweeps `lib/` rather than a list, so a *third* service written the old way
/// fails here instead of shipping.
final _prose = RegExp(
  r"""(?:warnings\.add|notices\.add|MusicXmlImportException)\(\s*'""",
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

/// Interface text found in [path], as `path:line  "value"` strings.
List<String> _englishIn(String path) {
  // Whole-file, not line-by-line: a `Text(` and its literal are routinely on
  // separate lines, and a per-line scan silently skips exactly those.
  // Comment lines are stripped first — they are prose about the code.
  final source = File(path)
      .readAsLinesSync()
      .map((l) => l.trimLeft().startsWith('//') ? '' : l)
      .join('\n');

  final found = <String>[];
  for (final match in _slots.allMatches(source)) {
    final value = match.group(1) ?? match.group(2) ?? '';
    if (!_looksLikeSentence(value)) continue;
    final line = source.substring(0, match.start).split('\n').length;
    found.add('$path:$line  "$value"');
  }
  return found;
}

void main() {
  test('no English is left on a translated screen', () {
    final offenders = <String>[];

    for (final path in _localised) {
      expect(File(path).existsSync(), isTrue,
          reason: '$path is listed but missing');
      offenders.addAll(_englishIn(path));
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these belong in lib/l10n/app_en.arb:\n${offenders.join('\n')}',
    );
  });

  test('every file with interface text is claimed as localised', () {
    // The other direction, and the one that actually caught something: the test
    // above only ever looks where it is told to. A handoff note listing the
    // files left to translate missed `chord_view`, the legacy `sheet_music_view`
    // and the router's 404 — three surfaces a singer sees — and nothing failed,
    // because none of them was on the list. Sweeping lib/ instead means a NEW
    // screen written with hardcoded strings fails here rather than shipping.
    final claimed = _localised.toSet();
    final unclaimed = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      // The generated AppLocalizations *is* the English, by definition.
      if (path.startsWith('lib/l10n/')) continue;
      if (claimed.contains(path)) continue;
      unclaimed.addAll(_englishIn(path));
    }

    expect(
      unclaimed,
      isEmpty,
      reason: 'either translate these and add the file to _localised, or — if '
          'the string is not interface text — add it to _allowed with a '
          'reason:\n${unclaimed.join('\n')}',
    );
  });

  /// Files with known untranslated warnings, exempted deliberately and visibly.
  ///
  /// Empty, and worth keeping as a place to be honest in rather than deleting.
  ///
  /// It held `photo_text_bridge.dart` and its four English warnings — nothing
  /// legible, a page holding two songs, no chords recognised, German note names
  /// renamed — on the grounds that converting them was not a local change:
  /// `PhotoReading.warnings` fed both `PhotoImportException`'s message and
  /// `ChordProPayload`, which the remote reader also fills with prose of its
  /// own, so the type had to change right across the photo pipeline. That is
  /// what happened, and the two warnings the app measured and never raised —
  /// a photograph too compressed to hold its accents, and show-through erased —
  /// went in at the same time, because they needed the same seam.
  const proseDebt = <String>{};

  test('no importer or parser message is written as prose', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/l10n/')) continue;
      if (proseDebt.contains(path)) continue;

      final lines = entity.readAsLinesSync();
      // Whole-file: the literal and the call routinely sit on separate lines.
      final source = lines
          .map((l) => l.trimLeft().startsWith('//') ? '' : l)
          .join('\n');
      for (final match in _prose.allMatches(source)) {
        final line = source.substring(0, match.start).split('\n').length;
        offenders.add('$path:$line  ${match.group(0)!.trim()}…');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'a warning or an error a user will read must be an ImportNotice '
          'code, not a String — the service raising it has no BuildContext, so '
          'anything it writes is English on a Hungarian screen. Add a code to '
          'ImportNoticeCode and a message to all three ARBs '
          'instead:\n${offenders.join('\n')}',
    );
  });
}
