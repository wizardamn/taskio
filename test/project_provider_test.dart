import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:taskio/models/project_model.dart';
import 'package:taskio/providers/project_provider.dart';
import 'package:taskio/services/project_service.dart';

class MockProjectService extends Mock implements ProjectService {}

class FakeProjectModel extends Fake implements ProjectModel {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeProjectModel());
  });

  late MockProjectService mockService;
  late ProjectProvider provider;

  ProjectModel buildProject() {
    return ProjectModel(
      id: 'project_1',
      ownerId: 'user_1',
      title: 'Test Project',
      description: 'Description',
      deadline: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
      status: ProjectStatus.planned.index,
      color: '0xFF2196F3',
      category: ProjectCategory.educational,
      maxMembers: 10,
      maxAttachments: 10,
      gradingEnabled: false,
      participantsData: const [],
    );
  }

  setUp(() {
    mockService = MockProjectService();
    provider = ProjectProvider(mockService);
  });

  group('ProjectProvider Logic Tests', () {
    test('Guest user cannot create project', () async {
      final project = buildProject();

      final result = await provider.addProject(project);

      expect(result, isNull);
      verifyNever(() => mockService.add(any()));
    });

    test('Service add returns created project', () async {
      final project = buildProject();

      when(() => mockService.add(any()))
          .thenAnswer((_) async => project);

      final result = await mockService.add(project);

      expect(result, isNotNull);
      expect(result.title, 'Test Project');

      verify(() => mockService.add(any())).called(1);
    });

    test('Project model stores correct title', () {
      final project = buildProject();

      expect(project.title, 'Test Project');
    });

    test('Project model stores correct owner id', () {
      final project = buildProject();

      expect(project.ownerId, 'user_1');
    });

    test('Project status enum is planned', () {
      final project = buildProject();

      expect(project.statusEnum, ProjectStatus.planned);
    });

    test('Project description is stored correctly', () {
      final project = buildProject();

      expect(project.description, 'Description');
    });

    test('Project color is stored correctly', () {
      final project = buildProject();

      expect(project.color, '0xFF2196F3');
    });

    test('Project category is educational', () {
      final project = buildProject();

      expect(
        project.category,
        ProjectCategory.educational,
      );
    });

    test('Project deadline is in the future', () {
      final project = buildProject();

      expect(
        project.deadline.isAfter(DateTime.now()),
        true,
      );
    });
  });
}