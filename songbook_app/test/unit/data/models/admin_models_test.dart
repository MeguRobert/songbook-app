import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/app_role.dart';
import 'package:songbook_app/data/models/app_settings.dart';
import 'package:songbook_app/data/models/managed_user.dart';
import 'package:songbook_app/data/models/submission_refusal.dart';

void main() {
  group('AppRole', () {
    test('the ladder is ordered, and capabilities follow rank not identity', () {
      expect(AppRole.member.rank, lessThan(AppRole.moderator.rank));
      expect(AppRole.moderator.rank, lessThan(AppRole.administrator.rank));

      expect(AppRole.member.canModerate, isFalse);
      expect(AppRole.moderator.canModerate, isTrue);
      expect(AppRole.administrator.canModerate, isTrue);

      expect(AppRole.moderator.isAdministrator, isFalse,
          reason: 'the whole point of the split: a moderator is not an admin');
      expect(AppRole.administrator.isAdministrator, isTrue);
    });

    test('the wire names match the roles table', () {
      expect(AppRole.member.wireName, 'member');
      expect(AppRole.moderator.wireName, 'moderator');
      expect(AppRole.administrator.wireName, 'administrator');
    });

    test('an unknown or absent role reads as member, never higher', () {
      // A tier added to the database before this app was rebuilt must not be
      // mistaken for something powerful.
      expect(AppRole.fromWireName('contributor'), AppRole.member);
      expect(AppRole.fromWireName('admin'), AppRole.member,
          reason: 'the retired name must not still grant moderation');
      expect(AppRole.fromWireName(null), AppRole.member);
    });
  });

  group('SubmissionRefusal', () {
    test('each gate token maps to its own reason', () {
      expect(SubmissionRefusalParsing.fromServerMessage('submissions_closed'),
          SubmissionRefusal.submissionsClosed);
      expect(SubmissionRefusalParsing.fromServerMessage('email_not_confirmed'),
          SubmissionRefusal.emailNotConfirmed);
      expect(
          SubmissionRefusalParsing.fromServerMessage('guidelines_not_accepted'),
          SubmissionRefusal.guidelinesNotAccepted);
      expect(SubmissionRefusalParsing.fromServerMessage('display_name_required'),
          SubmissionRefusal.displayNameRequired);
      expect(SubmissionRefusalParsing.fromServerMessage('daily_limit_reached'),
          SubmissionRefusal.dailyLimitReached);
    });

    test('a token wrapped in Postgres prose is still recognised', () {
      expect(
        SubmissionRefusalParsing.fromServerMessage(
            'PostgrestException(message: submissions_closed, code: P0001)'),
        SubmissionRefusal.submissionsClosed,
      );
    });

    test('anything unrecognised is unknown rather than shown raw', () {
      expect(SubmissionRefusalParsing.fromServerMessage('deadlock detected'),
          SubmissionRefusal.unknown);
      expect(SubmissionRefusalParsing.fromServerMessage(null),
          SubmissionRefusal.unknown);
    });
  });

  group('ManagedUser', () {
    Map<String, dynamic> row({
      String id = 'u1',
      String? email = 'someone@example.test',
      String? displayName = 'Someone',
      String role = 'moderator',
      String? lastSignInAt = '2026-08-20T10:00:00Z',
      String? guidelinesAcceptedAt,
      Map<String, dynamic>? songs,
    }) =>
        {
          'id': id,
          'email': email,
          'emailConfirmed': true,
          'displayName': displayName,
          'role': role,
          'createdAt': '2026-01-01T00:00:00Z',
          'lastSignInAt': lastSignInAt,
          'guidelinesAcceptedAt': guidelinesAcceptedAt,
          'songs': songs ?? {'approved': 3, 'pending': 1, 'rejected': 2},
        };

    test('reads the fields the panel needs', () {
      final user = ManagedUser.tryFromJson(row())!;
      expect(user.id, 'u1');
      expect(user.role, AppRole.moderator);
      expect(user.emailConfirmed, isTrue);
      expect(user.songs.approved, 3);
      expect(user.songs.rejected, 2);
      expect(user.songs.decided, 5);
      expect(user.hasAcceptedGuidelines, isFalse);
    });

    test('an account that never signed in is dormant', () {
      final user = ManagedUser.tryFromJson(row(lastSignInAt: null))!;
      expect(user.isDormant, isTrue);
    });

    test('the label prefers a display name, then the address, never a bare id', () {
      expect(ManagedUser.tryFromJson(row())!.label, 'Someone');
      expect(ManagedUser.tryFromJson(row(displayName: '  '))!.label,
          'someone@example.test');
      expect(
          ManagedUser.tryFromJson(row(displayName: null, email: null))!.label,
          'u1');
    });

    test('a malformed entry is dropped rather than throwing', () {
      // One bad row must not empty the whole user list.
      expect(ManagedUser.tryFromJson(null), isNull);
      expect(ManagedUser.tryFromJson('not a map'), isNull);
      expect(ManagedUser.tryFromJson({'email': 'no id here'}), isNull);
    });

    test('a missing songs object is a zero tally, not a crash', () {
      final user = ManagedUser.tryFromJson({'id': 'u2', 'role': 'member'})!;
      expect(user.songs.approved, 0);
      expect(user.songs.decided, 0);
    });
  });

  group('AppSettings', () {
    final row = {
      'submissions_open': false,
      'require_confirmed_email': true,
      'daily_submission_cap': 3,
      'guidelines_en': 'English rules',
      'guidelines_hu': 'Magyar szabályok',
      'guidelines_ro': '',
      'updated_at': '2026-08-22T09:00:00Z',
    };

    test('reads the row', () {
      final settings = AppSettings.fromRow(row);
      expect(settings.submissionsOpen, isFalse);
      expect(settings.requireConfirmedEmail, isTrue);
      expect(settings.dailySubmissionCap, 3);
      expect(settings.updatedAt, isNotNull);
    });

    test('guidelines fall back to English rather than to nothing', () {
      final settings = AppSettings.fromRow(row);
      expect(settings.guidelinesFor('hu'), 'Magyar szabályok');
      // Romanian is empty in this row: a rule in the wrong language still beats
      // an empty box next to a tick that claims you read it.
      expect(settings.guidelinesFor('ro'), 'English rules');
      expect(settings.guidelinesFor('de'), 'English rules');
    });

    test('an absent row falls back to open with a cap, not to unlimited', () {
      const settings = AppSettings();
      expect(settings.submissionsOpen, isTrue);
      expect(settings.dailySubmissionCap, 5);
    });

    test('toUpdate sends only what an administrator may change', () {
      final update = AppSettings.fromRow(row).toUpdate();
      expect(update.keys, containsAll(['submissions_open', 'guidelines_hu']));
      expect(update.containsKey('updated_at'), isFalse,
          reason: 'the database sets that; claiming it would be a forgery');
      expect(update.containsKey('updated_by'), isFalse);
      expect(update.containsKey('id'), isFalse);
    });
  });
}
