import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/setlists/setlists_screen.dart';

import '../../widget/helpers.dart';

Future<void> pumpScreen(WidgetTester tester, SharedPreferences prefs) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: localizedApp(const SetlistsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the empty state when there are no setlists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpScreen(tester, prefs);

    expect(find.text('No setlists yet'), findsOneWidget);
  });

  testWidgets('creating a setlist adds it to the list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await pumpScreen(tester, prefs);

    // Open the create dialog via the FAB.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sunday Morning');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Sunday Morning'), findsOneWidget);
    expect(find.text('0 songs'), findsOneWidget);
  });
}
