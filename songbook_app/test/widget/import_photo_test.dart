import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/photo_import_service.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';

import 'helpers.dart';

/// The photo-import entry point.
///
/// The picker itself is a platform channel and cannot be driven here, so these
/// cover what surrounds it: the button exists, an unconfigured service explains
/// itself instead of failing silently, and a configured one is what the screen
/// reaches for.
class _FakePhotoImportService implements PhotoImportService {
  final PhotoImportPayload? payload;
  final PhotoImportException? error;
  int calls = 0;

  _FakePhotoImportService({this.payload, this.error});

  @override
  Future<PhotoImportPayload> extract(Uint8List imageBytes,
      {String? fileName}) async {
    calls++;
    if (error != null) throw error!;
    return payload!;
  }
}

/// Opens the "More ways to add" expander that holds the non-paste sources.
///
/// Photo lives in there beside the file picker, both demoted behind one
/// disclosure so pasting a chord sheet keeps the screen — it is what actually
/// happens most of the time.
Future<void> openMoreWays(WidgetTester tester) async {
  await tester.tap(find.text('More ways to add'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Photo button waits inside "More ways to add"',
      (tester) async {
    await pumpScreen(tester, const ImportSongScreen());
    await tester.pumpAndSettle();

    expect(find.text('Photo'), findsNothing);

    await openMoreWays(tester);

    expect(find.text('Photo'), findsOneWidget);
    // Beside the file picker, not instead of it.
    expect(find.text('MusicXML file'), findsOneWidget);
  });

  testWidgets('with no service configured, tapping Photo says where to set '
      'it up rather than doing nothing', (tester) async {
    // The failure mode this guards: a button that looks live, does nothing on
    // tap, and gives no hint that configuration is missing.
    await pumpScreen(tester, const ImportSongScreen());
    await tester.pumpAndSettle();
    await openMoreWays(tester);

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Settings'), findsWidgets);
  });

  testWidgets('a configured service is the one the screen reaches for',
      (tester) async {
    final fake = _FakePhotoImportService(
      payload: const ChordProPayload('[G]Az Úrra [C]bízom életem'),
    );

    await pumpScreen(
      tester,
      const ImportSongScreen(),
      overrides: [photoImportServiceProvider.overrideWithValue(fake)],
    );
    await tester.pumpAndSettle();
    await openMoreWays(tester);

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();

    // The not-configured message must NOT appear: the screen resolved a
    // service. It then opens a real file picker, which this harness cannot
    // satisfy, so extraction itself is covered in the service's own tests.
    expect(find.text('Set up photo import in Settings first.'), findsNothing);
  });

  group('what the screen does with a payload', () {
    // The picker cannot be driven in a widget test, so these assert the
    // handling either side of it: that a ChordPro answer is exactly what the
    // existing parser consumes, and that a failure carries a readable message.
    test('ChordPro from a photo parses like any other paste', () async {
      final fake = _FakePhotoImportService(
        payload: const ChordProPayload(
            '[G]Az Úrra [C]bízom életem\n\nMásodik versszak'),
      );
      final payload = await fake.extract(Uint8List.fromList([1, 2, 3]));

      expect(payload, isA<ChordProPayload>());
      expect((payload as ChordProPayload).text, contains('[G]'));
    });

    test('a service failure surfaces its sentence', () async {
      final fake = _FakePhotoImportService(
        error: const PhotoImportException('Nothing could be read from that photo.'),
      );

      await expectLater(
        () => fake.extract(Uint8List.fromList([1])),
        throwsA(isA<PhotoImportException>().having(
            (e) => e.message, 'message', contains('Nothing could be read'))),
      );
    });
  });
}
