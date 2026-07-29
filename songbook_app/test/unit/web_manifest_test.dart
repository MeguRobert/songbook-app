import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The installed PWA has to obey the phone, not argue with it.
///
/// `web/manifest.json` declared `"orientation": "any"`, which is the app stating
/// an orientation preference of its own. An installed PWA that does so is not
/// bound by the system rotation lock, so the song view swung into landscape on a
/// phone the user had deliberately locked to portrait.
///
/// Declaring nothing is the only value that means "whatever the device says" —
/// including a named orientation would lock it the other way, which is the same
/// mistake pointing the other direction.
void main() {
  test('the web manifest states no orientation preference', () {
    final manifest = json.decode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;

    expect(manifest.containsKey('orientation'), isFalse,
        reason: 'any value here overrides the device rotation lock');
  });

  test('and nothing else in the project locks orientation', () {
    // `SystemChrome.setPreferredOrientations` would do the same thing from Dart,
    // on every platform at once.
    final offenders = <String>[];
    for (final entry in Directory('lib').listSync(recursive: true)) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      if (entry.readAsStringSync().contains('setPreferredOrientations')) {
        offenders.add(entry.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
