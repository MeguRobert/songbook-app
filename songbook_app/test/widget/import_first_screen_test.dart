import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';

import 'helpers.dart';

/// What the import screen offers before you have done anything.
///
/// This file replaces `import_more_ways_test.dart`, which pinned a structure
/// that is gone. Paste and "MusicXML file" once sat side by side; the file
/// picker was then demoted behind a "More ways to add" expander, and the Photo
/// button was put in there beside it.
///
/// Both of those were wrong in the same way. The songs being added are in
/// books — a hymnal nobody digitised — and a book is *photographed*. MusicXML
/// needs a score exported from MuseScore first, which is the rarest path there
/// is, and it was the one with a name on the first screen while the camera hid
/// two taps away.
///
/// So: Paste and Photo, both first-class, nothing to open. The MusicXML *upload*
/// is gone entirely — `MusicXmlImporter` stays, because the sheet-music photo
/// path comes back as MusicXML from the engraving service and the notation
/// editor still imports files, but neither of those is a button here.
void main() {
  Future<void> pumpImport(WidgetTester tester) async {
    await pumpScreen(tester, const ImportSongScreen());
    await tester.pumpAndSettle();
  }

  testWidgets('the paste box and Parse are visible without any digging',
      (tester) async {
    await pumpImport(tester);

    expect(find.text('PASTE THE SONG'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Parse'), findsOneWidget);
  });

  testWidgets('Photo is on the first screen too', (tester) async {
    await pumpImport(tester);

    expect(find.text('Photo'), findsOneWidget);
  });

  testWidgets('there is no expander to open', (tester) async {
    await pumpImport(tester);

    expect(find.text('More ways to add'), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsNothing);
  });

  testWidgets('the MusicXML upload is gone', (tester) async {
    await pumpImport(tester);

    expect(find.text('MusicXML file'), findsNothing);
  });

  testWidgets('the sheet-music question is under the button it changes',
      (tester) async {
    // The checkbox used to live inside the expander with the Photo button. It
    // has to stay next to it: it decides which of two engines reads the page,
    // and only the person holding the camera can see which kind of page it is.
    await pumpImport(tester);

    expect(find.text('This page has sheet music'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('the curl warning is never orphaned', (tester) async {
    // Worth more than any code on this screen: a curled page took a reading from
    // 63 notes to 6, because staff detection needs straight lines. It used to be
    // reachable only with the expander open AND the checkbox ticked. Now one
    // hint line is always present and swaps to the curl warning when it applies.
    await pumpImport(tester);

    expect(find.textContaining('words and chords on the page'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.textContaining('Press the book flat'), findsOneWidget);
  });

  // The editing path is this same screen with a song already in it, so it gets
  // the same two buttons by construction - the test the old file had for that
  // pumped the plain screen and asserted the expander existed, which proved
  // nothing about editing. Covered where editing is actually exercised, in
  // import_song_screen_test.dart.
}
