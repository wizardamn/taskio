import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:taskio/models/project_model.dart';
import 'package:taskio/providers/project_provider.dart';
import 'package:taskio/screens/home/project_list_screen.dart';

class MockProjectProvider extends Mock
    with ChangeNotifier
    implements ProjectProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  ProjectModel buildTestProject() {
    return ProjectModel(
      id: '1',
      ownerId: 'owner_id',
      title: 'Тестовый проект',
      description: 'Описание проекта',
      deadline: DateTime.now().add(
        const Duration(days: 7),
      ),
      createdAt: DateTime.now(),

      status: ProjectStatus.inProgress.index,
      color: '0xFF2196F3',
      category: ProjectCategory.educational,
      maxMembers: 10,
      maxAttachments: 10,
      gradingEnabled: false,

      participantsData: const [],
      attachments: const [],

      totalTasks: 0,
      completedTasks: 0,

      unreadCount: 0,
      lastMessage: null,
      lastMessageAt: null,
    );
  }

  Widget buildTestApp({
    required ProjectProvider provider,
  }) {
    return EasyLocalization(
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      path: 'assets/lang',
      fallbackLocale: const Locale('ru'),
      child: ChangeNotifierProvider<ProjectProvider>.value(
        value: provider,
        child: Builder(
          builder: (context) {
            return MaterialApp(
              locale: context.locale,
              supportedLocales:
              context.supportedLocales,
              localizationsDelegates:
              context.localizationDelegates,
              home: const ProjectListScreen(),
            );
          },
        ),
      ),
    );
  }

  group('ProjectListScreen Widget Tests', () {
    testWidgets(
      'отображает FAB',
          (WidgetTester tester) async {
        final mockProvider = MockProjectProvider();

        when(() => mockProvider.isGuest)
            .thenReturn(false);

        when(() => mockProvider.isLoading)
            .thenReturn(false);

        when(() => mockProvider.projects)
            .thenReturn([]);

        await tester.pumpWidget(
          buildTestApp(
            provider: mockProvider,
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byType(
            FloatingActionButton,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'отображает список проектов',
          (WidgetTester tester) async {
        final mockProvider = MockProjectProvider();

        final testProject =
        buildTestProject();

        when(() => mockProvider.isGuest)
            .thenReturn(false);

        when(() => mockProvider.isLoading)
            .thenReturn(false);

        when(() => mockProvider.projects)
            .thenReturn([testProject]);

        when(
              () => mockProvider.canEditProject(
            testProject,
          ),
        ).thenReturn(true);

        await tester.pumpWidget(
          buildTestApp(
            provider: mockProvider,
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Тестовый проект'),
          findsOneWidget,
        );
      },
    );
  });
}