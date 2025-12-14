// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:taskio/models/project_model.dart';
import 'package:taskio/providers/project_provider.dart';
import 'package:taskio/screens/home/project_list_screen.dart';

// Создаем мок-класс для ProjectProvider
class MockProjectProvider extends Mock implements ProjectProvider {}

void main() {
  // Регистрируем моки
  setUpAll(() {
    registerFallbackValue(MockProjectProvider());
  });

  testWidgets('ProjectListScreen отображает заголовок и FAB', (WidgetTester tester) async {
    // 1. Создаем мок-провайдер и настраиваем его поведение
    final mockProvider = MockProjectProvider();

    // Имитируем, что пользователь не гость
    when(() => mockProvider.isGuest).thenReturn(false);
    // Имитируем, что загрузка данных не идет
    when(() => mockProvider.isLoading).thenReturn(false);
    // Имитируем пустой список проектов
    when(() => mockProvider.view).thenReturn([]);

    // 2. Строим только ProjectListScreen, оборачивая его в Provider
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ProjectProvider>.value(
          value: mockProvider,
          child: const ProjectListScreen(),
        ),
      ),
    );

    // 3. Проверяем наличие ключевых элементов
    expect(find.text('Мои проекты'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('ProjectListScreen отображает список проектов', (WidgetTester tester) async {
    final mockProvider = MockProjectProvider();

    when(() => mockProvider.isGuest).thenReturn(false);
    when(() => mockProvider.isLoading).thenReturn(false);
    // Имитируем список из одного проекта
    final testProject = ProjectModel(
      id: '1',
      title: 'Тестовый проект',
      description: 'Описание',
      ownerId: 'owner_id',
      deadline: DateTime.now(),
      status: 1,
      grade: null,
      attachments: const [],
      participantsData: const [],
      participantIds: const [],
      createdAt: DateTime.now(),
    );
    when(() => mockProvider.view).thenReturn([testProject]);

    // !!! КЛЮЧЕВОЕ ИСПРАВЛЕНИЕ !!!
    // Настраиваем мок для метода canEditProject, чтобы он возвращал true для нашего тестового проекта
    when(() => mockProvider.canEditProject(testProject)).thenReturn(true);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<ProjectProvider>.value(
          value: mockProvider,
          child: const ProjectListScreen(),
        ),
      ),
    );

    // Проверяем, что проект отображается в списке
    expect(find.text('Тестовый проект'), findsOneWidget);
  });
}