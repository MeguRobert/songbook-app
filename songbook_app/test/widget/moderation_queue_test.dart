import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/models/lyric_line.dart';
import 'package:songbook_app/data/models/song.dart';
import 'package:songbook_app/data/models/song_id.dart';
import 'package:songbook_app/data/models/submission.dart';
import 'package:songbook_app/data/models/verse.dart';
import 'package:songbook_app/data/repositories/submission_repository.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/moderation/moderation_queue_screen.dart';

import 'helpers.dart';

/// The screen where a decision is made about somebody else's song.
///
/// Everything here is re-decided server-side — RLS and the status trigger own
/// what is *allowed* — so these tests are not about permission. They are about
/// the two ways this screen can mislead the person holding the decision:
///
/// 1. **Showing the wrong facts.** A moderator judging a submission needs to see
///    whose it is at the moment of deciding, and needs "submitted by Anna" to be
///    distinguishable from "submitted by Anna, who has since left" — the account
///    is gone, so there is nobody to ask about it.
/// 2. **Looking empty when it is not.** Loading and failure both draw *nothing
///    but* their own state here, so a queue that renders blank after a failed
///    fetch reads as "nothing is waiting": the moderator closes the tab and the
///    contributors go on waiting.
///
/// The rejection reason gets its own cluster because it is the only field on
/// this screen a contributor ever reads back. A blank one is refused by a
/// database check too, but the dialog has to refuse it first or the moderator
/// gets a Postgres error instead of a sentence.
class _MockSubmissions extends Mock implements SubmissionRepository {}

Submission pendingSubmission({
  String id = 's1',
  String title = 'Az Úrra bízom életem',
  int number = 1,
  String? submittedByName = 'Anna',
  bool ownerGone = false,
}) =>
    Submission(
      id: id,
      status: SubmissionStatus.pending,
      submittedByName: submittedByName,
      ownerGone: ownerGone,
      submittedAt: DateTime(2026, 8, 1),
      song: Song(
        number: number,
        title: title,
        originalKey: 'G',
        book: 'Saját énekek',
        explicitId: SongId.user(id),
        verses: const [
          Verse(number: 1, lines: [LyricLine(text: 'Az Úrra bízom életem')]),
        ],
      ),
    );

/// Mounts the queue over a stubbed repository, driving the real
/// [moderationQueueProvider] rather than overriding it — the provider's own
/// "no backend means empty, not broken" branch is part of the seam under test.
///
/// [settle] is off for the loading case: the spinner animates forever, so
/// `pumpAndSettle` would time out instead of asserting anything.
Future<SubmissionRepository> pumpQueue(
  WidgetTester tester, {
  List<Submission> queue = const [],
  Future<List<Submission>> Function()? fetch,
  bool settle = true,
}) async {
  final repository = _MockSubmissions();
  when(() => repository.pendingQueue()).thenAnswer(
    (_) => fetch == null ? Future.value(queue) : fetch(),
  );
  when(() => repository.approve(any())).thenAnswer((_) async {});
  when(() => repository.reject(any(), any())).thenAnswer((_) async {});

  await pumpScreen(
    tester,
    const ModerationQueueScreen(),
    overrides: [submissionRepositoryProvider.overrideWithValue(repository)],
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return repository;
}

Finder rejectButton() => find.widgetWithText(TextButton, 'Turn down');
Finder confirmReject() => find.widgetWithText(FilledButton, 'Turn down');
Finder approveButton() => find.widgetWithText(FilledButton, 'Approve');

Future<void> openReject(WidgetTester tester) async {
  await tester.tap(rejectButton());
  await tester.pumpAndSettle();
}

void main() {
  group('what the queue shows', () {
    testWidgets('a row carries the song and who submitted it', (tester) async {
      await pumpQueue(tester, queue: [
        pendingSubmission(title: 'Az Úrra bízom életem', number: 1),
        pendingSubmission(
          id: 's2',
          title: 'Mint a szép híves patakra',
          number: 42,
          submittedByName: 'Béla',
        ),
      ]);

      expect(find.text('Az Úrra bízom életem'), findsOneWidget);
      expect(find.text('Mint a szép híves patakra'), findsOneWidget);
      // Attribution shares one Text with the number and book, so these are
      // substring matches on purpose.
      expect(find.textContaining('Submitted by Anna'), findsOneWidget);
      expect(find.textContaining('Submitted by Béla'), findsOneWidget);
    });

    testWidgets('a submission from a deleted account says the person has left',
        (tester) async {
      await pumpQueue(tester, queue: [
        pendingSubmission(submittedByName: 'Anna', ownerGone: true),
      ]);

      // The frozen name outlives the account, and that difference has to reach
      // the moderator: there is nobody left to ask about this song.
      expect(
        find.textContaining('Submitted by Anna, who has since left'),
        findsOneWidget,
      );
    });

    testWidgets('a live account is not described as a former member',
        (tester) async {
      await pumpQueue(tester, queue: [
        pendingSubmission(submittedByName: 'Anna'),
      ]);

      expect(find.textContaining('who has since left'), findsNothing);
      expect(find.textContaining('Submitted by Anna'), findsOneWidget);
    });

    testWidgets('a submission with no recorded name claims no attribution',
        (tester) async {
      await pumpQueue(tester,
          queue: [pendingSubmission(submittedByName: null)]);

      expect(find.text('Az Úrra bízom életem'), findsOneWidget);
      expect(find.textContaining('Submitted by'), findsNothing);
    });

    testWidgets('an empty queue says so rather than drawing a blank list',
        (tester) async {
      await pumpQueue(tester);

      expect(find.text('Nothing is waiting.'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('a queue still loading shows a spinner, not the empty state',
        (tester) async {
      await pumpQueue(
        tester,
        fetch: () => Completer<List<Submission>>().future,
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The dangerous confusion: "not loaded yet" must never read as "nothing
      // is waiting", or a moderator walks away from a full queue.
      expect(find.text('Nothing is waiting.'), findsNothing);
    });

    testWidgets('a queue that fails to load says so rather than looking empty',
        (tester) async {
      await pumpQueue(tester, fetch: () => Future.error(Exception('offline')));

      expect(
        find.text('Could not reach the server. Check your connection.'),
        findsOneWidget,
      );
      expect(find.text('Nothing is waiting.'), findsNothing);
    });
  });

  group('approving', () {
    testWidgets('calls through with the submission id', (tester) async {
      final repository =
          await pumpQueue(tester, queue: [pendingSubmission(id: 'sub-7')]);

      await tester.tap(approveButton());
      await tester.pumpAndSettle();

      verify(() => repository.approve('sub-7')).called(1);
    });

    testWidgets('re-reads the queue from the server rather than trusting itself',
        (tester) async {
      final repository = await pumpQueue(tester, queue: [pendingSubmission()]);

      await tester.tap(approveButton());
      await tester.pumpAndSettle();

      // Another moderator may have acted meanwhile, so the server is the
      // authority on what is still pending — not a locally spliced list.
      verify(() => repository.pendingQueue()).called(greaterThanOrEqualTo(2));
    });

    testWidgets('a failure is reported instead of passing for a decision',
        (tester) async {
      final repository = await pumpQueue(tester, queue: [pendingSubmission()]);
      when(() => repository.approve(any())).thenThrow(Exception('offline'));

      await tester.tap(approveButton());
      await tester.pumpAndSettle();

      expect(
        find.text('Could not reach the server. Check your connection.'),
        findsOneWidget,
      );
    });
  });

  group('turning down', () {
    testWidgets('an empty reason never reaches the server', (tester) async {
      final repository = await pumpQueue(tester, queue: [pendingSubmission()]);
      await openReject(tester);

      await tester.tap(confirmReject());
      await tester.pumpAndSettle();

      expect(find.text('Give a reason so they can fix it.'), findsOneWidget);
      // Still open, so the moderator can add a reason rather than start over.
      expect(find.byType(AlertDialog), findsOneWidget);
      verifyNever(() => repository.reject(any(), any()));
    });

    testWidgets('whitespace is not a reason', (tester) async {
      final repository = await pumpQueue(tester, queue: [pendingSubmission()]);
      await openReject(tester);

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(confirmReject());
      await tester.pumpAndSettle();

      expect(find.text('Give a reason so they can fix it.'), findsOneWidget);
      verifyNever(() => repository.reject(any(), any()));
    });

    testWidgets('the reason typed is the reason sent', (tester) async {
      final repository =
          await pumpQueue(tester, queue: [pendingSubmission(id: 'sub-7')]);
      await openReject(tester);

      await tester.enterText(
          find.byType(TextFormField), 'Only two of the four verses.');
      await tester.tap(confirmReject());
      await tester.pumpAndSettle();

      // This string is the only thing the contributor ever reads back, so it
      // has to arrive intact rather than as a flag.
      verify(() => repository.reject('sub-7', 'Only two of the four verses.'))
          .called(1);
    });

    testWidgets('cancelling decides nothing', (tester) async {
      final repository = await pumpQueue(tester, queue: [pendingSubmission()]);
      await openReject(tester);

      await tester.enterText(find.byType(TextFormField), 'Changed my mind');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.reject(any(), any()));
      verifyNever(() => repository.approve(any()));
    });

    /// The dismissal itself, which used to be the thing this screen got wrong.
    ///
    /// `_promptReject` built its `TextEditingController` inline and disposed it
    /// on the line after `await showDialog(...)` returned. The route was popped
    /// but still transitioning out, so the next frame rebuilt the
    /// `TextFormField`, `EditableText` re-subscribed, and the framework threw
    ///
    ///     A TextEditingController was used after being disposed.
    ///
    /// on **every** dismissal — Cancel and confirm alike — with a cascade behind
    /// it that `takeException` could not drain. In release the assertion is
    /// compiled out, which is why nobody saw it: what was left was a listener
    /// registered on a disposed `ChangeNotifier`.
    ///
    /// `_RejectDialog` owns the controller now, so it outlives the animation.
    /// This test is the guard: it pumps the exit transition to completion, which
    /// is exactly what the old code could not survive.
    testWidgets('the dialog can be dismissed without a framework error',
        (tester) async {
      await pumpQueue(tester, queue: [pendingSubmission()]);
      await openReject(tester);

      await tester.enterText(find.byType(TextFormField), 'Typed and abandoned');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
