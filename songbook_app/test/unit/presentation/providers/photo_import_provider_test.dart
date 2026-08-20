import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/repositories/auth_repository.dart';
import 'package:songbook_app/data/repositories/settings_repository.dart';
import 'package:songbook_app/domain/services/photo_import_service.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

/// Configuring photo import.
///
/// The stored address configures the *sheet-music* half only. Reading words and
/// chords moved into the browser, so it needs no address at all — which is why
/// there are two providers here, and why only one of them can be unconfigured.
///
/// The address is stored rather than compiled in, so everything a user can
/// mistype has to degrade into "not configured" — a state the UI explains —
/// rather than into a crash partway through an import.

/// An account that exists only to hold a token.
///
/// `noSuchMethod` covers the rest of [AuthRepository] deliberately: if the
/// notation provider ever starts calling something else on it, that is a change
/// worth failing on rather than quietly answering null.
class _TokenOnlyAuth implements AuthRepository {
  _TokenOnlyAuth(this.accessToken);

  @override
  final String? accessToken;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'The notation provider needs only the access token.');
}
Future<SettingsRepository> settingsWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  return SettingsRepository(LocalDataSource(await SharedPreferences.getInstance()));
}

Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
  );
}

/// The same, with somebody signed in.
Future<ProviderContainer> containerWithAuth(
    Map<String, Object> prefs, String token) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sp),
    authRepositoryProvider.overrideWithValue(_TokenOnlyAuth(token)),
  ]);
}

void main() {
  group('endpoint storage', () {
    test('is null until configured', () async {
      final settings = await settingsWith({});
      expect(settings.getPhotoImportEndpoint(), isNull);
      expect(settings.getPhotoImportToken(), isNull);
    });

    test('round-trips a valid https endpoint', () async {
      final settings = await settingsWith({});
      await settings.setPhotoImportEndpoint(' https://example.test/extract ');
      expect(settings.getPhotoImportEndpoint().toString(),
          'https://example.test/extract');
    });

    test('accepts plain http, for a service on your own network', () async {
      final settings = await settingsWith({});
      await settings.setPhotoImportEndpoint('http://192.168.1.20:8000/extract');
      expect(settings.getPhotoImportEndpoint(), isNotNull);
    });

    test('a malformed value reads as not configured, not as a crash', () async {
      // Each of these is a plausible typo. None may reach http.
      for (final bad in [
        'not a url',
        'example.test/extract', // no scheme
        'ftp://example.test/x', // wrong scheme
        'https://', // no authority
      ]) {
        final settings = await settingsWith({
          'settings_photo_import_endpoint': bad,
        });
        expect(settings.getPhotoImportEndpoint(), isNull, reason: bad);
      }
    });

    test('an empty value clears rather than storing blank', () async {
      final settings = await settingsWith({});
      await settings.setPhotoImportEndpoint('https://example.test/x');
      await settings.setPhotoImportEndpoint('   ');
      expect(settings.getPhotoImportEndpoint(), isNull);
    });

    test('the token is optional and clearable', () async {
      final settings = await settingsWith({});
      await settings.setPhotoImportToken('  abc123  ');
      expect(settings.getPhotoImportToken(), 'abc123');
      await settings.setPhotoImportToken('');
      expect(settings.getPhotoImportToken(), isNull);
    });
  });

  group('photoTextImportServiceProvider', () {
    test('is null off the web, because there is no engine to run', () async {
      // On the Dart VM the conditional import resolves to the stub, which
      // reports itself unsupported. That is the honest answer for a build with
      // no browser in it, and the import screen says so rather than failing on
      // tap. In a web build this is a BrowserPhotoImportService.
      final container = await containerWith({});
      addTearDown(container.dispose);
      expect(container.read(photoTextImportServiceProvider), isNull);
    });

    test('a stored address does not divert it', () async {
      // The address belongs to the sheet-music reader. Words and chords are
      // read locally, measured faster and more accurate than the server path
      // this replaced, so a stored address must not quietly take that back.
      final container = await containerWith({
        'settings_photo_import_endpoint': 'https://example.test/extract',
      });
      addTearDown(container.dispose);
      expect(container.read(photoTextImportServiceProvider), isNull);
    });
  });

  group('photoNotationImportServiceProvider', () {
    test('is null when nothing is configured', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      // Null, not a throwing stub: "point this at a service" is a setup step
      // the UI can explain, not an error to fail on tap.
      expect(container.read(photoNotationImportServiceProvider), isNull);
    });

    test('is null when the stored endpoint is unusable', () async {
      final container = await containerWith({
        'settings_photo_import_endpoint': 'nonsense',
      });
      addTearDown(container.dispose);
      expect(container.read(photoNotationImportServiceProvider), isNull);
    });

    test('builds a service once an endpoint is stored', () async {
      final container = await containerWith({
        'settings_photo_import_endpoint': 'https://example.test/extract',
        'settings_photo_import_token': 'tok',
      });
      addTearDown(container.dispose);

      final service = container.read(photoNotationImportServiceProvider);
      expect(service, isA<HttpPhotoImportService>());
      expect((service! as HttpPhotoImportService).endpoint.toString(),
          'https://example.test/extract');
      expect((service as HttpPhotoImportService).token, 'tok');
    });

    test('sends the signed-in account own token when none was typed', () async {
      // Without this the deployed service answers 401: it verifies a Supabase
      // access token against the project public keys, and the app is the only
      // thing holding one.
      final container = await containerWithAuth(
        {'settings_photo_import_endpoint': 'https://example.test/extract'},
        'live-session-token',
      );
      addTearDown(container.dispose);

      final service = container.read(photoNotationImportServiceProvider)!
          as HttpPhotoImportService;
      expect(service.token, 'live-session-token');
    });

    test('a token typed into Settings wins over the session one', () async {
      // Someone running their own reader has no Supabase session to offer it,
      // and has answered the question explicitly.
      final container = await containerWithAuth(
        {
          'settings_photo_import_endpoint': 'http://192.168.1.20:8000/extract',
          'settings_photo_import_token': 'my-own-key',
        },
        'live-session-token',
      );
      addTearDown(container.dispose);

      final service = container.read(photoNotationImportServiceProvider)!
          as HttpPhotoImportService;
      expect(service.token, 'my-own-key');
    });

    test('signed out and nothing typed still builds, and sends no header',
        () async {
      final container = await containerWith({
        'settings_photo_import_endpoint': 'https://example.test/extract',
      });
      addTearDown(container.dispose);

      final service = container.read(photoNotationImportServiceProvider)!
          as HttpPhotoImportService;
      // The service refuses it with a 401 that the screen re-words as "sign
      // in". Blocking it here instead would break a self-hosted reader that
      // wants no token at all.
      expect(service.token, isNull);
    });
  });
}
