import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/domain/services/musicxml_importer.dart';

/// Real Audiveris output, with the one shape that took the renderer down.
///
/// The fixture starts as `tools/audiveris_output/zsolt-090.width-800.xml` — an
/// actual optical-music-recognition result — and moves the notes of its second
/// measure into a voice that is not the melody. The app renders the melody
/// only, so that measure has to arrive with nothing in it, which is exactly
/// what a photographed page of song 151 produced and what
/// `beamGroups.reduce` threw on.
void main() {
  const importer = MusicXmlImporter();

  String fixture() => File('test/fixtures/score_with_offmelody_bar.musicxml')
      .readAsStringSync();

  test('Audiveris output carries no title, which is why the box was empty',
      () async {
    final result = importer.importXml(fixture());
    expect(result.title, isNull,
        reason: 'Audiveris reads staves, not headings — so the app has to get '
            'the heading from somewhere else');
  });

  test('a bar whose notes are all off the melody arrives with no beats',
      () async {
    final result = importer.importXml(fixture());
    final measures = result.notation.verses.expand((v) => v.measures).toList();
    expect(measures, isNotEmpty);
    expect(
      measures.where((m) => m.beats.isEmpty),
      isNotEmpty,
      reason: 'this is the shape the renderer must survive; if this ever '
          'fails, the importer changed and the regression it guards moved',
    );
  });
}
