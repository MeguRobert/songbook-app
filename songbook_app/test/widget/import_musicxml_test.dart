import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/domain/services/musicxml_importer.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The MusicXML import path.
///
/// The file picker itself cannot be driven in a widget test (it is a platform
/// channel / HTML input), so these exercise everything on either side of it:
/// the importer against the REAL Audiveris output this project produces, and
/// that a song carrying notation stores and reloads intact.
///
/// Driving the picker is covered manually in a browser.
void main() {
  const importer = MusicXmlImporter();

  File realMxl() => File('../tools/audiveris_output/zsolt-090.width-800.mxl');

  test('the real Audiveris .mxl imports into a storable song', () {
    final result = importer.importCompressed(realMxl().readAsBytesSync());

    expect(result.notation.verses, isNotEmpty);
    expect(result.notation.originalKey, 'Bb');

    final song = Song(
      number: 90,
      title: 'Te benned bíztunk eleitől fogva',
      originalKey: result.key ?? result.notation.originalKey,
      timeSignature: result.timeSignature,
      notation: result.notation,
      verses: result.verses,
      book: 'Saját énekek',
    );
    expect(song.hasNotation, isTrue);
  });

  test('a notated song survives storage byte-for-byte', () async {
    final result = importer.importCompressed(realMxl().readAsBytesSync());
    final song = Song(
      number: 90,
      title: 'Te benned bíztunk',
      originalKey: result.notation.originalKey,
      timeSignature: result.timeSignature,
      notation: result.notation,
      verses: result.verses,
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final stored = await container.read(userSongsProvider.notifier).add(song);

    // Value equality reaches all the way through SongNotation, so this asserts
    // every beat, pitch, duration, tie and syllable round-tripped. It only
    // holds because the notation classes were given value equality.
    final reloaded = container
        .read(userSongRepositoryProvider)
        .getById(stored.id);
    expect(reloaded, stored);
    expect(reloaded!.notation, result.notation);
  });

  test('a notated import keeps the sheet-music view, not the chord fallback',
      () async {
    // The chord-view override is only for songs with nothing to engrave. A
    // MusicXML import HAS notation, so forcing chords on it would throw away
    // the one thing that import path is for.
    final result = importer.importCompressed(realMxl().readAsBytesSync());
    final song = Song(
      number: 90,
      title: 'Te benned bíztunk',
      originalKey: result.notation.originalKey,
      notation: result.notation,
      verses: result.verses,
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final stored = await container.read(userSongsProvider.notifier).add(song);
    expect(
      container.read(settingsRepositoryProvider).getSongViewConfig(stored.id),
      isNull,
      reason: 'no override should be written for a song that has notation',
    );
  });

  test('a malformed file reports a message instead of crashing', () {
    expect(() => importer.importXml('this is not xml'),
        throwsA(isA<MusicXmlImportException>()));
    expect(() => importer.importXml(''),
        throwsA(isA<MusicXmlImportException>()));
  });

  test('the real file has notation but NO lyric verses', () {
    // The bug this pins down: the import screen required verses, so an
    // engraved score whose syllables hang off individual beats rather than
    // <lyric> elements — which is what Audiveris produces — could not be
    // saved at all. Exactly the files the MusicXML path exists for.
    final result = importer.importCompressed(realMxl().readAsBytesSync());

    expect(result.verses, isEmpty, reason: 'no <lyric> elements in this file');
    expect(result.notation.verses.single.measures, isNotEmpty);

    // A song built from it is still perfectly renderable.
    final song = Song(
      number: 90,
      title: 'Te benned bíztunk',
      originalKey: result.notation.originalKey,
      notation: result.notation,
      verses: result.verses,
    );
    expect(song.hasNotation, isTrue);
    expect(song.verses, isEmpty);
  });
}
