import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/data/models/view_config.dart';
import 'package:songbook_app/presentation/screens/song_view/widgets/song_controls_sheet.dart';

import 'helpers.dart';

/// UAT findings about the controls sheet itself.

Future<void> pumpControls(
  WidgetTester tester, {
  String viewConfig = 'false:true',
  double width = 412,
}) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: SizedBox(
        width: width,
        child: SongControlsSheet(originalKey: 'C'),
      ),
    ),
    prefs: {'settings_view_config': viewConfig},
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the VIEW row', () {
    testWidgets('shows no checkmark on the selected preset', (tester) async {
      await pumpControls(tester);

      // The checkmark appears only on the selected chip, so the row's width
      // changed every time the preset changed — and it cost horizontal space in
      // a row that has to hold three labelled chips on a phone. The chip's own
      // fill already says which one is selected.
      for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
        expect(chip.showCheckmark, isFalse);
      }
    });

    testWidgets('keeps the three labels short enough to share a row',
        (tester) async {
      // Deliberately NOT a pixel assertion. Widget tests substitute a font whose
      // every glyph is a full em, so "Sheet Music" measures ~50% wider here than
      // in Roboto — a width check would fail against layout that is fine, and
      // pass against layout that is not. What is testable is the decision:
      // three one-word labels, no checkmark, compact density. The pixels get
      // checked in a browser at 412 px.
      await pumpControls(tester);

      for (final label in ['Sheet', 'Chords', 'Lyrics']) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
        expect(label.contains(' '), isFalse, reason: 'one word each');
      }
      expect(find.widgetWithText(ChoiceChip, 'Sheet Music'), findsNothing);
      for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
        expect(chip.visualDensity, VisualDensity.compact);
      }
    });
  });

  group('"Chords above staff"', () {
    testWidgets('leaves Sheet Music selected when chords are turned off',
        (tester) async {
      // The bug: ViewConfig is two booleans and the three presets claimed only
      // three of the four combinations. Turning chords off inside Sheet Music
      // produced (notation: true, chords: false) — which matched NO preset, so
      // all three chips went unselected and the sheet stopped saying where you
      // were.
      await pumpControls(tester, viewConfig: 'true:true');

      final sheetMusic = find.widgetWithText(ChoiceChip, 'Sheet');
      expect(tester.widget<ChoiceChip>(sheetMusic).selected, isTrue);

      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();

      expect(tester.widget<ChoiceChip>(sheetMusic).selected, isTrue,
          reason: 'still the Sheet Music preset, just without chord symbols');
      expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Chords'))
              .selected,
          isFalse);
      expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Lyrics'))
              .selected,
          isFalse);
    });

    test('the presets cover every state ViewConfig can hold', () {
      // Exhaustive, because the gap above was one uncovered combination out of
      // four and nothing said so.
      for (final notation in [true, false]) {
        for (final chords in [true, false]) {
          final config =
              ViewConfig(showNotation: notation, showChords: chords);
          final matched = [
            config.isSheetMusicPreset,
            config.isChordsPreset,
            config.isLyricsOnlyPreset,
          ].where((m) => m).length;
          expect(matched, 1,
              reason: 'notation: $notation, chords: $chords matched $matched '
                  'presets — every state must match exactly one');
        }
      }
    });
  });

  group('starting auto-scroll', () {
    testWidgets('closes the sheet so the song is visible', (tester) async {
      // Auto-scroll starts scrolling text that the sheet is sitting on top of.
      // Watching a covered song scroll is not a feature.
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => const SongControlsSheet(originalKey: 'C'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        prefs: const {'settings_view_config': 'false:true'},
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SongControlsSheet), findsOneWidget);

      // AUTO-SCROLL is the last section of a scrollable sheet, so it starts
      // below the fold — tapping without scrolling to it hits whatever happens
      // to be at those coordinates instead.
      final start = find.byTooltip('Start auto-scroll');
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      await tester.pumpAndSettle();

      expect(find.byType(SongControlsSheet), findsNothing);
    });

  });
}
