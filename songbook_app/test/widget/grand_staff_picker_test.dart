import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_layout.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_painter.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_renderer.dart';

import 'helpers.dart';

/// Reading all four voices at once.
///
/// The voice picker chooses ONE line to engrave in place of the melody, which is
/// what a bass singer wants. A choir director wants the opposite — every part on
/// its own staff, bar lines aligned — and that is a different layout, not a
/// different selection, so it is a further option on the same control.
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

  SheetMusicRenderer renderer(WidgetTester tester) =>
      tester.widget<SheetMusicRenderer>(find.byType(SheetMusicRenderer));

  /// The layout the canvas is actually painting — the only place that proves all
  /// four staves reached the screen rather than merely being computable.
  SheetMusicLayout paintedLayout(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SheetMusicPainter));
    return (paint.painter as SheetMusicPainter).layout;
  }

  Future<void> openControls(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
  }

  /// VOICE sits below CAPO, under the fold of a sheet that opens at 72% of the
  /// screen, and `tester.tap` does not check visibility — an off-screen chip's
  /// centre coordinates land outside the sheet's clip and the hit test quietly
  /// misses.
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
            (ref, id) => id == const SongId.hymnal(42) ? song : null),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a four-part score offers all its voices together', (tester) async {
    await pumpSong(tester, satb());
    await openControls(tester);

    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('a single-voice score offers nothing to combine', (tester) async {
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

    expect(find.text('All'), findsNothing);
  });

  testWidgets('choosing All engraves each voice on its own staff',
      (tester) async {
    await pumpSong(tester, satb());
    expect(paintedLayout(tester).systems, hasLength(1),
        reason: 'opens on the melody alone');

    await openControls(tester);
    await tapVoice(tester, 'All');

    final systems = paintedLayout(tester).systems;
    expect(systems, hasLength(4));
    expect(systems.map((s) => s.label), ['Melody', 'Alto', 'Tenor', 'Bass']);
  });

  testWidgets('the bass staff is engraved in the bass clef', (tester) async {
    await pumpSong(tester, satb());
    await openControls(tester);
    await tapVoice(tester, 'All');

    final systems = paintedLayout(tester).systems;
    expect(systems.first.clef, StaffClef.treble);
    expect(systems.last.clef, StaffClef.bass);
  });

  testWidgets('All hands the renderer the score unprojected', (tester) async {
    // The single-voice path swaps the chosen line INTO `verses`. Doing that here
    // would engrave the bass four times: the grand staff reads `verses` as the
    // top line and `voices` as the rest, so it needs the stored score as it is.
    await pumpSong(tester, satb());
    await openControls(tester);
    await tapVoice(tester, 'All');

    expect(renderer(tester).grandStaff, isTrue);
    expect(renderer(tester).notation.verses.single.measures.single.beats.single
        .pitch, 'C5');
    expect(renderer(tester).notation.voices, hasLength(3));
  });

  testWidgets('picking a single voice again leaves the grand staff',
      (tester) async {
    await pumpSong(tester, satb());
    await openControls(tester);

    await tapVoice(tester, 'All');
    expect(paintedLayout(tester).systems, hasLength(4));

    await tapVoice(tester, 'Bass');
    expect(renderer(tester).grandStaff, isFalse);
    expect(paintedLayout(tester).systems, hasLength(1));
    expect(
        renderer(tester).notation.verses.single.measures.single.beats.single
            .pitch,
        'C3');
  });

  test('opening another song does not carry the grand staff over', () async {
    // Same reasoning as the transpose amount and the single-voice selection:
    // reading a four-part score is something done for one hymn, and the next song
    // should open the way every other song does. Driven through the notifier
    // rather than the screen because that is where the reset lives — openSong
    // builds a fresh state rather than clearing fields one by one.
    final container = await makeAppContainer();
    final notifier = container.read(songViewProvider.notifier);

    notifier.openSong(const SongId.hymnal(42));
    notifier.setVoice(SongNotation.allVoices);
    expect(container.read(songViewProvider)!.voiceIndex,
        SongNotation.allVoices);

    notifier.openSong(const SongId.hymnal(43));
    expect(container.read(songViewProvider)!.voiceIndex, 0);
  });
}
