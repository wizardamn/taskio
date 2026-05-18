import 'package:flutter_test/flutter_test.dart';
import 'package:taskio/models/project_model.dart';

void main() {
  group(
    'ProjectModel Unit Tests',
        () {
      ProjectModel buildProject({
        required int totalTasks,
        required int completedTasks,
        int status = 1,
        String color = '0xFF2196F3',
      }) {
        return ProjectModel(
          id: 'project_test',
          ownerId: 'user_test',
          title: 'Taskio Test Project',
          description: 'Test description',
          deadline: DateTime.now().add(
            const Duration(days: 7),
          ),
          createdAt: DateTime.now(),
          status: status,
          color: color,
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
        'Positive: progress = 0.0 for new project',
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
        'Positive: progress = 0.5',
            () {
          final project = buildProject(
            totalTasks: 10,
            completedTasks: 5,
          );

          expect(project.progress, 0.5);
        },
      );

      test(
        'Positive: progress = 1.0',
            () {
          final project = buildProject(
            totalTasks: 8,
            completedTasks: 8,
          );

          expect(project.progress, 1.0);
        },
      );

      test(
        'Boundary: progress = 0.0 when tasks exist but none completed',
            () {
          final project = buildProject(
            totalTasks: 5,
            completedTasks: 0,
          );

          expect(project.progress, 0.0);
        },
      );

      test(
        'Negative: invalid status falls back safely',
            () {
          final project = buildProject(
            totalTasks: 1,
            completedTasks: 0,
            status: 999,
          );

          expect(
            project.statusEnum,
            ProjectStatus.planned,
          );
        },
      );

      test(
        'Positive: correct color parsing',
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

      test(
        'Negative: invalid color falls back safely',
            () {
          final project = buildProject(
            totalTasks: 1,
            completedTasks: 0,
            color: 'INVALID_COLOR',
          );

          expect(
            project.colorObj.value,
            isNotNull,
          );
        },
      );

      test(
        'Positive: copyWith updates title',
            () {
          final project = buildProject(
            totalTasks: 3,
            completedTasks: 1,
          );

          final updated = project.copyWith(
            title: 'Updated Project',
          );

          expect(
            updated.title,
            'Updated Project',
          );

          expect(
            updated.description,
            project.description,
          );
        },
      );

      test(
        'Positive: copyWith updates status',
            () {
          final project = buildProject(
            totalTasks: 3,
            completedTasks: 1,
          );

          final updated = project.copyWith(
            status: ProjectStatus.completed.index,
          );

          expect(
            updated.statusEnum,
            ProjectStatus.completed,
          );
        },
      );

      test(
        'Boundary: completedTasks > totalTasks',
            () {
          final project = buildProject(
            totalTasks: 5,
            completedTasks: 10,
          );

          expect(
            project.progress >= 1.0,
            true,
          );
        },
      );
    },
  );
}