import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vakil/models/chat_models.dart';
import 'package:vakil/screens/home_shell.dart';
import 'package:vakil/state/home_nav.dart';

LawyerSummary lawyer(List<String> areas) => LawyerSummary(id: areas.join(), name: 'Test', categories: areas);

void main() {
  // Practice areas lawyers pick in the Partner App, plus the test lawyer's.
  const partnerAreas = ['Civil & Family Law', 'Criminal Law', 'Corporate Law', 'Property Law', 'Labour & Service Law', 'Tax Law', 'Constitutional Law', 'Consumer Protection', 'Intellectual Property'];
  const devAreas = ['Corporate Law', 'Criminal Defense', 'Family Law', 'Employment Law', 'Real Estate Law', 'Property Law'];

  group('speciality matching', () {
    final expected = {
      Speciality.criminal: ['Criminal Law', 'Criminal Defense'],
      Speciality.family: ['Civil & Family Law', 'Family Law'],
      Speciality.business: ['Corporate Law', 'Labour & Service Law', 'Tax Law', 'Employment Law'],
      Speciality.realEstate: ['Property Law', 'Real Estate Law'],
      Speciality.medical: ['Consumer Protection'],
    };
    for (final entry in expected.entries) {
      test('${entry.key.name} matches exactly its practice areas', () {
        final matched = {...partnerAreas, ...devAreas}.where((area) => entry.key.matches(lawyer([area]))).toSet();
        expect(matched, entry.value.toSet());
      });
    }
    test('Legal Specialist matches every lawyer', () {
      for (final area in partnerAreas) {
        expect(Speciality.all.matches(lawyer([area])), isTrue);
      }
    });
  });

  testWidgets('each home speciality opens the Lawyers tab with its filter, and Back returns Home', (tester) async {
    // The test font draws every letter as a wide square, so some older home
    // rows overflow here but not on phones; ignore only those layout warnings.
    final original = FlutterError.onError;
    FlutterError.onError = (details) { if (!details.toString().contains('overflowed')) original?.call(details); };
    addTearDown(() => FlutterError.onError = original);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump(const Duration(milliseconds: 200));

    const cards = {
      'Legal\nSpecialist': null,
      'Criminal\nLaw': 'Criminal Law',
      'Family\nLaw': 'Family Law',
      'Business\nLaw': 'Business Law',
      'Real\nEstate': 'Real Estate',
      'Medical\nMalpractice': 'Medical Malpractice',
    };
    for (final entry in cards.entries) {
      expect(HomeNav.tab.value, HomeNav.home, reason: 'starts on Home before ${entry.key}');
      await tester.ensureVisible(find.text(entry.key));
      await tester.pump();
      await tester.tap(find.text(entry.key));
      await tester.pump(const Duration(milliseconds: 200));
      expect(HomeNav.tab.value, HomeNav.lawyers, reason: '${entry.key} opens the Lawyers tab');
      expect(HomeNav.speciality.value?.name, entry.value, reason: '${entry.key} filter');
      if (entry.value != null) {
        expect(find.widgetWithText(InputChip, entry.value!), findsOneWidget, reason: 'chip for ${entry.value}');
      } else {
        expect(find.byType(InputChip), findsNothing, reason: 'Legal Specialist shows every lawyer');
      }
      // Back returns to the home screen.
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 200));
      expect(HomeNav.tab.value, HomeNav.home, reason: 'Back after ${entry.key}');
    }

    // The chip's X clears the filter.
    await tester.ensureVisible(find.text('Criminal\nLaw'));
    await tester.pump();
    await tester.tap(find.text('Criminal\nLaw'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Show all lawyers'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(HomeNav.speciality.value, isNull);
    expect(find.byType(InputChip), findsNothing);
  });
}
