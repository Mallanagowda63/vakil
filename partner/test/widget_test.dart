import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vakil_partner/main.dart';
import 'package:vakil_partner/models/dashboard_data.dart';

void main() {
  testWidgets('App launches, shows splash, then the sign-in screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(VakilPartnerApp(dashboard: DashboardController()));

    expect(find.text('Vakil Partner'), findsOneWidget);

    // Let the splash screen's navigation timer fire and settle on the
    // sign-in screen.
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
  });
}
