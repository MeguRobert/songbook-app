import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/models/app_settings.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/data/repositories/submission_repository.dart';
import 'package:songbook_app/presentation/providers/admin_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';

import 'helpers.dart';

/// The three stops the role ladder added to sharing.
///
/// `share_song_test.dart` covers the entry point and the two stops that shipped
/// with it — signed out, and the confirm. These are the ones that arrived with
/// `app_settings` and the frozen attribution: a closed door, a contributor with
/// no name to be credited as, and guidelines nobody has accepted.
///
/// Every one of them is also enforced in `public.assert_may_submit`, so what is
/// being checked here is not whether the rule holds — pgTAP does that — but
/// whether the user is told which rule they have hit. Before this, all three
/// arrived as one unexplained "could not be sent".
class _MockSubmissions extends Mock implements SubmissionRepository {}

Song userSong() => Song(
      number: 1,
      title: 'Az Úrra bízom életem',
      originalKey: 'G',
      book: 'Saját énekek',
      explicitId: SongId.user('abc'),
      verses: const [
        Verse(number: 1, lines: [LyricLine(text: 'Az Úrra bízom életem')]),
      ],
    );

Future<void> pumpSongView(
  WidgetTester tester, {
  required SubmissionRepository submissions,
  String? displayName = 'Someone',
  bool guidelinesAccepted = true,
  AppSettings settings = const AppSettings(),
}) async {
  final song = userSong();
  await pumpScreen(
    tester,
    SongViewScreen(songId: song.id),
    prefs: const {'settings_view_config': 'false:true'},
    overrides: [
      songByIdProvider
          .overrideWith((ref, id) async => id == song.id ? song : null),
      submissionRepositoryProvider.overrideWithValue(submissions),
      isSignedInProvider.overrideWithValue(true),
      isEmailConfirmedProvider.overrideWithValue(true),
      appSettingsProvider.overrideWith((ref) async => settings),
      myProfileProvider.overrideWith((ref) async => (
            displayName: displayName,
            guidelinesAcceptedAt:
                guidelinesAccepted ? DateTime(2026, 8, 1) : null,
          )),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> tapShare(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Share with the congregation'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(userSong()));

  testWidgets('a closed door is explained, and nothing is sent', (tester) async {
    final submissions = _MockSubmissions();
    await pumpSongView(
      tester,
      submissions: submissions,
      settings: const AppSettings(submissionsOpen: false),
    );
    await tapShare(tester);

    // Reported before anything is asked of the contributor -- that ordering is
    // the whole point of firstUnmetStop, and it is why this assertion also
    // checks the confirm dialog never appeared.
    expect(find.text('Submissions are closed'), findsOneWidget);
    expect(find.text('Share this song?'), findsNothing);
    verifyNever(() => submissions.submit(any()));
  });

  testWidgets('a contributor with no name is asked for one', (tester) async {
    final submissions = _MockSubmissions();
    await pumpSongView(tester, submissions: submissions, displayName: null);
    await tapShare(tester);

    // Without this the song would be credited to an email address, which
    // publishes it to the whole congregation.
    expect(find.text('How should we credit you?'), findsOneWidget);
    verifyNever(() => submissions.submit(any()));
  });

  testWidgets('the guidelines must be read before the first submission',
      (tester) async {
    final submissions = _MockSubmissions();
    await pumpSongView(
      tester,
      submissions: submissions,
      guidelinesAccepted: false,
      settings: const AppSettings(
        guidelines: {'en': 'Only songs actually sung in worship.'},
      ),
    );
    await tapShare(tester);

    expect(find.text('Before you send it'), findsOneWidget);
    expect(find.text('Only songs actually sung in worship.'), findsOneWidget);

    // Agreeing is impossible until the box is ticked. The tick is the entire
    // record that they were shown the rules, so a button that worked without it
    // would make guidelines_accepted_at a lie.
    final agree = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Agree and send'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(agree.onPressed, isNull);
    verifyNever(() => submissions.submit(any()));
  });

  testWidgets('cancelling the guidelines sends nothing', (tester) async {
    final submissions = _MockSubmissions();
    await pumpSongView(
      tester,
      submissions: submissions,
      guidelinesAccepted: false,
      settings: const AppSettings(guidelines: {'en': 'The rules.'}),
    );
    await tapShare(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Share this song?'), findsNothing);
    verifyNever(() => submissions.submit(any()));
  });
}
