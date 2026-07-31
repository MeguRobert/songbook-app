import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/repositories/settings_repository.dart';
import 'package:songbook_app/domain/services/photo_import_service.dart';
import 'package:songbook_app/presentation/providers/providers.dart';

/// Configuring photo import.
///
/// The endpoint is stored rather than compiled in, so everything a user can
/// mistype has to degrade into "not configured" — a state the UI explains —
/// rather than into a crash partway through an import.
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

  group('photoImportServiceProvider', () {
    test('is null when nothing is configured', () async {
      final container = await containerWith({});
      addTearDown(container.dispose);
      // Null, not a throwing stub: "point this at a service" is a setup step
      // the UI can explain, not an error to fail on tap.
      expect(container.read(photoImportServiceProvider), isNull);
    });

    test('is null when the stored endpoint is unusable', () async {
      final container = await containerWith({
        'settings_photo_import_endpoint': 'nonsense',
      });
      addTearDown(container.dispose);
      expect(container.read(photoImportServiceProvider), isNull);
    });

    test('builds a service once an endpoint is stored', () async {
      final container = await containerWith({
        'settings_photo_import_endpoint': 'https://example.test/extract',
        'settings_photo_import_token': 'tok',
      });
      addTearDown(container.dispose);

      final service = container.read(photoImportServiceProvider);
      expect(service, isA<HttpPhotoImportService>());
      expect((service! as HttpPhotoImportService).endpoint.toString(),
          'https://example.test/extract');
      expect((service as HttpPhotoImportService).token, 'tok');
    });

    test('an endpoint without a token still builds', () async {
      final container = await containerWith({
        'settings_photo_import_endpoint': 'https://example.test/extract',
      });
      addTearDown(container.dispose);

      final service =
          container.read(photoImportServiceProvider)! as HttpPhotoImportService;
      expect(service.token, isNull);
    });
  });
}
