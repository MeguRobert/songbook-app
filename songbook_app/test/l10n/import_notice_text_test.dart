import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/import_notice.dart';
import 'package:songbook_app/l10n/app_localizations.dart';
import 'package:songbook_app/presentation/l10n/import_notice_text.dart';

/// The importer's and the parser's messages, in all three languages.
///
/// These were the last English strings a user could see: the two services that
/// raise them are pure domain code with no `BuildContext`, so they used to build
/// their own prose. Now they name a code and this formatter says it in words —
/// which means the failure mode moves here. A code with no ARB entry, or one
/// whose Hungarian silently fell back to the English template, is invisible at
/// runtime: the app compiles, the warning appears, and it is simply in the wrong
/// language. So every code is rendered in every locale and compared.

/// One representative notice per code, with arguments where the code takes them.
///
/// The map is checked for completeness below, so adding a code without adding a
/// sample fails here rather than shipping an unrendered warning.
const _samples = <ImportNoticeCode, ImportNotice>{
  ImportNoticeCode.unknownDirective: ImportNotice(
      ImportNoticeCode.unknownDirective, line: 3, text: '{define: G}'),
  ImportNoticeCode.ambiguousBareRoot:
      ImportNotice(ImportNoticeCode.ambiguousBareRoot, line: 7, text: 'A'),
  ImportNoticeCode.continuationWithoutChord: ImportNotice(
      ImportNoticeCode.continuationWithoutChord, line: 4, text: '-7'),
  ImportNoticeCode.fromReader: ImportNotice(ImportNoticeCode.fromReader,
      text: 'The bottom of the page was cut off.'),
  ImportNoticeCode.bracketNotAChord:
      ImportNotice(ImportNoticeCode.bracketNotAChord, line: 1, text: 'Chorus'),
  ImportNoticeCode.photoLowResolution: ImportNotice(
      ImportNoticeCode.photoLowResolution, text: '1532×2047', count: 106),
  ImportNoticeCode.photoShowThroughRemoved:
      ImportNotice(ImportNoticeCode.photoShowThroughRemoved),
  ImportNoticeCode.photoTwoSongs:
      ImportNotice(ImportNoticeCode.photoTwoSongs, count: 2),
  ImportNoticeCode.photoNoChords: ImportNotice(ImportNoticeCode.photoNoChords),
  ImportNoticeCode.photoNothingLegible:
      ImportNotice(ImportNoticeCode.photoNothingLegible),
  ImportNoticeCode.photoGermanNoteNames: ImportNotice(
      ImportNoticeCode.photoGermanNoteNames, text: 'H7, hm'),
  ImportNoticeCode.timewiseScore: ImportNotice(ImportNoticeCode.timewiseScore),
  ImportNoticeCode.noNotes: ImportNotice(ImportNoticeCode.noNotes),
  ImportNoticeCode.extraVoicesKept:
      ImportNotice(ImportNoticeCode.extraVoicesKept, count: 3),
  ImportNoticeCode.graceNotesSkipped:
      ImportNotice(ImportNoticeCode.graceNotesSkipped, count: 2),
  ImportNoticeCode.chordsReducedToTopNote:
      ImportNotice(ImportNoticeCode.chordsReducedToTopNote, count: 4),
  ImportNoticeCode.doubleAccidentalsApproximated:
      ImportNotice(ImportNoticeCode.doubleAccidentalsApproximated, count: 1),
  ImportNoticeCode.doubleDotsReduced:
      ImportNotice(ImportNoticeCode.doubleDotsReduced, count: 5),
  ImportNoticeCode.unsupportedNoteValues: ImportNotice(
      ImportNoticeCode.unsupportedNoteValues, count: 2, text: '32nd, breve'),
  ImportNoticeCode.emptyXmlInput: ImportNotice(ImportNoticeCode.emptyXmlInput),
  ImportNoticeCode.invalidXml:
      ImportNotice(ImportNoticeCode.invalidXml, text: 'Expected close tag'),
  ImportNoticeCode.containerManifestNotScore:
      ImportNotice(ImportNoticeCode.containerManifestNotScore),
  ImportNoticeCode.emptyMxlInput: ImportNotice(ImportNoticeCode.emptyMxlInput),
  ImportNoticeCode.unreadableArchive:
      ImportNotice(ImportNoticeCode.unreadableArchive, text: 'bad CRC'),
  ImportNoticeCode.noScoreInArchive:
      ImportNotice(ImportNoticeCode.noScoreInArchive),
};

Future<AppLocalizations> load(String locale) =>
    AppLocalizations.delegate.load(Locale(locale));

void main() {
  test('every code has a sample to render', () {
    // Without this the sweeps below quietly shrink as codes are added.
    expect(_samples.keys.toSet(), ImportNoticeCode.values.toSet());
  });

  group('every notice reads as a sentence in every language', () {
    for (final locale in const ['en', 'hu', 'ro']) {
      test(locale, () async {
        final l10n = await load(locale);
        for (final entry in _samples.entries) {
          final text = l10n.importNoticeText(entry.value);
          expect(text.trim(), isNotEmpty, reason: '${entry.key.name} in $locale');
          // A placeholder name still in the output is the shape of an ARB
          // argument that was declared under one name and used under another.
          // Braces alone are not the test: `{define: G}` is a real directive,
          // and quoting one back at the user is the whole point of that message.
          for (final name in const ['{line}', '{count}', '{text}']) {
            expect(text, isNot(contains(name)),
                reason: '${entry.key.name} in $locale left $name unfilled');
          }
        }
      });
    }
  });

  /// Codes whose text is identical in every language by design.
  ///
  /// [ImportNoticeCode.fromReader] quotes prose written by the photo-reading
  /// backend, which has no idea what language the app is in. Translating it is
  /// not possible and pretending to would be worse, so it renders verbatim — and
  /// the comparison below has to know that, or it reads a deliberate choice as an
  /// untranslated string.
  const quotedVerbatim = {ImportNoticeCode.fromReader};

  group('nothing falls back to the template', () {
    // gen_l10n fills a missing key from app_en.arb, so an untranslated notice
    // is not a build failure — it is English inside a Hungarian sentence, and
    // only a comparison like this one says so.
    for (final locale in const ['hu', 'ro']) {
      test(locale, () async {
        final en = await load('en');
        final translated = await load(locale);
        for (final entry in _samples.entries) {
          if (quotedVerbatim.contains(entry.key)) continue;
          expect(
            translated.importNoticeText(entry.value),
            isNot(en.importNoticeText(entry.value)),
            reason: '${entry.key.name} is still English in $locale',
          );
        }
      });
    }
  });

  group('the facts survive the formatting', () {
    test('a line number reaches every language', () async {
      for (final locale in const ['en', 'hu', 'ro']) {
        final l10n = await load(locale);
        expect(
          l10n.importNoticeText(const ImportNotice(
              ImportNoticeCode.unknownDirective, line: 42, text: '{x}')),
          allOf(contains('42'), contains('{x}')),
          reason: locale,
        );
      }
    });

    test('a count reaches every language', () async {
      for (final locale in const ['en', 'hu', 'ro']) {
        final l10n = await load(locale);
        expect(
          l10n.importNoticeText(
              const ImportNotice(ImportNoticeCode.graceNotesSkipped, count: 9)),
          contains('9'),
          reason: locale,
        );
      }
    });

    test('a failure reason reaches every language', () async {
      for (final locale in const ['en', 'hu', 'ro']) {
        final l10n = await load(locale);
        expect(
          l10n.importNoticeText(const ImportNotice(ImportNoticeCode.invalidXml,
              text: 'Expected close tag at 1:14')),
          contains('Expected close tag at 1:14'),
          reason: locale,
        );
      }
    });

    test('the bracket token is punctuated by the formatter, not the parser',
        () async {
      // The parser hands over `Chorus`; the brackets belong to the sentence, so
      // each language can quote it its own way.
      final l10n = await load('en');
      expect(
        l10n.importNoticeText(const ImportNotice(
            ImportNoticeCode.bracketNotAChord, line: 1, text: 'Chorus')),
        contains('[Chorus]'),
      );
    });

    test('singular and plural are not the same sentence', () async {
      for (final locale in const ['en', 'hu', 'ro']) {
        final l10n = await load(locale);
        expect(
          l10n.importNoticeText(
              const ImportNotice(ImportNoticeCode.extraVoicesKept, count: 1)),
          isNot(l10n.importNoticeText(
              const ImportNotice(ImportNoticeCode.extraVoicesKept, count: 3))),
          reason: locale,
        );
      }
    });
  });
}
