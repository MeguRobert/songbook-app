import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:songbook_app/data/models/notation.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/notation_editor/notation_editor_screen.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';
import 'package:songbook_app/presentation/widgets/sheet_music/sheet_music_renderer.dart';
import 'package:songbook_app/router/app_router.dart';

import 'helpers.dart';

/// B3a — the notation-correction editor.
///
/// This is where OMR output gets fixed, so the list is the product: a flat row
/// per beat with its pitch, duration and syllable, which is closer to editing a
/// table than to driving a score editor. Deliberately NOT a blank-page score
/// writer — no note entry from scratch, no beaming, no voices.

/// Two 4/4 measures, the second deliberately a beat short so the per-measure
/// arithmetic has something to complain about.
SongNotation shortSecondMeasure() => const SongNotation(
      originalKey: 'C',
      timeSignature: '4/4',
      verses: [
        NotatedVerse(number: 1, measures: [
          NotatedMeasure(beats: [
            NotatedBeat(
                pitch: 'C4', duration: NoteDuration.quarter, syllable: 'Az'),
            NotatedBeat(
                pitch: 'D4', duration: NoteDuration.quarter, syllable: 'Úr-'),
            NotatedBeat(
                pitch: 'E4', duration: NoteDuration.half, syllable: 'ra'),
          ]),
          NotatedMeasure(beats: [
            NotatedBeat(
                pitch: 'F4', duration: NoteDuration.half, syllable: 'bí-'),
            NotatedBeat(
                pitch: 'G4', duration: NoteDuration.quarter, syllable: 'zom'),
          ]),
        ]),
      ],
    );

Song notatedUserSong({SongNotation? notation}) => Song(
      number: 1,
      title: 'Az Úrra bízom életem',
      originalKey: 'C',
      timeSignature: '4/4',
      explicitId: const SongId.user('abc'),
      notation: notation ?? shortSecondMeasure(),
      verses: const [Verse(number: 1, plainText: 'Az Úrra bízom életem')],
    );

/// Mounts the app at the notation editor for [song], over real storage.
Future<ProviderContainer> pumpEditor(WidgetTester tester, Song song) async {
  final container = await makeAppContainer();
  await container.read(userSongsProvider.notifier).add(song);

  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('HOME'))),
    GoRoute(
      path: AppRoutes.song,
      builder: (_, s) =>
          SongViewScreen(songId: SongId.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: AppRoutes.editNotation,
      builder: (_, s) => NotationEditorScreen(
        songId: SongId.parse(s.pathParameters['id']!),
      ),
    ),
  ]);
  addTearDown(router.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: localizedRouterApp(router),
  ));
  await tester.pumpAndSettle();
  router.push(AppRoutes.editNotationPath(song.id));
  await tester.pumpAndSettle();
  return container;
}

/// Opens the field sheet for the beat whose pitch is [pitch].
Future<void> openBeat(WidgetTester tester, String pitch) async {
  await tester.tap(find.text(pitch));
  await tester.pumpAndSettle();
}

/// Picks [value] from the dropdown keyed [key].
Future<void> selectFromDropdown(
  WidgetTester tester,
  String key,
  String value,
) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

void main() {
  group('entry point', () {
    Future<void> pumpSongViewFor(WidgetTester tester, Song song) async {
      await pumpScreen(
        tester,
        SongViewScreen(songId: song.id),
        prefs: const {'settings_view_config': 'false:true'},
        overrides: [
          songByIdProvider
              .overrideWith((ref, id) async => id == song.id ? song : null),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
    }

    testWidgets('offered for a user song that has notation', (tester) async {
      await pumpSongViewFor(tester, notatedUserSong());
      expect(find.text('Correct the notation'), findsOneWidget);
    });

    testWidgets('not offered for a user song with no notation',
        (tester) async {
      // A pasted chord sheet never produces notation, and there is nothing to
      // correct on a blank staff — that would be the score writer this is not.
      await pumpSongViewFor(
        tester,
        Song(
          number: 1,
          title: 'Pasted',
          originalKey: 'G',
          explicitId: const SongId.user('abc'),
          verses: const [Verse(number: 1, plainText: 'x')],
        ),
      );
      expect(find.text('Correct the notation'), findsNothing);
    });

    testWidgets('not offered for a bundled hymn, notation or not',
        (tester) async {
      await pumpSongViewFor(
        tester,
        Song(
          number: 151,
          title: 'Bundled',
          originalKey: 'C',
          notation: shortSecondMeasure(),
          verses: const [Verse(number: 1, plainText: 'x')],
        ),
      );
      expect(find.text('Correct the notation'), findsNothing);
    });
  });

  group('the beat list', () {
    testWidgets('lists every beat with its pitch, duration and syllable',
        (tester) async {
      await pumpEditor(tester, notatedUserSong());

      for (final pitch in ['C4', 'D4', 'E4', 'F4', 'G4']) {
        expect(find.text(pitch), findsOneWidget, reason: 'beat $pitch');
      }
      expect(find.text('Az'), findsOneWidget);
      expect(find.text('zom'), findsOneWidget);
      expect(find.textContaining('quarter'), findsWidgets);
    });

    testWidgets('groups beats by measure and shows what each one adds up to',
        (tester) async {
      await pumpEditor(tester, notatedUserSong());

      expect(find.text('Measure 1'), findsOneWidget);
      expect(find.text('Measure 2'), findsOneWidget);
      // 4/4: the first measure is complete, the second is a beat short. Showing
      // the arithmetic is the point — a dropped or invented note is exactly what
      // makes a bar stop adding up, and it is invisible on the staff.
      expect(find.text('4 / 4 beats'), findsOneWidget);
      expect(find.text('3 / 4 beats'), findsOneWidget);
    });

    testWidgets('labels a declared upbeat and does not flag it as short',
        (tester) async {
      // The bar is 1 beat of 4, which for any other measure is the editor's
      // loudest signal that the transcription lost a note. An anacrusis is short
      // on purpose, and flagging it would train the warning away on exactly the
      // hymns that open on one.
      await pumpEditor(
        tester,
        notatedUserSong(
          notation: const SongNotation(
            originalKey: 'C',
            timeSignature: '4/4',
            verses: [
              NotatedVerse(number: 1, measures: [
                NotatedMeasure(
                  isPickup: true,
                  beats: [
                    NotatedBeat(
                        pitch: 'G3',
                        duration: NoteDuration.quarter,
                        syllable: 'Te'),
                  ],
                ),
                NotatedMeasure(beats: [
                  NotatedBeat(pitch: 'C4', duration: NoteDuration.whole),
                ]),
              ]),
            ],
          ),
        ),
      );

      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('1 / 4 beats'), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      // The first FULL bar is Measure 1, the way a score numbers it.
      expect(find.text('Measure 1'), findsOneWidget);
      expect(find.text('Measure 2'), findsNothing);
    });

    testWidgets('still flags a short bar that was never declared a pickup',
        (tester) async {
      await pumpEditor(tester, notatedUserSong());

      expect(find.text('Pickup'), findsNothing);
      expect(find.text('3 / 4 beats'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('says so when stored pickup beats are not being rendered',
        (tester) async {
      // SongNotation.pickup is read by nothing in lib/ — not the renderer, not
      // the layout engine. Silently omitting those beats from a screen whose
      // whole job is "is this right?" would be the worst of both.
      await pumpEditor(
        tester,
        notatedUserSong(
          notation: const SongNotation(
            originalKey: 'C',
            timeSignature: '4/4',
            verses: [
              NotatedVerse(number: 1, measures: [
                NotatedMeasure(beats: [
                  NotatedBeat(pitch: 'C4', duration: NoteDuration.whole),
                ]),
              ]),
            ],
            pickup: [NotatedBeat(pitch: 'G3', duration: NoteDuration.quarter)],
          ),
        ),
      );

      expect(find.textContaining('pickup'), findsOneWidget);
    });
  });

  group('editing a beat', () {
    testWidgets('opens the fields seeded with that beat', (tester) async {
      await pumpEditor(tester, notatedUserSong());
      await openBeat(tester, 'D4');

      expect(find.byKey(const Key('beat-syllable')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('beat-syllable')))
            .controller!
            .text,
        'Úr-',
      );
    });

    testWidgets('a corrected pitch shows in the list', (tester) async {
      await pumpEditor(tester, notatedUserSong());
      await openBeat(tester, 'D4');

      await selectFromDropdown(tester, 'beat-note', 'F');
      // Named, not the ♯/♭/♮ glyphs. Driving the release build in a browser,
      // ♮ rendered as an unreadable mark below the baseline in Roboto, so the
      // selected accidental could not be told apart from the other two — on the
      // one control in this screen that most needs to be unambiguous.
      await selectFromDropdown(tester, 'beat-accidental', 'sharp');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('F#4'), findsOneWidget);
      expect(find.text('D4'), findsNothing);
    });

    testWidgets('names the accidentals rather than relying on a glyph',
        (tester) async {
      await pumpEditor(tester, notatedUserSong());
      await openBeat(tester, 'D4');
      await tester.tap(find.byKey(const Key('beat-accidental')));
      await tester.pumpAndSettle();

      expect(find.text('natural'), findsWidgets);
      expect(find.text('sharp'), findsWidgets);
      expect(find.text('flat'), findsWidgets);
    });

    testWidgets('a corrected duration re-does the measure arithmetic',
        (tester) async {
      await pumpEditor(tester, notatedUserSong());
      // Measure 2 is a beat short: F4 was read as a half note but is a whole.
      await openBeat(tester, 'F4');
      await selectFromDropdown(tester, 'beat-duration', 'whole');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('5 / 4 beats'), findsOneWidget);
    });

    testWidgets('a rest needs no pitch', (tester) async {
      await pumpEditor(tester, notatedUserSong());
      await openBeat(tester, 'D4');

      await tester.tap(find.byKey(const Key('beat-rest')));
      await tester.pumpAndSettle();
      // The pitch controls are meaningless for a rest and go away.
      expect(find.byKey(const Key('beat-note')), findsNothing);

      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('rest'), findsOneWidget);
      expect(find.text('D4'), findsNothing);
    });

    testWidgets('the engraved preview is handed the corrected notation',
        (tester) async {
      // The reason the score sits above the list at all: a correction is judged
      // against the paper it came from. The renderer relays because SongNotation
      // carries value equality over all its fields — hand it the same object and
      // its cached layout stands.
      await pumpEditor(tester, notatedUserSong());
      expect(
        tester
            .widget<SheetMusicRenderer>(find.byType(SheetMusicRenderer))
            .notation
            .verses
            .first
            .measures
            .first
            .beats[1]
            .pitch,
        'D4',
      );

      await openBeat(tester, 'D4');
      await selectFromDropdown(tester, 'beat-note', 'F');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SheetMusicRenderer>(find.byType(SheetMusicRenderer))
            .notation
            .verses
            .first
            .measures
            .first
            .beats[1]
            .pitch,
        'F4',
      );
    });

    testWidgets('nothing is written until Save', (tester) async {
      final container = await pumpEditor(tester, notatedUserSong());

      await openBeat(tester, 'D4');
      await selectFromDropdown(tester, 'beat-note', 'F');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Applied to the draft on screen, not to storage: a correction pass is
      // one edit at a time and has to be abandonable.
      final stored = container.read(userSongsProvider).single;
      expect(stored.notation!.verses.first.measures.first.beats[1].pitch, 'D4');
    });

    testWidgets('Save writes the corrected notation and returns to the song',
        (tester) async {
      final container = await pumpEditor(tester, notatedUserSong());

      await openBeat(tester, 'D4');
      await selectFromDropdown(tester, 'beat-note', 'F');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final stored = container.read(userSongsProvider).single;
      expect(stored.notation!.verses.first.measures.first.beats[1].pitch, 'F4');
      // The song keeps its identity and its words; only the notation moved.
      expect(stored.id, const SongId.user('abc'));
      expect(stored.title, 'Az Úrra bízom életem');
      expect(stored.verses, hasLength(1));
      expect(find.byType(NotationEditorScreen), findsNothing);
    });
  });

  group('adding and removing beats', () {
    testWidgets('insert after copies the beat next to it', (tester) async {
      // The note OMR dropped sits beside one it read correctly, so this is one
      // corrected field instead of four entered.
      final container = await pumpEditor(tester, notatedUserSong());

      await tester.tap(find.byKey(const Key('beat-menu-0-1-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insert after'));
      await tester.pumpAndSettle();

      expect(find.text('F4'), findsNWidgets(2));
      // The measure was 3 beats of 4; the copy makes it 5, which the readout
      // now says out loud.
      expect(find.text('5 / 4 beats'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
          container.read(userSongsProvider).single.notation!.verses.first
              .measures[1].beats,
          hasLength(3));
    });

    testWidgets('delete removes just that beat', (tester) async {
      final container = await pumpEditor(tester, notatedUserSong());

      await tester.tap(find.byKey(const Key('beat-menu-0-0-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('D4'), findsNothing);
      expect(find.text('C4'), findsOneWidget);
      expect(find.text('3 / 4 beats'), findsNWidgets(2)); // both short now

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
          container.read(userSongsProvider).single.notation!.verses.first
              .measures.first.beats,
          hasLength(2));
    });
  });

  group('leaving with unsaved corrections', () {
    testWidgets('asks before discarding them', (tester) async {
      final container = await pumpEditor(tester, notatedUserSong());

      await openBeat(tester, 'D4');
      await selectFromDropdown(tester, 'beat-note', 'F');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(NotationEditorScreen), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(NotationEditorScreen), findsNothing);
      expect(
          container.read(userSongsProvider).single.notation!.verses.first
              .measures.first.beats[1].pitch,
          'D4');
    });

    testWidgets('leaves without asking when nothing was changed',
        (tester) async {
      await pumpEditor(tester, notatedUserSong());

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard'), findsNothing);
      expect(find.byType(NotationEditorScreen), findsNothing);
    });
  });
}
