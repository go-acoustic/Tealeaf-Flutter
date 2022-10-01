// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tl_flutter_plugin_example/main.dart';

void main() {
  testWidgets('Verify Platform Version Widget', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that platform version is retrieved.
    expect(
      find.byWidgetPredicate((Widget widget) {
        bool match = false;
        if (widget != null && widget is Text) {
          final String text = widget.data;

          match = text.startsWith('Running on:');
          if (match) {
            print('Widget text found: $text');
          }
        }
        return match;
      }
      /*
        (Widget widget) => widget != null && widget is Text &&
                           widget.data.startsWith('Running on:'),
      */
      ),
      findsOneWidget,
    );
  });
}
