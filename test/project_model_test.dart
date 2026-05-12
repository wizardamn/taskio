import 'package:flutter_test/flutter_test.dart';
import 'package:taskio/models/project_model.dart';

void main() {
  group(
    'ProjectModel Business Logic Tests (Тестирование бизнес-логики модели проекта)',
        () {
      ProjectModel buildProject({
        required int totalTasks,
        required int completedTasks,
      }) {
        return ProjectModel(
          id: 'test_project_id',
          ownerId: 'test_user_id',
          title: 'Test Project',
          description: 'Test Description',
          deadline: DateTime.now(),
          createdAt: DateTime.now(),

          // твоя новая модель
          status: ProjectStatus.inProgress.index,
          color: '0xFF2196F3',
          category: ProjectCategory.educational,
          maxMembers: 10,
          maxAttachments: 10,
          gradingEnabled: false,

          participantsData: const [],
          attachments: const [],

          totalTasks: totalTasks,
          completedTasks: completedTasks,

          unreadCount: 0,
          lastMessage: null,
          lastMessageAt: null,
        );
      }

      test(
        'Сценарий 1: Новый проект (0 задач). Прогресс должен быть 0.0',
            () {
          final project = buildProject(
            totalTasks: 0,
            completedTasks: 0,
          );

          expect(project.progress, 0.0);
          expect(project.progress.isNaN, false);
        },
      );

      test(
        'Сценарий 2: Выполнено 5 из 10 задач. Прогресс = 0.5',
            () {
          final project = buildProject(
            totalTasks: 10,
            completedTasks: 5,
          );

          expect(project.progress, 0.5);
        },
      );

      test(
        'Сценарий 3: Все задачи выполнены. Прогресс = 1.0',
            () {
          final project = buildProject(
            totalTasks: 7,
            completedTasks: 7,
          );

          expect(project.progress, 1.0);
        },
      );

      test(
        'Сценарий 4: Есть задачи, но ничего не выполнено. Прогресс = 0.0',
            () {
          final project = buildProject(
            totalTasks: 5,
            completedTasks: 0,
          );

          expect(project.progress, 0.0);
        },
      );

      test(
        'Сценарий 5: Некорректный status должен возвращать planned',
            () {
          final project = buildProject(
            totalTasks: 1,
            completedTasks: 0,
          ).copyWith(
            status: 999,
          );

          expect(
            project.statusEnum,
            ProjectStatus.planned,
          );
        },
      );

      test(
        'Сценарий 6: colorObj должен корректно парсить цвет',
            () {
          final project = buildProject(
            totalTasks: 1,
            completedTasks: 0,
          );

          expect(
            project.colorObj.value,
            0xFF2196F3,
          );
        },
      );
    },
  );
}