// Runs PagePreprocessor over a raw 8-bit greyscale file, so the Dart port can
// be measured against the Python original on real photographs rather than only
// on synthetic test pixels.
//
//   dart run tool/preprocess_page.dart in.grey <width> <height> out.grey
import 'dart:io';
import 'dart:typed_data';

import 'package:songbook_app/domain/services/page_preprocessor.dart';

void main(List<String> args) {
  if (args.length != 4) {
    stderr.writeln('usage: preprocess_page.dart in.grey width height out.grey');
    exit(2);
  }
  final width = int.parse(args[1]);
  final height = int.parse(args[2]);
  final grey = File(args[0]).readAsBytesSync();

  const preprocessor = PagePreprocessor();
  final started = DateTime.now();
  final ghosted = preprocessor.hasShowThrough(grey, width, height);
  final detected = DateTime.now();
  final out = ghosted
      ? preprocessor.suppressShowThrough(grey, width, height)
      : grey;
  final finished = DateTime.now();

  File(args[3]).writeAsBytesSync(Uint8List.fromList(out));
  stderr.writeln('show-through: $ghosted   '
      'detect ${detected.difference(started).inMilliseconds}ms   '
      'suppress ${finished.difference(detected).inMilliseconds}ms');
}
