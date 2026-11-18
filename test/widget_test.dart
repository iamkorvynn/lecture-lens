import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecture_lens/screens/home_screen.dart';
import 'package:lecture_lens/screens/onboarding_screen.dart';
import 'package:lecture_lens/services/database_helper.dart';

import 'test_setup.dart';

void main() {
  setUpAll(setupTestDb);
  // Open the database here, in real time: inside a testWidgets body the
  // fake-async zone can stall the path_provider method-channel call that
  // resolves the database path. With the database already open, the
  // screens' queries complete with ordinary pumps.
  setUpAll(() async {
    await DatabaseHelper.instance.database;
  });

  testWidgets('onboarding explains the flow and advances pages',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen()),
    );

    expect(find.text('Record the lecture'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Read it back, add your notes'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text('Summarise with your own Gemini key'),
      findsOneWidget,
    );
    expect(find.text('Start recording'), findsOneWidget);
  });

  testWidgets('home screen starts empty with a record call to action',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );
    // The lecture list loads from a real SQLite database; let that I/O
    // finish in real time, then rebuild. (The loading spinner animates
    // continuously, so pumpAndSettle would never return.)
    await tester.runAsync(
      () async => await Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.text('LectureLens'), findsOneWidget);
    expect(find.text('No lectures yet'), findsOneWidget);
    expect(find.text('Record lecture'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
