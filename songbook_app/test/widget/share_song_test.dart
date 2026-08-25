import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/submission.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/data/models/app_settings.dart';
import 'package:songbook_app/data/repositories/submission_repository.dart';
import 'package:songbook_app/presentation/providers/admin_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';

import 'helpers.dart';

/// Sending a song the user added to the shared catalogue.
///
/// `SubmissionRepository.submit` shipped tested and with no caller anywhere in
/// the app: every song ever imported stayed on the phone that imported it, so
/// the moderation queue, the roles and the RLS behind it had nothing to act on.
/// These pin the entry point and the stops in front of it.
///
/// The gate grew from two stops to five when the role ladder landed, so the
/// harness below has to present a contributor who is ALREADY past the other
/// three -- confirmed address, a name to be credited as, guidelines accepted.
/// Each of those is a database rule as well as a prompt, so a test that left
/// them unmet would be testing the gate, not the sharing, and
/// `test/unit/domain/services/publish_gate_test.dart` already tests the gate.

class _MockSubmissions extends Mock implements SubmissionRepository {}

Song userSong({
  String ref = 'abc',
  String title = 'Az Úrra bízom életem',
  int number = 1,
}) =>
    Song(
      number: number,
      title: title,
      originalKey: 'G',
      book: 'Saját énekek',
      explicitId: SongId.user(ref),
      verses: const [
        Verse(number: 1, lines: [LyricLine(text: 'Az Úrra bízom életem')]),
      ],
    );

Song bundledSong() => Song(
      number: 42,
      title: 'Mint a szép híves patakra',
      originalKey: 'G',
      verses: const [
        Verse(number: 1, lines: [LyricLine(text: 'Mint a szép híves patakra')]),
      ],
    );

Submission pendingSubmission(Song song) => Submission(
      id: 'row-1',
      status: SubmissionStatus.pending,
      song: song,
    );

Future<void> pumpSongView(
  WidgetTester tester,
  Song song, {
  SubmissionRepository? submissions,
  bool signedIn = true,
  bool emailConfirmed = true,
  String? displayName = 'Someone',
  bool guidelinesAccepted = true,
  AppSettings settings = const AppSettings(),
}) async {
  await pumpScreen(
    tester,
    SongViewScreen(songId: song.id),
    // No notation -> ChordView, so the test needs no sheet-music assets.
    prefs: const {'settings_view_config': 'false:true'},
    overrides: [
      songByIdProvider
          .overrideWith((ref, id) async => id == song.id ? song : null),
      submissionRepositoryProvider.overrideWithValue(submissions),
      isSignedInProvider.overrideWithValue(signedIn),
      isEmailConfirmedProvider.overrideWithValue(emailConfirmed),
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

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(userSong());
  });

  group('the share action is offered', () {
    testWidgets('for a song the user added, when there is a catalogue',
        (tester) async {
      final submissions = _MockSubmissions();
      await pumpSongView(tester, userSong(), submissions: submissions);
      await openMenu(tester);

      expect(find.text('Share with the congregation'), findsOneWidget);
    });

    testWidgets('but not with no backend behind the build', (tester) async {
      // A supported configuration, not a broken one: the bundled hymnal works
      // offline and signed out. Offering to send a song nowhere would be a
      // control that cannot work.
      await pumpSongView(tester, userSong(), submissions: null);
      await openMenu(tester);

      expect(find.text('Share with the congregation'), findsNothing);
    });

    testWidgets('and not for a bundled hymnal song', (tester) async {
      // It is already in the catalogue. Submitting it would queue a duplicate
      // of a song the moderators published themselves.
      final submissions = _MockSubmissions();
      await pumpSongView(tester, bundledSong(), submissions: submissions);
      await openMenu(tester);

      expect(find.text('Share with the congregation'), findsNothing);
    });
  });

  group('signed out', () {
    testWidgets('asks for an account and sends nothing when refused',
        (tester) async {
      final submissions = _MockSubmissions();
      await pumpSongView(tester, userSong(),
          submissions: submissions, signedIn: false);
      await openMenu(tester);
      await tester.tap(find.text('Share with the congregation'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to share'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => submissions.submit(any()));
    });
  });

  group('signed in', () {
    testWidgets('asks first, and a cancel sends nothing', (tester) async {
      final submissions = _MockSubmissions();
      await pumpSongView(tester, userSong(), submissions: submissions);
      await openMenu(tester);
      await tester.tap(find.text('Share with the congregation'));
      await tester.pumpAndSettle();

      expect(find.text('Share this song?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => submissions.submit(any()));
    });

    testWidgets('confirming sends the song and says so', (tester) async {
      final song = userSong();
      final submissions = _MockSubmissions();
      when(() => submissions.mySubmissions()).thenAnswer((_) async => []);
      when(() => submissions.submit(any())).thenAnswer((_) async {});

      await pumpSongView(tester, song, submissions: submissions);
      await openMenu(tester);
      await tester.tap(find.text('Share with the congregation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      final sent = verify(() => submissions.submit(captureAny())).captured;
      expect(sent, hasLength(1));
      expect((sent.single as Song).title, song.title);
      expect(find.text('Sent for review.'), findsOneWidget);
    });

    testWidgets('a song already in the queue is not sent twice',
        (tester) async {
      final song = userSong();
      final submissions = _MockSubmissions();
      when(() => submissions.mySubmissions())
          .thenAnswer((_) async => [pendingSubmission(song)]);

      await pumpSongView(tester, song, submissions: submissions);
      await openMenu(tester);
      await tester.tap(find.text('Share with the congregation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      verifyNever(() => submissions.submit(any()));
      expect(find.textContaining('already sent'), findsOneWidget);
    });

    testWidgets('a refusal from the server is reported, not swallowed',
        (tester) async {
      // The server-side gate can refuse for reasons this build has no
      // vocabulary for yet, so the message is deliberately one message — but it
      // has to arrive.
      final submissions = _MockSubmissions();
      when(() => submissions.mySubmissions()).thenAnswer((_) async => []);
      when(() => submissions.submit(any())).thenThrow(StateError('refused'));

      await pumpSongView(tester, userSong(), submissions: submissions);
      await openMenu(tester);
      await tester.tap(find.text('Share with the congregation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be sent'), findsOneWidget);
    });
  });
}
