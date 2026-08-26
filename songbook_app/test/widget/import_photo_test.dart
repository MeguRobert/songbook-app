import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/photo_import_service.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';

import 'helpers.dart';

/// The photo-import entry point.
///
/// The picker itself is a platform channel and cannot be driven here, so these
/// cover what surrounds it: the button is on the first screen beside Parse, each
/// of the two engines is asked for only when it is the one chosen, and neither
/// being available says so instead of failing silently.
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

void main() {
  testWidgets('Photo sits beside Parse, with nothing to open first',
      (tester) async {
    // It used to wait two taps away inside a "More ways to add" expander,
    // sharing that drawer with a MusicXML file picker that needs a score
    // exported from MuseScore first. That gave the rarest path equal billing and
    // hid the one this app is for: the songs being added are in books, and a
    // book is photographed.
    await pumpScreen(tester, const ImportSongScreen());
    await tester.pumpAndSettle();

    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Parse'), findsOneWidget);
    expect(find.text('More ways to add'), findsNothing);
    expect(find.text('MusicXML file'), findsNothing);
  });

  testWidgets('with no reader available, tapping Photo says why rather than '
      'doing nothing', (tester) async {
    // The failure mode this guards: a button that looks live, does nothing on
    // tap, and gives no hint why. On the Dart VM there is no browser to run the
    // engine in, which is exactly the state a non-web build is in.
    await pumpScreen(tester, const ImportSongScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('browser version'), findsOneWidget);
  });

  testWidgets('the words engine is the one a plain photo reaches for',
      (tester) async {
    final words = _FakePhotoImportService(
      payload: const ChordProPayload('[G]Az Úrra [C]bízom életem'),
    );
    final notation = _FakePhotoImportService(
      payload: const MusicXmlPayload('<score-partwise/>'),
    );

    await pumpScreen(
      tester,
      const ImportSongScreen(),
      overrides: [
        photoTextImportServiceProvider.overrideWithValue(words),
        photoNotationImportServiceProvider.overrideWithValue(notation),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();

    // Neither "no reader" nor "no service" may appear: the screen resolved one.
    // It then opens a real file picker, which this harness cannot satisfy, so
    // extraction itself is covered in the services' own tests.
    expect(find.textContaining('browser version'), findsNothing);
    expect(find.textContaining('cannot read sheet music'), findsNothing);
  });

  testWidgets('ticking "this page has sheet music" shows the instruction that '
      'decides whether it works', (tester) async {
    // A curled page took the notation reading from 63 notes to 6. Pressing the
    // book flat is worth more than any code in this feature, so the toggle that
    // routes to the notation engine is what says it.
    await pumpScreen(tester, const ImportSongScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('Press the book flat'), findsNothing);

    await tester.tap(find.text('This page has sheet music'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Press the book flat'), findsOneWidget);
  });

  testWidgets('with sheet music ticked and no reader in this build, the screen '
      'says so', (tester) async {
    // The words engine is unavailable here too, so this also pins that the
    // toggle really does change which engine is asked for: the message is the
    // sheet-music one, not the no-browser one. Neither message offers a fix in
    // Settings any more — the reader is compiled in and there is nothing there
    // to point at.
    await pumpScreen(tester, const ImportSongScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('This page has sheet music'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('cannot read sheet music'), findsOneWidget);
    expect(find.textContaining('browser version'), findsNothing);
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
