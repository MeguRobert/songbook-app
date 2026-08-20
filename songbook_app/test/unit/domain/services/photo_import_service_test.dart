import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:songbook_app/domain/services/chord_sheet_parser.dart';
import 'package:songbook_app/domain/services/photo_import_service.dart';

/// The photo-import contract.
///
/// Every failure here is one a user holding a phone will actually hit — an
/// endpoint that is down, a backend returning something slightly wrong, a photo
/// of a blank page — so each has to arrive as a sentence rather than an
/// exception dump or a spinner that never stops.
/// Stand-in image bytes. Content is irrelevant — nothing under test decodes
/// the image; it is forwarded to the backend verbatim.
final _image = Uint8List.fromList(List.filled(64, 7));

HttpPhotoImportService serviceReturning(
  String body, {
  int status = 200,
  void Function(http.BaseRequest)? inspect,
}) {
  return HttpPhotoImportService(
    endpoint: Uri.parse('https://example.invalid/extract'),
    token: 'secret-token',
    client: MockClient((request) async {
      inspect?.call(request);
      return http.Response(body, status, headers: {
        'content-type': 'application/json; charset=utf-8',
      });
    }),
  );
}

void main() {
  group('successful extraction', () {
    test('chordpro comes back as a ChordProPayload', () async {
      final service = serviceReturning(json.encode({
        'kind': 'chordpro',
        'content': '[G]Az Úrra [C]bízom életem',
      }));

      final payload = await service.extract(_image);

      expect(payload, isA<ChordProPayload>());
      expect((payload as ChordProPayload).text, '[G]Az Úrra [C]bízom életem');
      expect(payload.warnings, isEmpty);
    });

    test('musicxml comes back as a MusicXmlPayload', () async {
      // The v2 sheet-music path needs no new app code — only a backend that
      // answers with this kind instead.
      final service = serviceReturning(json.encode({
        'kind': 'musicxml',
        'content': '<score-partwise/>',
      }));

      final payload = await service.extract(_image);

      expect(payload, isA<MusicXmlPayload>());
      expect((payload as MusicXmlPayload).xml, '<score-partwise/>');
    });

    test('backend warnings survive to the caller', () async {
      // These sit beside the parser's own warnings on the review screen, so a
      // page the backend only half-read is visible before the song is saved.
      final service = serviceReturning(json.encode({
        'kind': 'chordpro',
        'content': '[G]Egy sor',
        'warnings': ['The bottom of the page was cut off.'],
      }));

      final payload = await service.extract(_image);
      expect(payload.warnings, ['The bottom of the page was cut off.']);
    });

    test('what it returns is what the existing parser already reads', () async {
      // The point of choosing ChordPro as the wire format: no new parsing.
      final service = serviceReturning(json.encode({
        'kind': 'chordpro',
        'content': '[G]Az Úrra [C]bízom életem\n\nMásodik versszak',
      }));

      final payload = await service.extract(_image) as ChordProPayload;
      final parsed = const ChordSheetParser().parse(payload.text);

      expect(parsed.verses, hasLength(2));
      expect(parsed.verses.first.lines.single.text, 'Az Úrra bízom életem');
      expect(parsed.verses.first.lines.single.chords.map((c) => c.chord),
          ['G', 'C']);
    });
  });

  group('the request', () {
    test('sends the image as multipart with the bearer token', () async {
      // MockClient hands the handler a finalized Request, so this asserts the
      // bytes a backend will actually receive rather than the object that
      // produced them — which is the contract that matters.
      http.BaseRequest? seen;
      final service = serviceReturning(
        json.encode({'kind': 'chordpro', 'content': '[G]x'}),
        inspect: (r) => seen = r,
      );

      await service.extract(_image, fileName: 'hymn.jpg');

      expect(seen!.method, 'POST');
      expect(seen!.headers['content-type'], startsWith('multipart/form-data'));
      expect(seen!.headers['Authorization'], 'Bearer secret-token');

      final body = latin1.decode((seen! as http.Request).bodyBytes);
      expect(body, contains('name="image"'));
      expect(body, contains('filename="hymn.jpg"'));
    });

    test('omits the Authorization header when no token is configured',
        () async {
      // A service on the user's own network may not want one, and sending
      // `Bearer ` with nothing after it is worse than sending nothing.
      http.BaseRequest? seen;
      final service = HttpPhotoImportService(
        endpoint: Uri.parse('https://example.invalid/extract'),
        client: MockClient((request) async {
          seen = request;
          return http.Response(
              json.encode({'kind': 'chordpro', 'content': '[G]x'}), 200);
        }),
      );

      await service.extract(_image);
      expect(seen!.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('failures arrive as sentences, not stack traces', () {
    Future<String> messageFrom(Future<void> Function() action) async {
      try {
        await action();
      } on PhotoImportException catch (e) {
        return e.message;
      }
      fail('expected a PhotoImportException');
    }

    test('an empty image is refused before any request is made', () async {
      var called = false;
      final service = HttpPhotoImportService(
        endpoint: Uri.parse('https://example.invalid/extract'),
        client: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      final message =
          await messageFrom(() => service.extract(Uint8List(0)));
      expect(message, contains('empty'));
      expect(called, isFalse, reason: 'no point posting nothing');
    });

    test('a non-200 with no explanation names the status', () async {
      final service = serviceReturning('nope', status: 502);
      expect(await messageFrom(() => service.extract(_image)),
          contains('502'));
    });

    test('a non-200 prefers the explanation to the status code',
        () async {
      // The backend explains itself: "No API key", "cannot decode that
      // image". Reporting only the number threw that away and left whoever
      // wrote the backend guessing at their own error message.
      final service = serviceReturning(
          json.encode({'error': 'No API key. Put one in tools/.anthropic_key.'}),
          status: 502);
      final message = await messageFrom(() => service.extract(_image));
      expect(message, contains('tools/.anthropic_key'));
      expect(message, isNot(contains('502')));
    });

    test('an empty explanation falls back to the status code', () async {
      final service =
          serviceReturning(json.encode({'error': '   '}), status: 500);
      expect(await messageFrom(() => service.extract(_image)),
          contains('500'));
    });

    test('a refused sign-in carries its status, so the app can re-word it',
        () async {
      // The sheet-music service answers "Sign in to read a page." in English.
      // Songbook is read in Hungarian and Romanian too, so the screen replaces
      // that one message with its own — and a status is the only thing it can
      // recognise it by without matching on the service's prose.
      final service = serviceReturning(
          json.encode({'error': 'Sign in to read a page.'}), status: 401);
      try {
        await service.extract(_image);
        fail('expected a PhotoImportException');
      } on PhotoImportException catch (e) {
        expect(e.statusCode, 401);
        expect(e.message, contains('Sign in'));
      }
    });

    test('a failure with no HTTP status behind it carries none', () async {
      // An empty image never reaches the wire, so there is no status to report
      // and nothing for the screen to re-word.
      final service = serviceReturning('unused');
      try {
        await service.extract(Uint8List(0));
        fail('expected a PhotoImportException');
      } on PhotoImportException catch (e) {
        expect(e.statusCode, isNull);
      }
    });

    test('a non-JSON body says so rather than throwing FormatException',
        () async {
      // A misconfigured URL pointing at a normal web page is the likely cause,
      // and that should read as a configuration problem.
      final service = serviceReturning('<html>Not found</html>');
      expect(await messageFrom(() => service.extract(_image)),
          contains('did not return JSON'));
    });

    test('an unreadable photo reports nothing could be read', () async {
      // A blank page, a thumb over the lens, a photo of the ceiling.
      final service =
          serviceReturning(json.encode({'kind': 'chordpro', 'content': '   '}));
      expect(await messageFrom(() => service.extract(_image)),
          contains('Nothing could be read'));
    });

    test('an unknown kind names the value it got', () async {
      // Whoever is debugging this wrote the backend; tell them what it said.
      final service = serviceReturning(
          json.encode({'kind': 'plaintext', 'content': 'x'}));
      expect(await messageFrom(() => service.extract(_image)),
          contains('plaintext'));
    });

    test('an unreachable endpoint reports that, not an exception type',
        () async {
      final service = HttpPhotoImportService(
        endpoint: Uri.parse('https://example.invalid/extract'),
        client: MockClient((_) async => throw const SocketishFailure()),
      );
      expect(await messageFrom(() => service.extract(_image)),
          contains('Could not reach'));
    });
  });
}

/// Stands in for the connection failures `http` surfaces on each platform —
/// SocketException on the VM, ClientException on web.
class SocketishFailure implements Exception {
  const SocketishFailure();
  @override
  String toString() => 'connection refused';
}
