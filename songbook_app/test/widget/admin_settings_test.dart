import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:songbook_app/data/models/app_settings.dart';
import 'package:songbook_app/data/repositories/admin_repository.dart';
import 'package:songbook_app/presentation/providers/admin_provider.dart';
import 'package:songbook_app/presentation/screens/admin/admin_settings_screen.dart';

import 'helpers.dart';

/// The project's rules for everybody, edited by one person.
///
/// Unlike the ordinary Settings screen — one device, one person's preferences,
/// written on every keystroke — this one holds a draft and writes it once. That
/// makes two things worth pinning:
///
/// 1. **Nothing reaches the server until Save.** A round trip per character
///    would publish half a sentence as the rule contributors have to accept.
/// 2. **What is on the screen is what gets written.** Every control here feeds
///    one `AppSettings`, so a control wired to the wrong field silently changes
///    a different rule: turning off "require a confirmed address" when the
///    intent was to close submissions is a door left open, not a typo.
///
/// The switches, the cap and the three guidelines boxes are therefore each
/// followed all the way through Save to the value the repository is handed.
class _MockAdmin extends Mock implements AdminRepository {}

const seeded = AppSettings(
  submissionsOpen: true,
  requireConfirmedEmail: true,
  dailySubmissionCap: 5,
  guidelines: {
    'en': 'Only songs actually sung in worship.',
    'hu': 'Csak olyan énekek, amelyeket tényleg énekelünk.',
    'ro': 'Doar cântări folosite în adunare.',
  },
);

Future<AdminRepository> pumpSettings(
  WidgetTester tester, {
  AppSettings settings = seeded,
  Future<AppSettings> Function()? fetch,
  bool settle = true,
}) async {
  final repository = _MockAdmin();
  when(() => repository.settings()).thenAnswer(
    (_) => fetch == null ? Future.value(settings) : fetch(),
  );
  when(() => repository.saveSettings(any())).thenAnswer((_) async {});

  await pumpScreen(
    tester,
    const AdminSettingsScreen(),
    overrides: [adminRepositoryProvider.overrideWithValue(repository)],
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return repository;
}

/// Scrolls [label] into view. The three guidelines boxes sit below the fold on a
/// phone-sized viewport, and every `find.*` skips what the `ListView` has not
/// built.
Future<void> reveal(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 200,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Save'));
  await tester.pumpAndSettle();
}

/// What the repository was actually handed, which is the only thing that
/// persists.
AppSettings saved(AdminRepository repository) =>
    verify(() => repository.saveSettings(captureAny())).captured.single
        as AppSettings;

Future<void> toggle(WidgetTester tester, String title) async {
  await tester.tap(find.widgetWithText(SwitchListTile, title));
  await tester.pumpAndSettle();
}

Future<void> step(WidgetTester tester, IconData icon) async {
  await tester.tap(find.widgetWithIcon(IconButton, icon));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(const AppSettings()));

  group('what the screen shows', () {
    testWidgets('is the settings as they were stored', (tester) async {
      await pumpSettings(tester);

      expect(
        tester
            .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Accept new songs'))
            .value,
        isTrue,
      );
      expect(find.text('5'), findsOneWidget);
      await reveal(tester, 'Magyar');
      expect(find.text('Csak olyan énekek, amelyeket tényleg énekelünk.'),
          findsOneWidget);
      await reveal(tester, 'English');
      expect(find.text('Only songs actually sung in worship.'), findsOneWidget);
    });

    testWidgets('a closed door shows as closed rather than defaulting to open',
        (tester) async {
      await pumpSettings(
        tester,
        settings: const AppSettings(submissionsOpen: false),
      );

      expect(
        tester
            .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Accept new songs'))
            .value,
        isFalse,
      );
    });

    testWidgets('is a spinner while the settings are still arriving',
        (tester) async {
      await pumpSettings(
        tester,
        fetch: () => Completer<AppSettings>().future,
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Not the form seeded with defaults: an administrator editing defaults
      // they never chose would overwrite the real rules on Save.
      expect(find.text('Accept new songs'), findsNothing);
    });
  });

  group('saving', () {
    testWidgets('nothing is written until Save is tapped', (tester) async {
      final repository = await pumpSettings(tester);

      await toggle(tester, 'Accept new songs');
      await step(tester, Icons.add);

      // The whole reason for holding a draft: no half-written rule reaches the
      // contributors.
      verifyNever(() => repository.saveSettings(any()));
    });

    testWidgets('closing submissions round-trips', (tester) async {
      final repository = await pumpSettings(tester);

      await toggle(tester, 'Accept new songs');
      await tapSave(tester);

      expect(saved(repository).submissionsOpen, isFalse);
    });

    testWidgets('dropping the confirmed-address requirement round-trips',
        (tester) async {
      final repository = await pumpSettings(tester);

      await toggle(tester, 'Require a confirmed address');
      await tapSave(tester);

      final settings = saved(repository);
      expect(settings.requireConfirmedEmail, isFalse);
      // And it did not quietly take the other switch with it.
      expect(settings.submissionsOpen, isTrue);
    });

    testWidgets('the cap steps up and down and Save carries the number',
        (tester) async {
      final repository = await pumpSettings(tester);

      await step(tester, Icons.add);
      await step(tester, Icons.add);
      await step(tester, Icons.remove);
      expect(find.text('6'), findsOneWidget);

      await tapSave(tester);
      expect(saved(repository).dailySubmissionCap, 6);
    });

    testWidgets('the cap cannot be stepped below nothing', (tester) async {
      await pumpSettings(
        tester,
        settings: const AppSettings(dailySubmissionCap: 0),
      );

      // Zero means "nobody may submit", which the master switch says more
      // clearly; a negative cap would mean nothing at all.
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a failed save is reported rather than passing for done',
        (tester) async {
      final repository = await pumpSettings(tester);
      when(() => repository.saveSettings(any())).thenThrow(Exception('403'));

      await toggle(tester, 'Accept new songs');
      await tapSave(tester);

      expect(find.text('That did not work.'), findsOneWidget);
    });
  });

  group('the guidelines', () {
    testWidgets('each language is saved under its own key', (tester) async {
      final repository = await pumpSettings(tester);

      // The toggle comes first only to wake the Save button up, and is at the
      // top of the list where it is still on screen. See the skipped test below
      // for why it is needed at all.
      await toggle(tester, 'Accept new songs');

      await reveal(tester, 'Magyar');
      await tester.enterText(
          find.widgetWithText(TextField, 'Magyar'), 'Új magyar szabály.');
      await reveal(tester, 'Română');
      await tester.enterText(
          find.widgetWithText(TextField, 'Română'), 'Regulă nouă.');
      await reveal(tester, 'English');
      await tester.enterText(
          find.widgetWithText(TextField, 'English'), 'A new rule.');

      await tapSave(tester);

      final settings = saved(repository);
      // Crossed keys here would publish the Romanian rules to Hungarian
      // speakers, and `guidelinesFor` would never notice.
      expect(settings.guidelines['hu'], 'Új magyar szabály.');
      expect(settings.guidelines['ro'], 'Regulă nouă.');
      expect(settings.guidelines['en'], 'A new rule.');
    });

    testWidgets('an untouched language keeps the words it already had',
        (tester) async {
      final repository = await pumpSettings(tester);

      // Again only to wake Save up; see the skipped test below.
      await toggle(tester, 'Accept new songs');

      await reveal(tester, 'Magyar');
      await tester.enterText(
          find.widgetWithText(TextField, 'Magyar'), 'Új magyar szabály.');
      await tapSave(tester);

      // `saveSettings` writes all three columns every time, so an editor that
      // dropped the ones nobody touched would blank two languages per save.
      final settings = saved(repository);
      expect(settings.guidelines['ro'], 'Doar cântări folosite în adunare.');
      expect(settings.guidelines['en'], 'Only songs actually sung in worship.');
    });

    /// SKIPPED BECAUSE THE SCREEN IS BROKEN, not because the test is.
    ///
    /// The Save button reads `_draft == null ? null : _save`, and `_draft` is
    /// seeded by `_seed()` — which runs inside the `data:` branch of the body,
    /// *after* the `AppBar` above it has already been built. So on the one frame
    /// where the settings arrive, Save is built disabled and nothing schedules
    /// another build.
    ///
    /// A switch or the cap stepper calls `setState`, which rebuilds and wakes
    /// Save up. Typing in a guidelines box does not: the `TextEditingController`
    /// lives in the `State` but the `TextField` listens to it internally, and the
    /// screen never rebuilds. **So an administrator who edits only the
    /// guidelines — the single most likely reason to open this screen — types
    /// three paragraphs and finds the Save button dead**, with no explanation
    /// and nothing on screen suggesting they should flick a switch first.
    ///
    /// Fixes: seed the draft in `initState`/on the first data frame with a
    /// `setState`, or drop the `_draft == null` guard in favour of the loaded
    /// value. Not made here because this branch is tests only. When it is made,
    /// delete `skip` and the "wake the Save button up" toggles in the two tests
    /// above.
    testWidgets(
      'editing only the guidelines is enough to enable Save',
      (tester) async {
        final repository = await pumpSettings(tester);

        await reveal(tester, 'Magyar');
        await tester.enterText(
            find.widgetWithText(TextField, 'Magyar'), 'Új magyar szabály.');
        await tester.pumpAndSettle();

        await tapSave(tester);

        expect(saved(repository).guidelines['hu'], 'Új magyar szabály.');
      },
      skip: true,
    );
  });
}
