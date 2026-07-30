import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/l10n/app_localizations.dart';

/// The interface is translated into Hungarian, Romanian and English.
///
/// The songs are Hungarian and the interface was not, which is the mismatch this
/// fixes. English stays as the template and the fallback for a device set to
/// anything else.
///
/// These tests guard the failure mode that matters with three ARB files: they
/// drift. A key added to the template and forgotten in `hu` does not fail the
/// build — `gen_l10n` fills the gap from the template, so the app silently shows
/// English inside a Hungarian sentence, and nothing says so.

Map<String, dynamic> arb(String locale) => json.decode(
      File('lib/l10n/app_$locale.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

/// Message keys only — `@@locale` and the `@key` metadata blocks are not
/// translatable strings.
Set<String> keysOf(Map<String, dynamic> file) =>
    file.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  final en = arb('en');
  final hu = arb('hu');
  final ro = arb('ro');

  group('the three files describe the same interface', () {
    test('Hungarian translates every key', () {
      expect(keysOf(en).difference(keysOf(hu)), isEmpty,
          reason: 'missing from app_hu.arb — these would appear in English');
    });

    test('Romanian translates every key', () {
      expect(keysOf(en).difference(keysOf(ro)), isEmpty,
          reason: 'missing from app_ro.arb — these would appear in English');
    });

    test('neither carries a key the template dropped', () {
      // A stale translation is invisible: nothing reads it, so it rots.
      expect(keysOf(hu).difference(keysOf(en)), isEmpty);
      expect(keysOf(ro).difference(keysOf(en)), isEmpty);
    });

    test('nothing is left untranslated by copy-paste', () {
      // A key whose Hungarian is byte-identical to its English is usually a
      // placeholder somebody meant to come back to. Proper nouns and language
      // names legitimately match, so those are named rather than guessed at.
      const sameOnPurpose = {
        'languageHungarian',
        'languageRomanian',
        'languageEnglish',
        'navFavorites', // "Favorites" / "Favorite" differ; RO checked below
        // The Italian voice names entered Hungarian unchanged. "Tenor" is the
        // Hungarian word; inventing a different one to satisfy this test would
        // put something wrong in front of a singer.
        'voiceTenor',
        // Hungarian guitarists say "capo". The dictionary word "kapodaszter"
        // (via German Kapodaster) was here first and the reader — a Hungarian
        // guitarist — did not recognise it. Note this is only the heading;
        // capoNone/capoAt/capoClamp around it are all genuinely translated.
        'sectionCapo',
      };

      for (final key in keysOf(en)) {
        if (sameOnPurpose.contains(key)) continue;
        expect(hu[key], isNot(en[key]), reason: '$key is still English in hu');
      }
    });
  });

  group('every supported language is actually reachable', () {
    test('the delegate supports exactly hu, ro and en', () {
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
        {'en', 'hu', 'ro'},
      );
    });

    test('each one resolves its own strings', () async {
      for (final entry in {
        'en': 'Songs',
        'hu': 'Énekek',
        'ro': 'Cântece',
      }.entries) {
        final l10n = await AppLocalizations.delegate.load(Locale(entry.key));
        expect(l10n.navSongs, entry.value);
      }
    });

    test('a language the app does not have falls back to English', () {
      // A German phone must get a usable app, not an empty one.
      expect(AppLocalizations.delegate.isSupported(const Locale('de')), isFalse);
    });
  });
}
