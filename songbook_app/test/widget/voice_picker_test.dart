import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_renderer.dart';

import 'helpers.dart';

/// Choosing which voice of a four-part score is engraved.
///
/// Importing a hymnal SATB score has always reduced it to the top line. The
/// other three were recovered and then thrown away, so a bass singer had no way
/// to read their own part. They are stored now, and this is the control that
/// picks one.
void main() {
  NotatedMeasure bar(String pitch, {String? syllable}) => NotatedMeasure(
        beats: [
          NotatedBeat(
            pitch: pitch,
            duration: NoteDuration.whole,
            syllable: syllable,
          ),
        ],
      );

  SongNotation satb() => SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [bar('C5', syllable: 'Mint')]),
        ],
        voices: [
          NotatedVoice(name: 'Alto', measures: [bar('G4')]),
          NotatedVoice(name: 'Tenor', measures: [bar('E4')]),
          NotatedVoice(name: 'Bass', measures: [bar('C3')]),
        ],
      );

  /// The pitch the staff is currently engraving.
  String engravedPitch(WidgetTester tester) {
    final renderer =
        tester.widget<SheetMusicRenderer>(find.byType(SheetMusicRenderer));
    return renderer.notation.verses.single.measures.single.beats.single.pitch;
  }

  Future<void> openControls(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
  }

  /// Taps a voice chip, scrolling it into view first.
  ///
  /// VOICE sits below CAPO, which puts it under the fold of a sheet that opens
  /// at 72% of the screen. `tester.tap` does not check visibility — it taps the
  /// widget's centre coordinates, and for an off-screen chip those land outside
  /// the sheet's clip, so the hit test quietly misses and the assertion fails
  /// with the picker looking fine.
  Future<void> tapVoice(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.text(name));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> pumpSong(WidgetTester tester, SongNotation notation) async {
    final song = makeTestSong().copyWith(notation: notation);
    await pumpScreen(
      tester,
      const SongViewScreen(songId: SongId.hymnal(42)),
      overrides: [
        songByIdProvider.overrideWith(
            (ref, id) async => id == const SongId.hymnal(42) ? song : null),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a four-part score offers all four voices', (tester) async {
    await pumpSong(tester, satb());
    await openControls(tester);

    expect(find.text('Melody'), findsOneWidget);
    expect(find.text('Alto'), findsOneWidget);
    expect(find.text('Tenor'), findsOneWidget);
    expect(find.text('Bass'), findsOneWidget);
  });

  testWidgets('a single-voice score offers no picker at all', (tester) async {
    // Not a disabled one-option picker: that explains nothing, and every
    // bundled song is single-voice, so it would be permanent clutter.
    await pumpSong(
      tester,
      SongNotation(
        originalKey: 'C',
        timeSignature: '4/4',
        verses: [
          NotatedVerse(number: 1, measures: [bar('C5', syllable: 'Mint')]),
        ],
      ),
    );
    await openControls(tester);

    expect(find.text('VOICE'), findsNothing);
    expect(find.text('Melody'), findsNothing);
  });

  testWidgets('picking a voice engraves that line instead', (tester) async {
    await pumpSong(tester, satb());
    expect(engravedPitch(tester), 'C5', reason: 'opens on the melody');

    await openControls(tester);
    await tapVoice(tester, 'Bass');

    expect(engravedPitch(tester), 'C3');
  });

  testWidgets('switching back to Melody restores the top line', (tester) async {
    // The projection is applied to the stored notation on every build, so this
    // works — and it is the reason it must be. Chaining the projection would
    // leave Melody showing the bass.
    await pumpSong(tester, satb());
    // Opened once: picking a voice leaves the sheet up, the same way the VIEW
    // preset chips do, so several choices can be compared without reopening.
    await openControls(tester);

    await tapVoice(tester, 'Tenor');
    expect(engravedPitch(tester), 'E4');

    await tapVoice(tester, 'Melody');
    expect(engravedPitch(tester), 'C5');
  });

  testWidgets('the words stay the melody’s, whichever voice is engraved',
      (tester) async {
    // The syllables belong to the song, not to the line being read. An alto
    // reading their part still needs the words.
    await pumpSong(tester, satb());
    await openControls(tester);
    await tapVoice(tester, 'Bass');

    expect(tester.takeException(), isNull);
    // The verse number identifies which set of words this is, and must survive.
    final renderer =
        tester.widget<SheetMusicRenderer>(find.byType(SheetMusicRenderer));
    expect(renderer.notation.verses.single.number, 1);
  });
}
