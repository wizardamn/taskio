import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskio/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Мокируем platform-каналы
  SharedPreferences.setMockInitialValues({});

  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.app_links/events'),
        (MethodCall methodCall) async {
      // Игнорируем вызовы listen/cancel для app_links в тестовой среде
      return null;
    },
  );

  group('Сквозные тесты Taskio: Управление проектами (с логином)', () {
    // Уникальный заголовок для теста, чтобы избежать конфликтов и точно его находить
    final uniqueProjectTitle = 'E2E Тест: ${DateTime.now().millisecondsSinceEpoch}';

    testWidgets('1. Вход в систему, создание, редактирование и удаление проекта', (WidgetTester tester) async {
      // 1. Запуск приложения
      await app.main();

      // ***ИСПРАВЛЕНИЕ: Увеличение и усиление ожидания***
      // Ждем 12 секунд. Это необходимо для завершения:
      // 1. Инициализации EasyLocalization.
      // 2. Инициализации Supabase.
      // 3. Проверки состояния авторизации и перехода к соответствующему экрану (LoginWrapper -> LoginScreen).
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle(); // Ждем завершения всех анимаций и редиректов
      await tester.pumpAndSettle(); // Дополнительный pumpAndSettle

      // Проверяем, что мы находимся на LoginScreen (или LoginWrapper, показывающем LoginScreen)
      // Проверим наличие элементов, характерных для LoginScreen.
      // ПРЕДПОЛОЖЕНИЕ: на LoginScreen есть TextFormField для email и password, и ElevatedButton для входа.
      final emailField = find.widgetWithText(TextFormField, 'Email'); // Замените на ваш placeholder
      final passwordField = find.widgetWithText(TextFormField, 'Пароль'); // Замените на ваш placeholder
      final loginButton = find.widgetWithText(ElevatedButton, 'Войти'); // Замените на ваш текст кнопки

      expect(emailField, findsOneWidget, reason: 'Не найдено поле Email на экране входа.');
      expect(passwordField, findsOneWidget, reason: 'Не найдено поле Пароль на экране входа.');
      expect(loginButton, findsOneWidget, reason: 'Не найдена кнопка "Войти" на экране входа.');

      // 2. Ввод учетных данных
      // ПОМНИТЕ: В реальной ситуации вы используете тестовые учетные данные.
      // В тестовой среде можно мокировать успешный вход или использовать тестовый аккаунт.
      // ПОМНИТЕ: Не храните реальные пароли в коде теста!
      // ЗАМЕНИТЕ НА ВАШИ ТЕСТОВЫЕ ДАННЫЕ
      await tester.enterText(emailField, 'bykovkirill98@gmail.com');
      await tester.enterText(passwordField, '123456');

      // 3. Нажатие кнопки входа
      await tester.tap(loginButton);

      // 4. Ждем завершения входа и перехода на ProjectListScreen
      // Это может занять некоторое время из-за аутентификации через Supabase
      await tester.pump(const Duration(seconds: 8)); // Увеличиваем ожидание после входа
      await tester.pumpAndSettle();

      // 5. Проверяем, что мы перешли на ProjectListScreen
      final appBarTitle = find.text('Мои проекты');
      final addProjectButton = find.byIcon(Icons.add);

      expect(appBarTitle, findsOneWidget, reason: 'Не найден заголовок "Мои проекты". Переход на список проектов не удался.');
      expect(addProjectButton, findsOneWidget, reason: 'Не найдена кнопка добавления проекта. Переход на список проектов не удался.');

      // --- Создание проекта ---
      // 6. Находим и нажимаем кнопку добавления проекта (FloatingActionButton с иконкой Icons.add)
      await tester.tap(addProjectButton);
      await tester.pumpAndSettle(); // Переход на экран создания ProjectFormScreen

      // 7. Заполнение формы создания проекта
      final titleField = find.widgetWithText(TextFormField, 'Название проекта');
      expect(titleField, findsOneWidget, reason: 'Не найдено поле "Название проекта"');
      await tester.enterText(titleField, uniqueProjectTitle);

      final descriptionField = find.widgetWithText(TextFormField, 'Описание');
      expect(descriptionField, findsOneWidget, reason: 'Не найдено поле "Описание"');
      await tester.enterText(descriptionField, 'Описание для проверки создания проекта.');

      // 8. Сохранение проекта
      final saveButton = find.byIcon(Icons.check);
      expect(saveButton, findsOneWidget, reason: 'Не найдена кнопка "Сохранить" (иконка галочки)');
      await tester.tap(saveButton);

      // Ждем возвращения на ProjectListScreen и завершения fetchProjects
      // Это может занять некоторое время из-за асинхронных операций в ProjectFormScreen и ProjectListScreen
      await tester.pumpAndSettle(const Duration(seconds: 10)); // Увеличиваем ожидание

      // --- ПРОВЕРКА ПОСЛЕ ПЕРЕСТРОЙКИ (создание)---
      // Попробуем прокрутить ListView вниз, чтобы построить все элементы
      // Ищем сам ListView
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget, reason: 'ListView не найден.');

      // Прокручиваем его вниз на большой отступ
      await tester.drag(listViewFinder, const Offset(0, -5000)); // Прокрутка вниз (отрицательное значение Y)
      await tester.pumpAndSettle(); // Дожидаемся завершения прокрутки и перерисовки

      // Теперь проверяем наличие элемента
      final createdProjectFinder = find.text(uniqueProjectTitle);
      expect(createdProjectFinder, findsOneWidget,
          reason: 'Проект с заголовком "$uniqueProjectTitle" не найден в списке после fetchProjects, ожидания и прокрутки вниз.'
      );
      // --- КОНЕЦ ПРОВЕРКИ (создание)---

      // --- Редактирование ---
      await tester.pumpAndSettle(); // Обновление списка
      final projectTile = find.widgetWithText(ListTile, uniqueProjectTitle);
      expect(projectTile, findsOneWidget, reason: 'Проект для редактирования не найден. Возможно, предыдущий тест не создал его.');

      await tester.tap(projectTile);
      await tester.pumpAndSettle(); // Переход на ProjectFormScreen в режиме редактирования

      final appBarTitleEdit = find.text('Редактировать проект');
      expect(appBarTitleEdit, findsOneWidget, reason: 'Не найден заголовок "Редактировать проект". Переход на форму редактирования не удался.');

      final descriptionFieldEdit = find.widgetWithText(TextFormField, 'Описание');
      expect(descriptionFieldEdit, findsOneWidget, reason: 'Не найдено поле "Описание" на экране редактирования');
      await tester.enterText(descriptionFieldEdit, 'Измененное описание для проверки редактирования.');

      final saveButtonEdit = find.byIcon(Icons.check);
      expect(saveButtonEdit, findsOneWidget, reason: 'Не найдена кнопка "Сохранить" (иконка галочки) на экране редактирования');
      await tester.tap(saveButtonEdit);

      // Ждем возвращения на ProjectListScreen и завершения fetchProjects после редактирования
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // --- ПРОВЕРКА ПОСЛЕ ПЕРЕСТРОЙКИ (редактирование) ---
      // Прокручиваем ListView вниз, чтобы построить все элементы
      final listViewFinderEdit = find.byType(ListView);
      expect(listViewFinderEdit, findsOneWidget, reason: 'ListView не найден (редактирование).');

      await tester.drag(listViewFinderEdit, const Offset(0, -5000));
      await tester.pumpAndSettle();

      final stillExistsFinder = find.text(uniqueProjectTitle);
      expect(stillExistsFinder, findsOneWidget, reason: 'Проект исчез после попытки редактирования и fetchProjects.');
      // --- КОНЕЦ ПРОВЕРКИ (редактирование) ---

      // --- Удаление ---
      await tester.pumpAndSettle();
      final projectTileDelete = find.widgetWithText(ListTile, uniqueProjectTitle);
      expect(projectTileDelete, findsOneWidget, reason: 'Проект для удаления не найден.');

      final moreButton = find.descendant(
        of: projectTileDelete,
        matching: find.byIcon(Icons.more_vert), // Иконка с тремя точками
      ).first;
      expect(moreButton, findsOneWidget, reason: 'Не найдена кнопка "Еще" (три точки) для проекта.');
      await tester.tap(moreButton);

      await tester.pumpAndSettle();

      final deleteButton = find.text('Удалить');
      expect(deleteButton, findsOneWidget, reason: 'Не найдена кнопка "Удалить" в меню.');
      await tester.tap(deleteButton);

      await tester.pumpAndSettle();
      final confirmButton = find.text('Удалить'); // Кнопка подтверждения в AlertDialog
      expect(confirmButton, findsOneWidget, reason: 'Не найдена кнопка подтверждения удаления в диалоге.');
      await tester.tap(confirmButton);

      // Ждем завершения асинхронной операции удаления и fetchProjects
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // --- ПРОВЕРКА УДАЛЕНИЯ ---
      // Прокручиваем ListView вниз, чтобы обновить дерево
      final listViewFinderDelete = find.byType(ListView);
      expect(listViewFinderDelete, findsOneWidget, reason: 'ListView не найден (удаление).');

      await tester.drag(listViewFinderDelete, const Offset(0, -5000));
      await tester.pumpAndSettle();

      final deletedProjectFinder = find.text(uniqueProjectTitle);
      expect(deletedProjectFinder, findsNothing,
          reason: 'Проект был удален, но все еще отображается в списке после fetchProjects и прокрутки.'
      );
      // --- КОНЕЦ ПРОВЕРКИ УДАЛЕНИЯ ---

    });
  });
}