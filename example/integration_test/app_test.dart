import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:tl_flutter_plugin_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tealeaf example app end-to-end integration test', () {
    testWidgets(
        'tap on the floating action button, verify counter (aop insertion)',
        (tester) async {
      app.main();

      await tester.pumpAndSettle();

      // Verify the counter starts at 0.
      expect(find.text('\nTaps: 0'), findsOneWidget);

      // Finds the floating action button to tap on.
      final Finder fab =
          find.byTooltip('Increment the counter by pressing this button');

      // Emulate a tap on the floating action button.
      await tester.tap(fab);

      // Trigger a frame.
      await tester.pumpAndSettle();

      // Verify the counter increments by 1.
      expect(find.text('\nTaps: 1'), findsOneWidget);

      await tester.pump(const Duration(seconds: 0));

      expect(find.text('Http list size: 0'), findsOneWidget);

      /*
      // Finds the Elevated Button by its text to perform a tap event on parent GestureDetector.
      //final Finder eb = find.ancestor(of: find.text('http get'), matching: find.byType(ElevatedButton));
      final Finder eb = find.byType(ElevatedButton);
      expect(eb, findsOneWidget);

      // Emulate a 'press' of the elevated button.
      await tester.tap(eb);

      // Trigger a frame.
      await tester.pumpAndSettle();

      // Wait for async http response to complete
      await tester.pump(const Duration(seconds: 5));

      // Verify that the 'logged' http get returns 100 items.
      // TBD: Use aspectd to capture last http so we can check data sent to Tealeaf

      expect(find.text('Http list size: 100'), findsOneWidget);
       */
    });

    testWidgets(
        'Push "http get" button, verify 100 json objects download from "https://jsonplaceholder.typicode.com/posts"',
        (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Finds the Elevated Button by its type to perform a tap event on parent GestureDetector.
      final Finder eb = find.byType(ElevatedButton);
      expect(eb, findsOneWidget);

      // Emulate a 'press' of the elevated button (tester.press does not work?)
      await tester.tap(eb);

      // Trigger a frame.
      await tester.pumpAndSettle();

      // Wait for async http response to complete
      // TBD: Could fail on slow connection, find better way to wait
      await tester.pump(const Duration(seconds: 5));

      // Verify that the 'logged' http get returns 100 items.
      // TBD: Use aspectd to capture last http so we can check data sent to Tealeaf
      expect(find.text('Http list size: 100'), findsOneWidget);
    });
  });
}
