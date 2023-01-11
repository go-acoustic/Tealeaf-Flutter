import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tl_flutter_plugin/tl_flutter_plugin.dart';
import 'package:tl_flutter_plugin_example/main.dart' as app;

void main() {
  group('App Test', () {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();

    group("Full app test", () {
      testWidgets("Floating Button Test", ((tester) async {
        app.main();
        await tester.pumpAndSettle(Duration(seconds: 2));
        final floatingButton = find.byKey(Key("floatingButton"));
        await tester.tap(floatingButton);
        await tester.pump(Duration(seconds: 2));
        expect(find.text("Taps: 1"), findsOneWidget);
        await Future.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }));

      testWidgets("Pinch Radio Test", ((tester) async {
        app.main();
        await tester.pumpAndSettle(Duration(seconds: 2));
        final pinchRadio = find.byKey(Key("PinchRadio"));
        await tester.tap(pinchRadio);
        await tester.pump(Duration(seconds: 5));

        await Future.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }));

      testWidgets("Swipe Radio Test", ((tester) async {
        app.main();
        await tester.pumpAndSettle(Duration(seconds: 2));
        final swipeRadio = find.byKey(Key("swipeRadio"));
        await tester.tap(swipeRadio);
        await tester.pump(Duration(seconds: 2));

        await Future.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }));

      testWidgets("Elevated Button Test", ((tester) async {
        app.main();
        await tester.pumpAndSettle(Duration(seconds: 2));
        final elevatedButton = find.byKey(Key("httpGet"));
        await tester.tap(elevatedButton);
        await tester.pump(Duration(seconds: 2));
        expect(find.text("Http list size: 100"), findsOneWidget);

        await Future.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }));

      testWidgets("Gesture Button Test ", ((tester) async {
        app.main();
        await tester.pumpAndSettle(Duration(seconds: 2));
        final gestureButton = find.byKey(Key("GestureButton"));

        await tester.dragUntilVisible(
            gestureButton, // what you want to find
            find.byType(GestureDetector),
            // widget you want to scroll
            const Offset(0, 50), // delta to move
            duration: Duration(seconds: 2));
        await tester.pump(Duration(seconds: 2));

        await tester.tap(gestureButton);
        await tester.pump(Duration(seconds: 2));
        expect(find.text("Taps: 2"), findsOneWidget);

        // Scroll back up
        await tester.pumpAndSettle(Duration(seconds: 2));
        final owlImage = find.byKey(Key("owlImage"));

        await tester.dragUntilVisible(
            owlImage, // what you want to find
            find.byType(Image),
            // widget you want to scroll
            const Offset(-50, 0), // delta to move
            duration: Duration(seconds: 2));
        await tester.pump(Duration(seconds: 2));

        await Future.delayed(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }));
    });
  });
}
