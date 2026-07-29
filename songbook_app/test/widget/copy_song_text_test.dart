import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/song_view/song_view_screen.dart';
import 'package:songbook_app/presentation/screens/song_view/widgets/chord_view.dart';

import 'helpers.dart';

/// Getting words out of the app.
///
/// Reported as "I cannot copy from the app when chord view for example, I cannot
/// select text". Every line was a plain `Text`, which paints characters and
/// offers no selection at all, so there was no way to get a verse into a message
/// or a service sheet.
///
/// Two answers, because they solve different problems: a selection layer for
/// taking one line, and a copy action for taking the whole song without dragging
/// across a phone screen.

Future<void> pumpSongView(WidgetTester tester) async {
  await pumpScreen(
    tester,
    SongViewScreen(songId: makeTestSong().id),
    prefs: const {'settings_view_config': 'false:true'},
    overrides: [
      songByIdProvider.overrideWith((ref, id) async =>
          id == makeTestSong().id ? makeTestSong() : null),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the words sit inside a selection layer', (tester) async {
    await pumpSongView(tester);

    // SelectionArea is what makes every descendant Text selectable, and it spans
    // them — so a drag can take a whole verse, not one line at a time.
    expect(
      find.ancestor(
        of: find.textContaining('Mint a szép híves patakra'),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ChordView),
        matching: find.byType(SelectionArea),
      ),
      findsWidgets,
    );
  });

  group('copy the whole song', () {
    testWidgets('is offered in the overflow menu', (tester) async {
      await pumpSongView(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Dragging a selection across every verse of a hymn on a phone is not a
      // realistic way to copy a song.
      expect(find.text('Copy song text'), findsOneWidget);
    });

    testWidgets('puts the song on the clipboard as ChordPro', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpSongView(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy song text'));
      await tester.pumpAndSettle();

      expect(copied, isNotNull);
      // ChordPro, because it is the format the paste importer already reads:
      // what comes out of the app can go back into it.
      expect(copied, contains('{title: Mint a szép híves patakra}'));
      expect(copied, contains('[Bb]Mint a szép híves patakra'));
      expect(copied, contains('A szarvas kívánkozik'));
      // The plain-text second verse comes along too.
      expect(copied, contains('Second verse plain text'));
      // And the user is told it happened.
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
