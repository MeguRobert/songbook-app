import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/app_settings.dart';
import 'package:songbook_app/domain/services/publish_gate.dart';

void main() {
  PublishReadiness ready({
    bool isSignedIn = true,
    bool isEmailConfirmed = true,
    String? displayName = 'Someone',
    bool hasAcceptedGuidelines = true,
    AppSettings settings = const AppSettings(),
  }) =>
      PublishReadiness(
        isSignedIn: isSignedIn,
        isEmailConfirmed: isEmailConfirmed,
        displayName: displayName,
        hasAcceptedGuidelines: hasAcceptedGuidelines,
        settings: settings,
      );

  group('firstUnmetStop', () {
    test('nothing in the way', () {
      expect(firstUnmetStop(ready()), isNull);
    });

    test('signed out is the login gate', () {
      expect(firstUnmetStop(ready(isSignedIn: false)), PublishStop.signIn);
    });

    test('an unconfirmed address stops it', () {
      expect(firstUnmetStop(ready(isEmailConfirmed: false)),
          PublishStop.confirmEmail);
    });

    test('an unconfirmed address does NOT stop it when the project allows that',
        () {
      // The setting exists so a project can trade verification for friction.
      expect(
        firstUnmetStop(ready(
          isEmailConfirmed: false,
          settings: const AppSettings(requireConfirmedEmail: false),
        )),
        isNull,
      );
    });

    test('a missing or blank display name stops it', () {
      expect(firstUnmetStop(ready(displayName: null)), PublishStop.displayName);
      expect(firstUnmetStop(ready(displayName: '   ')), PublishStop.displayName,
          reason: 'whitespace is not a name to credit a hymn to');
    });

    test('unaccepted guidelines stop it', () {
      expect(firstUnmetStop(ready(hasAcceptedGuidelines: false)),
          PublishStop.guidelines);
    });

    group('ordering', () {
      test('a closed door is reported before anything is asked of the user', () {
        // The point of the whole ordering. Somebody who is signed out, has no
        // name and has not read the guidelines is told the ONE thing they cannot
        // fix, instead of being walked through three steps and then refused.
        final state = ready(
          isSignedIn: false,
          isEmailConfirmed: false,
          displayName: null,
          hasAcceptedGuidelines: false,
          settings: const AppSettings(submissionsOpen: false),
        );
        expect(firstUnmetStop(state), PublishStop.submissionsClosed);
      });

      test('signing in comes before anything about the account', () {
        final state = ready(
          isSignedIn: false,
          isEmailConfirmed: false,
          displayName: null,
          hasAcceptedGuidelines: false,
        );
        expect(firstUnmetStop(state), PublishStop.signIn);
      });

      test('confirming an address comes before the inline steps', () {
        // Leaving for an email client beats filling in a name that would then
        // have been collected from somebody who is blocked anyway.
        final state = ready(
          isEmailConfirmed: false,
          displayName: null,
          hasAcceptedGuidelines: false,
        );
        expect(firstUnmetStop(state), PublishStop.confirmEmail);
      });

      test('the name is asked for before the guidelines', () {
        final state = ready(displayName: null, hasAcceptedGuidelines: false);
        expect(firstUnmetStop(state), PublishStop.displayName);
      });
    });

    test('clearing the stops one at a time walks the whole gate', () {
      // Proves the sequence a real first-time contributor experiences, and that
      // it terminates.
      var state = ready(
        isSignedIn: false,
        isEmailConfirmed: false,
        displayName: null,
        hasAcceptedGuidelines: false,
      );
      final walked = <PublishStop>[];

      for (var i = 0; i < 10; i++) {
        final stop = firstUnmetStop(state);
        if (stop == null) break;
        walked.add(stop);
        state = switch (stop) {
          PublishStop.submissionsClosed => throw StateError('door is open'),
          PublishStop.signIn => ready(
              isEmailConfirmed: false,
              displayName: null,
              hasAcceptedGuidelines: false),
          PublishStop.confirmEmail =>
            ready(displayName: null, hasAcceptedGuidelines: false),
          PublishStop.displayName => ready(hasAcceptedGuidelines: false),
          PublishStop.guidelines => ready(),
        };
      }

      expect(walked, [
        PublishStop.signIn,
        PublishStop.confirmEmail,
        PublishStop.displayName,
        PublishStop.guidelines,
      ]);
      expect(firstUnmetStop(state), isNull);
    });
  });
}
