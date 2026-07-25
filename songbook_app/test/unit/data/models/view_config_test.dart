import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/view_config.dart';

void main() {
  group('defaults and presets', () {
    test('default constructor shows everything', () {
      const config = ViewConfig();
      expect(config.showNotation, isTrue);
      expect(config.showChords, isTrue);
    });

    test('sheetMusic preset shows notation and chords', () {
      const config = ViewConfig.sheetMusic();
      expect(config.showNotation, isTrue);
      expect(config.showChords, isTrue);
      expect(config.isSheetMusicPreset, isTrue);
      expect(config.isChordsPreset, isFalse);
      expect(config.isLyricsOnlyPreset, isFalse);
    });

    test('chords preset hides notation, shows chords', () {
      const config = ViewConfig.chords();
      expect(config.showNotation, isFalse);
      expect(config.showChords, isTrue);
      expect(config.isChordsPreset, isTrue);
      expect(config.isSheetMusicPreset, isFalse);
      expect(config.isLyricsOnlyPreset, isFalse);
    });

    test('lyricsOnly preset hides both', () {
      const config = ViewConfig.lyricsOnly();
      expect(config.showNotation, isFalse);
      expect(config.showChords, isFalse);
      expect(config.isLyricsOnlyPreset, isTrue);
      expect(config.isSheetMusicPreset, isFalse);
      expect(config.isChordsPreset, isFalse);
    });

  });

  group('copyWith', () {
    test('overrides individual fields', () {
      const config = ViewConfig();
      expect(config.copyWith(showNotation: false),
          const ViewConfig(showNotation: false, showChords: true));
      expect(config.copyWith(showChords: false),
          const ViewConfig(showNotation: true, showChords: false));
    });

    test('no arguments returns an equal config', () {
      const config = ViewConfig.chords();
      expect(config.copyWith(), config);
    });
  });

  group('storage serialization', () {
    test('toStorageString encodes as "notation:chords"', () {
      expect(const ViewConfig().toStorageString(), 'true:true');
      expect(const ViewConfig.chords().toStorageString(), 'false:true');
      expect(const ViewConfig.lyricsOnly().toStorageString(), 'false:false');
      expect(
        const ViewConfig(showNotation: true, showChords: false)
            .toStorageString(),
        'true:false',
      );
    });

    test('fromStorageString parses the three presets', () {
      expect(ViewConfig.fromStorageString('true:true'), const ViewConfig());
      expect(
          ViewConfig.fromStorageString('false:true'), const ViewConfig.chords());
      expect(ViewConfig.fromStorageString('false:false'),
          const ViewConfig.lyricsOnly());
    });

    // notation-without-chords is a real, reachable state again: it is what the
    // "Chords above staff" switch turns off. It must survive a storage
    // round-trip rather than being normalised to Sheet Music.
    test('fromStorageString preserves the notation-without-chords state', () {
      expect(
        ViewConfig.fromStorageString('true:false'),
        const ViewConfig(showNotation: true, showChords: false),
      );
    });

    test('round-trips through storage string', () {
      const configs = [
        ViewConfig(),
        ViewConfig.chords(),
        ViewConfig.lyricsOnly(),
        ViewConfig(showNotation: true, showChords: false),
      ];
      for (final config in configs) {
        expect(ViewConfig.fromStorageString(config.toStorageString()), config);
      }
    });

    test('parsing is case-insensitive on the boolean tokens', () {
      expect(ViewConfig.fromStorageString('TRUE:True'), const ViewConfig());
      expect(ViewConfig.fromStorageString('FALSE:falsE'),
          const ViewConfig.lyricsOnly());
    });

    test('invalid input falls back to the all-on default', () {
      for (final input in ['', 'true', 'true:true:true', 'garbage', ':::']) {
        expect(ViewConfig.fromStorageString(input), const ViewConfig(),
            reason: '"$input"');
      }
    });

    test('non-boolean tokens in a two-part string parse as false', () {
      // Anything that is not (case-insensitively) 'true' is false.
      expect(ViewConfig.fromStorageString('yes:1'),
          const ViewConfig.lyricsOnly());
    });
  });

  group('equality and hashCode', () {
    test('equal values are equal with same hash', () {
      const a = ViewConfig(showNotation: false, showChords: true);
      const b = ViewConfig.chords();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different values are not equal', () {
      expect(const ViewConfig(), isNot(const ViewConfig.chords()));
      expect(const ViewConfig.chords(), isNot(const ViewConfig.lyricsOnly()));
    });

    test('is not equal to other types', () {
      expect(const ViewConfig(), isNot('true:true'));
    });
  });

  test('toString includes both flags', () {
    expect(const ViewConfig.chords().toString(),
        'ViewConfig(showNotation: false, showChords: true)');
  });
}
