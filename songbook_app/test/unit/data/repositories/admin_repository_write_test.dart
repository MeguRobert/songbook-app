import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:songbook_app/data/models/app_settings.dart';
import 'package:songbook_app/data/repositories/admin_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The three writes that used to report success whatever the server decided.
///
/// **A policy refusal on an UPDATE is not an error.** Postgres matches no row
/// and PostgREST answers 204 with an empty body, which the Dart client reports
/// as a clean completion. So `saveSettings`, `setDisplayName` and
/// `acceptGuidelines` all returned normally when RLS had refused them: an
/// administrator edited the contribution guidelines, saw "Done", and nothing had
/// changed.
///
/// Chaining `.select()` is what makes the difference visible — PostgREST then
/// returns the affected rows, and both `app_settings` and `profiles` are
/// world-readable (`app_settings_read_all` and `profiles_read_all`, each
/// `for select using (true)`), so a write that really happened always hands its
/// row back. An empty answer therefore means nothing was written.
///
/// Driven through a real [SupabaseClient] over a stubbed `http.Client` rather
/// than a mocked query builder, because the whole defect lives in the wire
/// semantics: a mock that returned whatever it was told would have agreed with
/// the broken code just as readily.

/// One `profiles` row, as PostgREST would return it.
const _profileRow = {
  'id': 'user-1',
  'display_name': 'Anna Kovács',
  'guidelines_accepted_at': null,
};

/// The `app_settings` singleton, as PostgREST would return it.
const _settingsRow = {
  'id': 1,
  'submissions_open': true,
  'require_confirmed_email': true,
  'daily_submission_cap': 5,
  'guidelines_en': 'Only songs actually sung in worship.',
  'guidelines_hu': 'Csak olyan énekek.',
  'guidelines_ro': 'Doar cântări.',
};

/// A client whose REST calls are answered from [rows], recording each request.
///
/// [rows] is what a PATCH comes back with: `[]` is the refusal — the shape RLS
/// produces — and a one-element list is the write that landed.
class FakeRest {
  FakeRest({required this.rows});

  List<Map<String, Object?>> rows;
  final List<http.BaseRequest> requests = [];

  late final SupabaseClient client = SupabaseClient(
    'http://songbook.test',
    'test-publishable-key',
    // Nothing here refreshes a token, and a live refresh timer would outlive
    // the test.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(rows),
        200,
        // Carried back deliberately: postgrest reads `response.request` to
        // decide how to parse, and a response with none throws before it ever
        // looks at the body.
        request: request,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );

  http.BaseRequest get lastRequest => requests.last;

  /// Signs a user in without a server, by restoring a session whose access
  /// token is a well-formed JWT that has not expired.
  Future<void> signIn() async {
    String segment(Map<String, Object?> claims) =>
        base64Url.encode(utf8.encode(jsonEncode(claims))).replaceAll('=', '');
    final expiry =
        DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
            1000;

    await client.auth.recoverSession(jsonEncode({
      'access_token': '${segment({'alg': 'none', 'typ': 'JWT'})}.'
          '${segment({'sub': 'user-1', 'exp': expiry})}.signature',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh',
      'user': {
        'id': 'user-1',
        'aud': 'authenticated',
        'app_metadata': <String, Object?>{},
        'user_metadata': <String, Object?>{},
        'created_at': '2026-01-01T00:00:00Z',
      },
    }));
  }
}

FakeRest serverReturning(List<Map<String, Object?>> rows) {
  final server = FakeRest(rows: rows);
  addTearDown(server.client.dispose);
  return server;
}

/// Whatever the request asked PostgREST to send back, header case aside.
String? preferOf(http.BaseRequest request) {
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == 'prefer') return entry.value;
  }
  return null;
}

void main() {
  group('saveSettings', () {
    test('a refusal that matched no row is a failure, not a save', () async {
      final server = serverReturning([]);
      final repository = AdminRepository(server.client);

      // What an administrator saw before this: nothing at all, and a "Done"
      // snackbar over guidelines that had not changed.
      await expectLater(
        repository.saveSettings(const AppSettings()),
        throwsA(isA<AdminFailure>().having(
          (failure) => failure.code,
          'code',
          AdminFailureCode.forbidden,
        )),
      );
    });

    test('asks PostgREST for the affected rows', () async {
      final server = serverReturning([_settingsRow]);
      await AdminRepository(server.client).saveSettings(const AppSettings());

      // The mechanism: without `return=representation` the answer is 204 and
      // there is nothing to tell a refusal from a save.
      expect(preferOf(server.lastRequest), contains('return=representation'));
      expect(server.lastRequest.method, 'PATCH');
    });

    test('a write that comes back with its row completes', () async {
      final server = serverReturning([_settingsRow]);
      await AdminRepository(server.client).saveSettings(const AppSettings());
    });
  });

  group('setDisplayName', () {
    test('a refusal that matched no row is reported', () async {
      final server = serverReturning([]);
      await server.signIn();
      final repository = AdminRepository(server.client);

      // The one that reaches a contributor: the publish gate asks for a name,
      // the name is not stored, and the gate asks again with nothing said.
      await expectLater(
        repository.setDisplayName('Anna Kovács'),
        throwsA(isA<AdminFailure>().having(
          (failure) => failure.code,
          'code',
          AdminFailureCode.forbidden,
        )),
      );
    });

    test('a write that comes back with its row completes', () async {
      final server = serverReturning([_profileRow]);
      await server.signIn();
      await AdminRepository(server.client).setDisplayName('Anna Kovács');

      expect(preferOf(server.lastRequest), contains('return=representation'));
    });
  });

  group('acceptGuidelines', () {
    test('a refusal that matched no row is reported', () async {
      final server = serverReturning([]);
      await server.signIn();

      await expectLater(
        AdminRepository(server.client).acceptGuidelines(),
        throwsA(isA<AdminFailure>().having(
          (failure) => failure.code,
          'code',
          AdminFailureCode.forbidden,
        )),
      );
    });

    test('a write that comes back with its row completes', () async {
      final server = serverReturning([_profileRow]);
      await server.signIn();
      await AdminRepository(server.client).acceptGuidelines();
    });

    test('signed out, it never reaches the server at all', () async {
      final server = serverReturning([_profileRow]);

      await expectLater(
        AdminRepository(server.client).acceptGuidelines(),
        throwsA(isA<AdminFailure>().having(
          (failure) => failure.code,
          'code',
          AdminFailureCode.forbidden,
        )),
      );
      expect(server.requests, isEmpty);
    });
  });
}
