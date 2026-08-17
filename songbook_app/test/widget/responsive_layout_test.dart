import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songbook_app/presentation/providers/providers.dart';
import 'package:songbook_app/presentation/screens/auth/auth_screen.dart';
import 'package:songbook_app/presentation/screens/settings/settings_screen.dart';
import 'package:songbook_app/presentation/widgets/content_pane.dart';

import 'helpers.dart';

/// The desktop-web complaint, as a test.
///
/// On a 1900-wide browser window the sign-in form arrived as a metre-wide
/// "Continue with Google" button and two metre-wide text fields, because a
/// `Column` in a scroll viewport takes every pixel it is offered. A screenshot
/// proves that once; this proves it on every commit, and — the half that actually
/// matters — proves the cap does *not* fire on a phone.
///
/// Widths are asserted against [ContentWidths], not against literals, so the test
/// keeps agreeing with the app if the numbers are ever retuned. What it pins is
/// the *behaviour*: capped and centred when wide, untouched when narrow.

/// Runs [body] with the surface at [size], restoring the view afterwards.
Future<void> atWindowSize(
  WidgetTester tester,
  Size size,
  Future<void> Function() body,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await body();
}

/// Width of the first [T] on screen.
///
/// `bySubtype`, not `byType`: `OutlinedButton.icon` builds a private subclass, and
/// `byType` matches the exact runtime type only, so it finds nothing.
double widthOf<T extends Widget>(WidgetTester tester) =>
    tester.getSize(find.bySubtype<T>().first).width;

/// Makes [AuthScreen] render its form rather than "accounts unavailable".
///
/// Only the availability flag, not a fake repository: no test here presses a
/// button, so nothing needs a Supabase client, and this leaves the real auth
/// wiring alone.
final signInFormVisible = [authAvailableProvider.overrideWithValue(true)];

void main() {
  const desktop = Size(1900, 1000);
  const phone = Size(390, 844);

  group('sign-in on a desktop window', () {
    testWidgets('caps the form, and centres it', (tester) async {
      await atWindowSize(tester, desktop, () async {
        await pumpScreen(tester, const AuthScreen(),
            overrides: signInFormVisible);
        await tester.pumpAndSettle();

        // The form itself, not just the pane: a cap that the Form ignored would
        // still leave the fields metre-wide.
        final form = tester.getRect(find.byType(Form));
        expect(form.width, lessThanOrEqualTo(ContentWidths.form));
        expect(form.center.dx, closeTo(desktop.width / 2, 1));

        // The three controls that were the actual complaint.
        expect(widthOf<TextFormField>(tester),
            lessThanOrEqualTo(ContentWidths.form));
        expect(widthOf<OutlinedButton>(tester),
            lessThanOrEqualTo(ContentWidths.form));
        expect(
            widthOf<FilledButton>(tester), lessThanOrEqualTo(ContentWidths.form));
      });
    });
  });

  group('sign-in on a phone', () {
    testWidgets('still fills the width, less the padding', (tester) async {
      await atWindowSize(tester, phone, () async {
        await pumpScreen(tester, const AuthScreen(),
            overrides: signInFormVisible);
        await tester.pumpAndSettle();

        // 24 of padding a side, exactly as before the cap existed. If this
        // regresses, mobile lost horizontal space to a desktop fix.
        expect(tester.getSize(find.byType(Form)).width,
            closeTo(phone.width - 48, 0.01));
      });
    });

    testWidgets('adds no wrapper to the tree at all', (tester) async {
      await atWindowSize(tester, phone, () async {
        await pumpScreen(tester, const AuthScreen(),
            overrides: signInFormVisible);
        await tester.pumpAndSettle();

        // ContentPane returns its child untouched below the breakpoint, so no
        // Center/ConstrainedBox sits between it and the form to change how the
        // Column reads its constraints. Asserted on the element tree because the
        // form's own controls contain ConstrainedBoxes of their own, which a
        // descendant finder would happily report.
        Widget? paneChild;
        tester
            .element(find.byType(ContentPane))
            .visitChildElements((element) => paneChild = element.widget);
        expect(paneChild, isA<Form>());
      });
    });
  });

  testWidgets('a list screen is capped wider than a form', (tester) async {
    await atWindowSize(tester, desktop, () async {
      await pumpScreen(tester, const SettingsScreen());
      await tester.pumpAndSettle();

      final list = tester.getRect(find.byType(ListView));
      expect(list.width, ContentWidths.list);
      expect(list.center.dx, closeTo(desktop.width / 2, 1));
    });
  });
}
