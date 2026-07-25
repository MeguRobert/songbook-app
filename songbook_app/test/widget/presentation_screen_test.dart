import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/song_provider.dart';
import 'package:songbook_app/presentation/screens/presentation/presentation_screen.dart';

import 'helpers.dart';

void main() {
  Future<void> pumpPresentation(WidgetTester tester) async {
    final song = makeTestSong();
    await pumpScreen(
      tester,
      const PresentationScreen(songNumber: 42),
      overrides: [
        songByNumberProvider.overrideWith(
            (ref, number) async => number == 42 ? song : null),
      ],
    );
    // Let the song future resolve and the auto-hide timer (3s) elapse.
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('builds and shows the first verse content', (tester) async {
    await pumpPresentation(tester);
    // First page shows the first verse's structured lines.
    expect(find.textContaining('Mint a szép híves patakra'), findsWidgets);
  });

  testWidgets('unknown song renders without crashing', (tester) async {
    await pumpScreen(
      tester,
      const PresentationScreen(songNumber: 999),
      overrides: [
        songByNumberProvider.overrideWith((ref, number) async => null),
      ],
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
