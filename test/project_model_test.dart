import 'package:flutter_test/flutter_test.dart';
import 'package:taskio/models/project_model.dart';

void main() {
  group('ProjectModel Business Logic Tests (Тестирование бизнес-логики модели проекта)', () {

    test('Сценарий 1: Новый проект (0 задач). Прогресс должен быть 0.0, ошибка деления на ноль исключена.', () {
      final project = ProjectModel(
        id: 'test_id_1',
        ownerId: 'user_1',
        title: 'New Project',
        description: 'Test Description',
        deadline: DateTime.now(),
        status: 0,
        createdAt: DateTime.now(),
        totalTasks: 0,
        completedTasks: 0,
      );

      final progress = project.progress;

      expect(progress, 0.0);
      expect(progress.isNaN, false);
    });

    test('Сценарий 2: Проект в процессе (Выполнено 5 из 10 задач). Прогресс должен быть 0.5.', () {
      final project = ProjectModel(
        id: 'test_id_2',
        ownerId: 'user_1',
        title: 'Active Project',
        description: '...',
        deadline: DateTime.now(),
        status: 1,
        createdAt: DateTime.now(),
        totalTasks: 10,
        completedTasks: 5,
      );

      final progress = project.progress;

      expect(progress, 0.5);
    });

    test('Сценарий 3: Завершенный этап (Все задачи выполнены). Прогресс должен быть 1.0.', () {
      final project = ProjectModel(
        id: 'test_id_3',
        ownerId: 'user_1',
        title: 'Completed Scope',
        description: '...',
        deadline: DateTime.now(),
        status: 1,
        createdAt: DateTime.now(),
        totalTasks: 7,
        completedTasks: 7,
      );

      final progress = project.progress;

      expect(progress, 1.0);
    });

    test('Граничный случай: Задачи есть, но ни одна не выполнена. Прогресс 0.0.', () {
      final project = ProjectModel(
        id: 'test_id_4',
        ownerId: 'user_1',
        title: 'Started Project',
        description: '...',
        deadline: DateTime.now(),
        status: 1,
        createdAt: DateTime.now(),
        totalTasks: 5,
        completedTasks: 0,
      );

      final progress = project.progress;

      expect(progress, 0.0);
    });
  });
}