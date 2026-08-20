import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/repositories/auth_repository.dart';
import 'package:songbook_app/data/repositories/settings_repository.dart';
import 'package:songbook_app/domain/services/photo_import_service.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

/// Which engine reads a photographed page, and what it is trusted with.
///
/// The address of the sheet-music reader is compiled in and cannot be changed
/// from inside the app. That is the point of these tests as much as the wiring
/// is: there is one reader, it is ours, and it is the only thing the signed-in
/// account's access token is ever handed to. It used to be a setting — writable
/// from a URL parameter, no less — while the notation request carried that
/// token, which together was a way to be given somebody's whole account.

/// An account that exists only to hold a token.
///
/// `noSuchMethod` covers the rest of [AuthRepository] deliberately: if the
/// notation provider ever starts calling something else on it, that is a change
/// worth failing on rather than quietly answering null.
class _TokenOnlyAuth implements AuthRepository {
  _TokenOnlyAuth(this.accessToken, {this.changes});

  /// Mutable, so a test can hand out a different token after a refresh.
  @override
  String? accessToken;

  /// Supplied only by the test that emits a refresh.
  final Stream<AuthState>? changes;

  @override
  Stream<AuthState> get authStateChanges =>
      changes ?? const Stream<AuthState>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'The notation provider needs only the access token.');
}

/// The address a deployed build carries. A test build has none, because it
/// compiles without --dart-define — which is what keeps a test from reaching
/// for a network, and why it has to be substituted here.
const compiledIn = 'https://songbook-omr.example/extract';

Future<SettingsRepository> settingsWith({String? endpoint}) async {
  SharedPreferences.setMockInitialValues({});
  return SettingsRepository(
    LocalDataSource(await SharedPreferences.getInstance()),
    photoImportEndpointOverride: endpoint,
  );
}

/// A container built as the deployed app is: a compiled-in reader, and
/// optionally somebody signed in.
Future<ProviderContainer> containerWith({
  String? endpoint = compiledIn,
  AuthRepository? auth,
}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sp),
    if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    settingsRepositoryProvider.overrideWithValue(SettingsRepository(
      LocalDataSource(sp),
      photoImportEndpointOverride: endpoint,
    )),
  ]);
}

void main() {
  group('the compiled-in address', () {
    test('is absent in a build with no --dart-define', () async {
      // Every build except the deployed one. The import screen explains it
      // rather than offering a button that cannot work.
      final settings = await settingsWith();
      expect(settings.getPhotoImportEndpoint(), isNull);
    });

    test('is used when the build carries one', () async {
      final settings = await settingsWith(endpoint: compiledIn);
      expect(settings.getPhotoImportEndpoint().toString(), compiledIn);
    });

    test('a malformed value reads as no reader, not as a crash', () async {
      // Each of these is a plausible mistake in a --dart-define. None may
      // reach http.
      for (final bad in [
        'not a url',
        'example.test/extract', // no scheme
        'ftp://example.test/x', // wrong scheme
        'https://', // no authority
        '   ',
      ]) {
        final settings = await settingsWith(endpoint: bad);
        expect(settings.getPhotoImportEndpoint(), isNull, reason: bad);
      }
    });

    test('nothing a user does can change it', () async {
      // The whole point. There is no setter, no stored key, and nothing reads
      // shared preferences for it — so a URL parameter, a settings screen or a
      // stale stored value cannot point this anywhere. If a setter is ever
      // added back, the token in photoNotationImportServiceProvider needs
      // withholding from anywhere that is not this address.
      SharedPreferences.setMockInitialValues({
        'settings_photo_import_endpoint': 'https://evil.example/extract',
        'photo_import_endpoint': 'https://evil.example/extract',
      });
      final settings = SettingsRepository(
        LocalDataSource(await SharedPreferences.getInstance()),
        photoImportEndpointOverride: compiledIn,
      );
      expect(settings.getPhotoImportEndpoint().toString(), compiledIn);
    });
  });

  group('photoTextImportServiceProvider', () {
    test('is null off the web, because there is no engine to run', () async {
      // On the Dart VM the conditional import resolves to the stub, which
      // reports itself unsupported. That is the honest answer for a build with
      // no browser in it, and the import screen says so rather than failing on
      // tap. In a web build this is a BrowserPhotoImportService.
      final container = await containerWith();
      addTearDown(container.dispose);
      expect(container.read(photoTextImportServiceProvider), isNull);
    });

    test('a compiled-in reader does not divert it', () async {
      // Words and chords are read on the device, measured faster and more
      // accurate than the server path this replaced. The notation address must
      // not quietly take that back.
      final container = await containerWith(endpoint: compiledIn);
      addTearDown(container.dispose);
      expect(container.read(photoTextImportServiceProvider), isNull);
    });
  });

  group('photoNotationImportServiceProvider', () {
    test('is null when this build ships no reader', () async {
      final container = await containerWith(endpoint: null);
      addTearDown(container.dispose);
      expect(container.read(photoNotationImportServiceProvider), isNull);
    });

    test('is null when the compiled-in address is unusable', () async {
      final container = await containerWith(endpoint: 'nonsense');
      addTearDown(container.dispose);
      expect(container.read(photoNotationImportServiceProvider), isNull);
    });

    test('points at the compiled-in reader and carries the account token',
        () async {
      // Without the token the service answers 401: it verifies a Supabase
      // access token against the project's public keys, and the app is the only
      // thing holding one.
      final container =
          await containerWith(auth: _TokenOnlyAuth('live-session-token'));
      addTearDown(container.dispose);

      final service = container.read(photoNotationImportServiceProvider)!
          as HttpPhotoImportService;
      expect(service.endpoint.toString(), compiledIn);
      expect(service.token, 'live-session-token');
    });

    test('signed out, it still builds and sends no header', () async {
      final container = await containerWith();
      addTearDown(container.dispose);

      final service = container.read(photoNotationImportServiceProvider)!
          as HttpPhotoImportService;
      // The service refuses it with a 401 the screen re-words as "sign in".
      expect(service.token, isNull);
    });

    test('a refreshed session is what the next import carries', () async {
      // The entire answer to token expiry is that this provider rebuilds when
      // the auth stream emits. Nothing tested it, so moving the watch or
      // turning it into a read would have passed.
      final changes = StreamController<AuthState>();
      addTearDown(changes.close);
      final auth = _TokenOnlyAuth('first-token', changes: changes.stream);
      final container = await containerWith(auth: auth);
      addTearDown(container.dispose);

      // Kept alive, or the provider is disposed between reads and would
      // rebuild for that reason instead of for the emission.
      final subscription =
          container.listen(photoNotationImportServiceProvider, (_, __) {});
      addTearDown(subscription.close);

      expect(
        (container.read(photoNotationImportServiceProvider)!
                as HttpPhotoImportService)
            .token,
        'first-token',
      );

      auth.accessToken = 'second-token';
      changes.add(AuthState(AuthChangeEvent.tokenRefreshed, null));
      await Future<void>.delayed(Duration.zero);

      expect(
        (container.read(photoNotationImportServiceProvider)!
                as HttpPhotoImportService)
            .token,
        'second-token',
        reason: 'the refresh must have rebuilt the service',
      );
    });
  });
}
