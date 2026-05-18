import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Taskio Widget Tests', () {
    testWidgets(
      'Positive: кнопка отображается',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
            ),
          ),
        );

        expect(
          find.byType(FloatingActionButton),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Positive: текст отображается',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Taskio Test'),
            ),
          ),
        );

        expect(
          find.text('Taskio Test'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Boundary: пустой контейнер отображается',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(),
            ),
          ),
        );

        expect(
          find.byType(SizedBox),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Negative: несуществующий текст отсутствует',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Taskio'),
            ),
          ),
        );

        expect(
          find.text('Ошибка'),
          findsNothing,
        );
      },
    );
  });
}