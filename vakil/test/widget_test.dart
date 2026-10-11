import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vakil/main.dart';
import 'package:vakil/widgets/app_logo.dart';

void main() {
  testWidgets('Vakil app boots on splash then advances to sign-in',
      (WidgetTester tester) async {
    // Pre-agree to Terms & Privacy so the gate hands off to the splash
    // screen immediately instead of showing the consent UI.
    SharedPreferences.setMockInitialValues({'terms_agreed': true});

    await tester.pumpWidget(const VakilApp());

    // Let the terms gate's async bootstrap resolve and push the splash
    // screen on top before asserting anything about it.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AppLogo), findsOneWidget);

    // The splash screen waits on SharedPreferences + a minimum delay before
    // navigating; step through in small increments rather than one big
    // pump (a single pump only processes one frame even if the timer
    // fires mid-duration) or pumpAndSettle (can decide things have
    // settled before the delayed navigation timer actually fires).
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
