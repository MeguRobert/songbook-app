import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/submission.dart';

Map<String, dynamic> row({
  String id = '11111111-1111-1111-1111-111111111111',
  String status = 'pending',
  String? rejectionReason,
  String? submittedAt = '2026-08-01T10:00:00Z',
  Object? payload,
}) =>
    {
      'id': id,
      'status': status,
      'rejection_reason': rejectionReason,
      'submitted_at': submittedAt,
      'number': 90,
      'title': 'Te benned bíztunk',
      'payload': payload ??
          {
            'number': 90,
            'title': 'Te benned bíztunk',
            'originalKey': 'Bb',
            'verses': <dynamic>[],
          },
    };

void main() {
  group('status mapping', () {
    test('maps every wire name the database can produce', () {
      // Mirrors the song_status enum in migration 20260728120000.
      expect(SubmissionStatus.fromWireName('draft'), SubmissionStatus.draft);
      expect(SubmissionStatus.fromWireName('pending'), SubmissionStatus.pending);
      expect(
          SubmissionStatus.fromWireName('approved'), SubmissionStatus.approved);
      expect(
          SubmissionStatus.fromWireName('rejected'), SubmissionStatus.rejected);
    });

    test('an unknown status becomes pending rather than being dropped', () {
      // A row we cannot classify still exists. Showing it in the wrong bucket is
      // recoverable; silently hiding a contributor's song is not.
      expect(SubmissionStatus.fromWireName('quarantined'),
          SubmissionStatus.pending);
    });
  });

  group('parsing a row', () {
    test('reads status, reason and timestamp', () {
      final submission = Submission.tryFromRow(row(
        status: 'rejected',
        rejectionReason: 'The chords do not match the melody.',
      ))!;

      expect(submission.status, SubmissionStatus.rejected);
      expect(submission.isRejected, isTrue);
      expect(submission.rejectionReason, 'The chords do not match the melody.');
      expect(submission.submittedAt, DateTime.utc(2026, 8, 1, 10));
    });

    test('the song gets a server-scoped id that cannot collide', () {
      // Without this, a submitted song numbered 90 would share an id with
      // hymnal song 90 and one would silently replace the other on merge.
      final submission = Submission.tryFromRow(row())!;
      expect(submission.song.id.value,
          'user:11111111-1111-1111-1111-111111111111');
    });

    test('an id inside the payload does not override the row id', () {
      final submission = Submission.tryFromRow(row(payload: {
        'id': 'user:forged',
        'number': 90,
        'title': 'x',
        'originalKey': 'C',
        'verses': <dynamic>[],
      }))!;

      expect(submission.song.id.value,
          'user:11111111-1111-1111-1111-111111111111',
          reason: 'the server owns identity; a payload claim is not evidence');
    });

    test('a missing payload yields null instead of throwing', () {
      expect(Submission.tryFromRow(row(payload: 'not a map')), isNull);
    });

    test('an unparseable payload yields null instead of throwing', () {
      // One bad row must not empty a moderator's queue.
      expect(Submission.tryFromRow(row(payload: {'nonsense': true})), isNull);
    });

    test('a null submitted_at is tolerated', () {
      // Drafts have never been submitted, so they carry no timestamp.
      final submission =
          Submission.tryFromRow(row(status: 'draft', submittedAt: null))!;
      expect(submission.submittedAt, isNull);
      expect(submission.status, SubmissionStatus.draft);
    });

    test('a malformed submitted_at is tolerated', () {
      final submission = Submission.tryFromRow(row(submittedAt: 'yesterday'))!;
      expect(submission.submittedAt, isNull);
    });
  });
}
