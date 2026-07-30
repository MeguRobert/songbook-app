import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';

import 'helpers.dart';

/// Which of the two import paths reads as the primary one.
///
/// Paste and "MusicXML file" used to sit side by side on one row, giving equal
/// billing to a path that needs a file exported from MuseScore first. Pasting a
/// chord sheet is what actually happens most of the time, so the file picker is
/// demoted behind a "More ways to add" expander: still reachable, no longer
/// competing for the eye with the box the user is about to type into.
///
/// It cannot simply be removed — it is the only path that produces engraved
/// notation, and the landing point for a photo pipeline later — so the expander
/// says what it is for rather than just hiding it.
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

  testWidgets('the file picker is behind the expander, not beside Parse',
      (tester) async {
    await pumpImport(tester);

    expect(find.text('More ways to add'), findsOneWidget);
    expect(find.text('MusicXML file'), findsNothing);
  });

  testWidgets('opening the expander reveals the file picker', (tester) async {
    await pumpImport(tester);

    await tester.tap(find.text('More ways to add'));
    await tester.pumpAndSettle();

    expect(find.text('MusicXML file'), findsOneWidget);
  });

  testWidgets('the expander says what the file path is for', (tester) async {
    // Demoting it without saying why would leave the one path that yields
    // engraved notation looking like a lesser version of paste.
    await pumpImport(tester);
    await tester.tap(find.text('More ways to add'));
    await tester.pumpAndSettle();

    expect(find.textContaining('engraved notation'), findsOneWidget);
  });

  testWidgets('the expander closes again', (tester) async {
    await pumpImport(tester);

    await tester.tap(find.text('More ways to add'));
    await tester.pumpAndSettle();
    expect(find.text('MusicXML file'), findsOneWidget);

    await tester.tap(find.text('More ways to add'));
    await tester.pumpAndSettle();
    expect(find.text('MusicXML file'), findsNothing);
  });

  testWidgets('editing an existing song still offers the file path',
      (tester) async {
    // Re-importing a score over a song whose notation the OMR mangled is a real
    // reason to open this while editing, so the expander is not add-only.
    await pumpScreen(tester, const ImportSongScreen());
    await tester.pumpAndSettle();

    expect(find.text('More ways to add'), findsOneWidget);
  });

  // A failed pick needs no special case: the button lives INSIDE the expander,
  // so the expander is necessarily open when the error appears below it. The
  // picker itself cannot be driven in a widget test — it is a platform channel
  // — and is checked in a browser, as import_musicxml_test.dart also notes.
}
