import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late MockGoTrueClient client;
  late AuthRepository repository;

  setUp(() {
    client = MockGoTrueClient();
    repository = AuthRepository(client);
  });

  /// Runs a sign-in that fails with [error] and returns how it was classified.
  Future<AuthFailureCode> codeFor(Object error) async {
    when(() => client.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(error);

    try {
      await repository.signIn(email: 'a@b.test', password: 'pw');
      fail('expected a failure');
    } on AuthFailure catch (failure) {
      return failure.code;
    }
  }

  // The point of the mapping: the UI switches on a closed enum and never has to
  // match on server prose, which is English-only and free to change.
  group('classifies by error code', () {
    test('bad password', () async {
      expect(
        await codeFor(const AuthException('nope', code: 'invalid_credentials')),
        AuthFailureCode.invalidCredentials,
      );
    });

    test('unverified email', () async {
      expect(
        await codeFor(const AuthException('nope', code: 'email_not_confirmed')),
        AuthFailureCode.emailNotConfirmed,
      );
    });

    test('address already taken, under either code the server may send',
        () async {
      expect(
        await codeFor(const AuthException('x', code: 'user_already_exists')),
        AuthFailureCode.emailAlreadyRegistered,
      );
      expect(
        await codeFor(const AuthException('x', code: 'email_exists')),
        AuthFailureCode.emailAlreadyRegistered,
      );
    });

    test('weak password', () async {
      expect(
        await codeFor(const AuthException('x', code: 'weak_password')),
        AuthFailureCode.weakPassword,
      );
    });

    test('malformed address', () async {
      expect(
        await codeFor(const AuthException('x', code: 'validation_failed')),
        AuthFailureCode.invalidEmail,
      );
    });

    test('rate limited, on all three limit codes', () async {
      for (final code in [
        'over_request_rate_limit',
        'over_email_send_rate_limit',
        'over_sms_send_rate_limit',
      ]) {
        expect(
          await codeFor(AuthException('x', code: code)),
          AuthFailureCode.rateLimited,
          reason: code,
        );
      }
    });

    test('a server timeout is a network problem, not a credentials problem',
        () async {
      expect(
        await codeFor(const AuthException('x', code: 'request_timeout')),
        AuthFailureCode.network,
      );
    });

    test('signups disabled is a server refusal the user cannot fix', () async {
      expect(
        await codeFor(const AuthException('x', code: 'signup_disabled')),
        AuthFailureCode.serverRejected,
      );
    });
  });

  // GoTrue's `code` is a raw passthrough of the server's error_code and can be
  // absent, so the message fallback is load-bearing rather than belt-and-braces.
  group('falls back to the message when no code is supplied', () {
    test('bad password', () async {
      expect(
        await codeFor(const AuthException('Invalid login credentials')),
        AuthFailureCode.invalidCredentials,
      );
    });

    test('unverified email', () async {
      expect(
        await codeFor(const AuthException('Email not confirmed')),
        AuthFailureCode.emailNotConfirmed,
      );
    });

    test('already registered', () async {
      expect(
        await codeFor(const AuthException('User already registered')),
        AuthFailureCode.emailAlreadyRegistered,
      );
    });

    test('weak password', () async {
      expect(
        await codeFor(
          const AuthException('Password should be at least 6 characters'),
        ),
        AuthFailureCode.weakPassword,
      );
    });

    test('an unrecognised auth error is a server refusal, not unknown',
        () async {
      expect(
        await codeFor(const AuthException('something new we have never seen')),
        AuthFailureCode.serverRejected,
      );
    });
  });

  test('a non-auth throw is reported as a network failure', () async {
    // Offline, DNS failure, TLS problem, and a paused free-tier project (HTTP
    // 540) all arrive as plain exceptions. The advice differs from a rejection:
    // check the connection, not what you typed.
    expect(
      await codeFor(Exception('SocketException: failed host lookup')),
      AuthFailureCode.network,
    );
  });

  test('the raw server message is kept for logs but not for users', () async {
    when(() => client.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(const AuthException('Invalid login credentials'));

    try {
      await repository.signIn(email: 'a@b.test', password: 'pw');
      fail('expected a failure');
    } on AuthFailure catch (failure) {
      expect(failure.debugMessage, 'Invalid login credentials');
      expect(failure.toString(), contains('invalidCredentials'));
    }
  });

  group('session state', () {
    test('signed out when there is no user', () {
      when(() => client.currentUser).thenReturn(null);
      expect(repository.isSignedIn, isFalse);
      expect(repository.isEmailConfirmed, isFalse,
          reason: 'no session cannot be a confirmed one');
    });

    test('a session alone does not mean the address is confirmed', () {
      // Supabase can be configured to allow unconfirmed sign-in, so holding a
      // session is not proof of verification. Contributing should require it.
      when(() => client.currentUser).thenReturn(
        User(
          id: 'u1',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.utc(2026).toIso8601String(),
        ),
      );

      expect(repository.isSignedIn, isTrue);
      expect(repository.isEmailConfirmed, isFalse);
    });

    test('confirmed once emailConfirmedAt is set', () {
      when(() => client.currentUser).thenReturn(
        User(
          id: 'u1',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.utc(2026).toIso8601String(),
          emailConfirmedAt: DateTime.utc(2026).toIso8601String(),
        ),
      );

      expect(repository.isEmailConfirmed, isTrue);
    });
  });

  test('email is trimmed before it reaches the server', () async {
    // A trailing space pasted from a password manager is a support ticket
    // waiting to happen: the server would treat it as a different address.
    when(() => client.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async => AuthResponse());

    await repository.signIn(email: '  a@b.test  ', password: 'pw');

    verify(() => client.signInWithPassword(
          email: 'a@b.test',
          password: 'pw',
        )).called(1);
  });
}
