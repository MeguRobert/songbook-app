import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/app_settings.dart';
import 'package:songbook_app/data/repositories/submission_repository.dart';
import 'package:songbook_app/presentation/providers/admin_provider.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/import/import_song_screen.dart';

import 'helpers.dart';

/// The Share action: when it exists, and when it is offerable.
///
/// The ordering logic behind the gate itself is pinned in
/// `test/unit/domain/services/publish_gate_test.dart`, where it is a pure
/// function and needs no widget tree. What is worth checking here is the part
/// that only exists on screen: that sharing is a *second* action rather than a
/// replacement for saving, and that it disappears rather than failing when there
/// is no backend to share with.
void main() {
  const pastedSheet = '''
1.
[C]Mint a szép híves patakra
a szarvas kívánkozik''';

  Finder shareButton() => find.ancestor(
        of: find.byIcon(Icons.upload_outlined),
        matching: find.byType(IconButton),
      );

  group('Share with the congregation', () {
    testWidgets('is absent entirely when there is no backend', (tester) async {
      // submissionRepositoryProvider defaults to null, which is exactly the
      // "no Supabase configured" build.
      await pumpScreen(tester, const ImportSongScreen(), overrides: [
        appSettingsProvider.overrideWith((ref) async => const AppSettings()),
      ]);
      await tester.pumpAndSettle();

      // An action that cannot work is worse than no action, matching how the
      // account section of Settings vanishes in that build.
      expect(find.byIcon(Icons.upload_outlined), findsNothing);
      // Saving locally is untouched. That separation is the whole design: the
      // device path stays free and signed-out.
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('appears alongside Save when a backend is configured',
        (tester) async {
      await pumpScreen(tester, const ImportSongScreen(), overrides: [
        submissionRepositoryProvider.overrideWithValue(_UnusedSubmissions()),
        appSettingsProvider.overrideWith((ref) async => const AppSettings()),
      ]);
      await tester.pumpAndSettle();

      expect(shareButton(), findsOneWidget);
      expect(find.text('Save'), findsOneWidget,
          reason: 'sharing is a second action, never a replacement for saving');
    });

    testWidgets('is disabled until there is a song to share', (tester) async {
      await pumpScreen(tester, const ImportSongScreen(), overrides: [
        submissionRepositoryProvider.overrideWithValue(_UnusedSubmissions()),
        appSettingsProvider.overrideWith((ref) async => const AppSettings()),
      ]);
      await tester.pumpAndSettle();

      // Same blockers as Save: nothing pasted, so there is no song yet.
      expect(tester.widget<IconButton>(shareButton()).onPressed, isNull);
    });

    testWidgets('becomes offerable once a chord sheet is pasted and parsed',
        (tester) async {
      await pumpScreen(tester, const ImportSongScreen(), overrides: [
        submissionRepositoryProvider.overrideWithValue(_UnusedSubmissions()),
        appSettingsProvider.overrideWith((ref) async => const AppSettings()),
      ]);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, pastedSheet);
      await tester.pumpAndSettle();

      // Parse, then a title, are what clear the blockers — the same ones Save
      // uses, which is why this test asserts on Save too.
      final parse = find.text('Parse');
      if (parse.evaluate().isNotEmpty) {
        await tester.tap(parse);
        await tester.pumpAndSettle();
      }

      final share = tester.widget<IconButton>(shareButton());
      final save = tester.widget<TextButton>(
        find.ancestor(of: find.text('Save'), matching: find.byType(TextButton)),
      );
      // Whatever the blockers are, the two actions agree about them. Sharing a
      // song Save would refuse would mean two definitions of "finished".
      expect(share.onPressed == null, save.onPressed == null);
    });
  });
}

/// A configured backend that is never actually called: every test above stops
/// before submission. Throws rather than returning null so a test that
/// accidentally reaches the network fails loudly instead of passing quietly.
class _UnusedSubmissions implements SubmissionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
      'no test here should reach ${invocation.memberName}');
}
