import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taskio/main.dart' as app;

void main() {
  final binding =
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  SharedPreferences.setMockInitialValues({});

  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.app_links/events'),
        (MethodCall methodCall) async {
      return null;
    },
  );

  group('Taskio Integration Tests', () {
    testWidgets(
      'Application launches successfully',
          (WidgetTester tester) async {
        app.main();

        await tester.pump(
          const Duration(seconds: 15),
        );

        await tester.pumpAndSettle();

        expect(
          find.byType(MaterialApp),
          findsOneWidget,
        );
      },
    );
  });
}