import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// What a photo-import backend returned.
///
/// Two kinds, because the app already has a consumer for each: ChordPro goes
/// to `ChordSheetParser`, MusicXML to `MusicXmlImporter`. Photographing a chord
/// sheet and photographing an engraved score are the same gesture with
/// different output, so they share one contract rather than one endpoint each —
/// and the sheet-music version needs no new app code, only a backend that
/// answers `musicxml`.
sealed class PhotoImportPayload {
  /// Non-fatal problems the backend wants surfaced — a page it could only
  /// partly read, a guess it had to make. Shown next to the parser's own
  /// warnings on the review screen.
  final List<String> warnings;

  const PhotoImportPayload({this.warnings = const []});
}

/// Lyrics and chords as ChordPro text.
class ChordProPayload extends PhotoImportPayload {
  final String text;

  const ChordProPayload(this.text, {super.warnings});
}

/// An engraved score as MusicXML.
class MusicXmlPayload extends PhotoImportPayload {
  final String xml;

  const MusicXmlPayload(this.xml, {super.warnings});
}

/// A photo import that failed in a way worth telling the user about.
///
/// Carries a plain sentence rather than a status code: every one of these is
/// displayed, and "the server said 502" helps nobody holding a phone.
class PhotoImportException implements Exception {
  final String message;

  /// The HTTP status behind this, where there was one.
  ///
  /// Carried for exactly one reason: a refused sign-in is the single failure the
  /// app can word better than the service can. The service answers in English,
  /// and the app knows which of three languages the person reading it speaks.
  /// Everything else is shown as [message], because the backend's own words
  /// beat any translation of a status code.
  final int? statusCode;

  const PhotoImportException(this.message, {this.statusCode});

  @override
  String toString() => 'PhotoImportException: $message';
}

/// Turns a photograph of a song into something the app can parse.
///
/// An interface, not a single implementation, because *where* this runs is
/// deliberately not the app's decision — it could be a vision model behind a
/// proxy, a machine on the user's own network, or a serverless function. The
/// app only needs the answer to arrive in one of the two shapes above.
abstract class PhotoImportService {
  Future<PhotoImportPayload> extract(Uint8List imageBytes, {String? fileName});
}

/// Posts the image to a user-configured HTTP endpoint.
///
/// The endpoint is configured rather than compiled in for two reasons: this is
/// a static PWA, so a key shipped in the bundle would be public; and the
/// hosting question is genuinely undecided, so hard-coding one answer would
/// have to be undone. The user points this at whatever they end up running.
///
/// Wire format — request is `multipart/form-data` with the image under `image`;
/// response is JSON:
///
/// ```json
/// { "kind": "chordpro" | "musicxml", "content": "…", "warnings": ["…"] }
/// ```
class HttpPhotoImportService implements PhotoImportService {
  final Uri endpoint;

  /// Sent as `Authorization: Bearer <token>` when present. Optional, because a
  /// service on the user's own network may not need one.
  final String? token;

  /// Injectable so tests can drive this without a socket.
  final http.Client _client;

  /// Generous, because these backends are cold-starting a model, not serving a
  /// cached page. Still bounded: without it a dead endpoint hangs the screen
  /// with a spinner and no way back.
  final Duration timeout;

  HttpPhotoImportService({
    required this.endpoint,
    this.token,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  }) : _client = client ?? http.Client();

  @override
  Future<PhotoImportPayload> extract(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    if (imageBytes.isEmpty) {
      throw const PhotoImportException('That image is empty.');
    }

    final request = http.MultipartRequest('POST', endpoint)
      ..files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName ?? 'photo.jpg',
      ));
    if (token != null && token!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on Exception catch (_) {
      // Covers no network, DNS failure, refused connection and the timeout —
      // from the user's side these are one situation: it did not answer.
      //
      // The exception itself is deliberately not appended. `ClientException`
      // carries the URI it failed on, which put the reader's address in front
      // of a user who has no use for it, and read as a fault in the app rather
      // than in the connection.
      throw const PhotoImportException(
        'Could not reach the reading service. Check your connection and try '
        'again.',
      );
    }

    if (response.statusCode != 200) {
      // The backend explains itself in `error` — "No API key", "cannot decode
      // that image". Reporting only the number threw that away and left the
      // person who wrote the backend guessing at their own error message.
      throw PhotoImportException(
        _reason(response),
        statusCode: response.statusCode,
      );
    }

    return _decode(response.body);
  }

  /// What went wrong, preferring the service's own words to its status code.
  String _reason(http.Response response) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } catch (_) {
      // Not JSON, or no `error` in it. Fall through to the status code.
    }
    return 'The import service returned ${response.statusCode}.';
  }

  PhotoImportPayload _decode(String body) {
    final Object? decoded;
    try {
      decoded = json.decode(body);
    } catch (_) {
      throw const PhotoImportException(
        'The import service did not return JSON.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PhotoImportException(
        'The import service returned an unexpected response.',
      );
    }

    final content = decoded['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const PhotoImportException(
        'Nothing could be read from that photo.',
      );
    }

    final warnings = switch (decoded['warnings']) {
      final List<dynamic> list => list.map((w) => '$w').toList(),
      _ => const <String>[],
    };

    return switch (decoded['kind']) {
      'chordpro' => ChordProPayload(content, warnings: warnings),
      'musicxml' => MusicXmlPayload(content, warnings: warnings),
      // Naming the value is deliberate: the most likely cause is a backend
      // returning something slightly off, and the person debugging it is the
      // one who wrote that backend.
      final Object? other => throw PhotoImportException(
          'The import service reported an unknown result type "$other".',
        ),
    };
  }
}
