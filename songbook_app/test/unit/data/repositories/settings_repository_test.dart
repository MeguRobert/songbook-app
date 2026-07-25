import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/core/theme/app_theme.dart';
import 'package:songbook_app/data/datasources/local/local_datasource.dart';
import 'package:songbook_app/data/models/view_config.dart';
import 'package:songbook_app/data/repositories/settings_repository.dart';

class MockLocalDataSource extends Mock implements LocalDataSource {}

void main() {
  late MockLocalDataSource dataSource;
  late SettingsRepository repository;

  setUp(() {
    dataSource = MockLocalDataSource();
    repository = SettingsRepository(dataSource);
  });

  group('theme mode', () {
    test('reads stored mode by enum name', () {
      when(() => dataSource.getStringSetting('theme_mode')).thenReturn('dark');
      expect(repository.getThemeMode(), AppThemeMode.dark);

      when(() => dataSource.getStringSetting('theme_mode')).thenReturn('light');
      expect(repository.getThemeMode(), AppThemeMode.light);
    });

    test('defaults to system for absent or unknown values', () {
      when(() => dataSource.getStringSetting('theme_mode')).thenReturn(null);
      expect(repository.getThemeMode(), AppThemeMode.system);

      when(() => dataSource.getStringSetting('theme_mode'))
          .thenReturn('bogus');
      expect(repository.getThemeMode(), AppThemeMode.system);
    });

    test('setThemeMode stores the enum name', () async {
      when(() => dataSource.setStringSetting('theme_mode', 'dark'))
          .thenAnswer((_) async => true);
      expect(await repository.setThemeMode(AppThemeMode.dark), isTrue);
      verify(() => dataSource.setStringSetting('theme_mode', 'dark')).called(1);
    });
  });

  group('show chords', () {
    test('defaults to true when absent', () {
      when(() => dataSource.getBoolSetting('show_chords')).thenReturn(null);
      expect(repository.getShowChords(), isTrue);
    });

    test('reads and writes the flag', () async {
      when(() => dataSource.getBoolSetting('show_chords')).thenReturn(false);
      expect(repository.getShowChords(), isFalse);

      when(() => dataSource.setBoolSetting('show_chords', false))
          .thenAnswer((_) async => true);
      await repository.setShowChords(false);
      verify(() => dataSource.setBoolSetting('show_chords', false)).called(1);
    });
  });

  group('font size', () {
    test('defaults to 18.0 when absent', () {
      when(() => dataSource.getIntSetting('font_size')).thenReturn(null);
      expect(repository.getFontSize(), 18.0);
    });

    test('reads stored int as double', () {
      when(() => dataSource.getIntSetting('font_size')).thenReturn(22);
      expect(repository.getFontSize(), 22.0);
    });

    test('setFontSize rounds to the nearest int', () async {
      when(() => dataSource.setIntSetting('font_size', 21))
          .thenAnswer((_) async => true);
      await repository.setFontSize(20.6);
      verify(() => dataSource.setIntSetting('font_size', 21)).called(1);
    });
  });

  group('view config (global)', () {
    test('defaults to all-on when absent', () {
      when(() => dataSource.getStringSetting('view_config')).thenReturn(null);
      expect(repository.getViewConfig(), const ViewConfig());
    });

    test('parses the stored storage string', () {
      when(() => dataSource.getStringSetting('view_config'))
          .thenReturn('false:true');
      expect(repository.getViewConfig(), const ViewConfig.chords());
    });

    test('invalid stored value falls back to default', () {
      when(() => dataSource.getStringSetting('view_config'))
          .thenReturn('garbage');
      expect(repository.getViewConfig(), const ViewConfig());
    });

    test('setViewConfig stores the storage string', () async {
      when(() => dataSource.setStringSetting('view_config', 'false:false'))
          .thenAnswer((_) async => true);
      await repository.setViewConfig(const ViewConfig.lyricsOnly());
      verify(() => dataSource.setStringSetting('view_config', 'false:false'))
          .called(1);
    });
  });

  group('per-song view config', () {
    test('null when no override is stored (null semantics preserved)', () {
      when(() => dataSource.getStringSetting('song_view_config_42'))
          .thenReturn(null);
      expect(repository.getSongViewConfig(42), isNull);
    });

    test('reads a stored override for the right song key', () {
      when(() => dataSource.getStringSetting('song_view_config_42'))
          .thenReturn('true:false');
      // 'true:false' is notation-without-chords — a real state again, set by
      // the "Chords above staff" switch, so it is read back verbatim.
      expect(
        repository.getSongViewConfig(42),
        const ViewConfig(showNotation: true, showChords: false),
      );
    });

    test('setSongViewConfig writes under the per-song key', () async {
      when(() => dataSource.setStringSetting(
              'song_view_config_7', 'false:true'))
          .thenAnswer((_) async => true);
      await repository.setSongViewConfig(7, const ViewConfig.chords());
      verify(() => dataSource.setStringSetting(
          'song_view_config_7', 'false:true')).called(1);
    });

    test('clearSongViewConfig removes the per-song key', () async {
      when(() => dataSource.removeStringSetting('song_view_config_7'))
          .thenAnswer((_) async => true);
      await repository.clearSongViewConfig(7);
      verify(() => dataSource.removeStringSetting('song_view_config_7'))
          .called(1);
    });
  });

  group('projection mode', () {
    test('defaults to false when absent', () {
      when(() => dataSource.getBoolSetting('projection_mode')).thenReturn(null);
      expect(repository.getProjectionMode(), isFalse);
    });

    test('reads and writes the flag', () async {
      when(() => dataSource.getBoolSetting('projection_mode')).thenReturn(true);
      expect(repository.getProjectionMode(), isTrue);

      when(() => dataSource.setBoolSetting('projection_mode', true))
          .thenAnswer((_) async => true);
      await repository.setProjectionMode(true);
      verify(() => dataSource.setBoolSetting('projection_mode', true))
          .called(1);
    });
  });
}
