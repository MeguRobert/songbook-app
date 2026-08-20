import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/l10n/app_localizations.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music.dart';

/// What the renderer does with notation a machine produced rather than a person.
///
/// A page read by optical music recognition is not the tidy notation the
/// renderer was written against. Audiveris returns measures that are entirely
/// rests, measures with nothing in them at all, and — on a page of two voices —
/// a part whose measure list can come back empty. On a real photographed page
/// (Hozsánna, 151, 29 bars) the result was a **solid grey rectangle** where the
/// staff should be, both in the import preview and in the saved song.
///
/// Grey is the tell. In a release build Flutter's default `ErrorWidget` is a
/// plain grey box, so any exception thrown while building this subtree looks
/// exactly like that, with nothing in the console to say so. In a test the same
/// exception is reported, which is what these use.
Song songWith(SongNotation notation) => Song(
      number: 151,
      title: 'Hozsánna',
      originalKey: 'E',
      verses: const [],
      notation: notation,
    );

SongNotation notationOf(List<NotatedVerse> verses) => SongNotation(
      originalKey: 'E',
      // What the importer defaults to when Audiveris reports none, which it
      // never does.
      timeSignature: '4/4',
      verses: verses,
    );

NotatedMeasure barOf(int notes) => NotatedMeasure(
      beats: [
        for (var i = 0; i < notes; i++)
          const NotatedBeat(pitch: 'E4', duration: NoteDuration.quarter),
      ],
    );

Future<List<Object>> renderErrors(
    WidgetTester tester, SongNotation notation) async {
  final errors = <Object>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exception);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SizedBox(
          height: 340,
          child: SheetMusicView(
            song: songWith(notation),
            notation: notation,
            transpose: 0,
          ),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 100));

  FlutterError.onError = previous;
  return errors;
}

void main() {
  testWidgets('ordinary notation renders, so the harness is not vacuous',
      (tester) async {
    final errors = await renderErrors(
      tester,
      notationOf([
        NotatedVerse(number: 1, measures: [barOf(4), barOf(4), barOf(4)]),
      ]),
    );
    expect(errors, isEmpty);
  });

  testWidgets('a verse with no measures at all does not take the staff down',
      (tester) async {
    // Audiveris on a two-voice page returns a part whose measures did not
    // survive the melody split. Nothing about that should stop the rest of the
    // page being drawn.
    final errors = await renderErrors(
      tester,
      notationOf([
        NotatedVerse(number: 1, measures: [barOf(4)]),
        const NotatedVerse(number: 2, measures: []),
      ]),
    );
    expect(errors, isEmpty,
        reason: 'an empty verse must not throw: ${errors.join('; ')}');
  });

  testWidgets('notation with no measures anywhere still renders something',
      (tester) async {
    final errors = await renderErrors(tester, notationOf([
      const NotatedVerse(number: 1, measures: []),
    ]));
    expect(errors, isEmpty,
        reason: 'no measures must not throw: ${errors.join('; ')}');
  });

  testWidgets('a measure with no beats in it does not take the staff down',
      (tester) async {
    // A bar of whole rests, or a bar Audiveris found the lines of but nothing
    // inside. Song 151 has several.
    final errors = await renderErrors(
      tester,
      notationOf([
        NotatedVerse(number: 1, measures: [barOf(4), barOf(0), barOf(4)]),
      ]),
    );
    expect(errors, isEmpty,
        reason: 'an empty measure must not throw: ${errors.join('; ')}');
  });

  testWidgets('every measure empty — the shape a badly read page arrives in',
      (tester) async {
    final errors = await renderErrors(
      tester,
      notationOf([
        NotatedVerse(number: 1, measures: [barOf(0), barOf(0)]),
      ]),
    );
    expect(errors, isEmpty,
        reason: 'all-empty measures must not throw: ${errors.join('; ')}');
  });
}
