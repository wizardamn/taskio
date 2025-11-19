import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Оставлен и используется для анимации
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  String _role = 'student'; // Роль по умолчанию (используется ключ для логики)
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  // Функция для показа стильных подсказок (Snackbar)
  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // Используем цветовую схему темы
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(15),
      ),
    );
  }

  void _register() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Передаем ключ роли в сервис
      final success = await _auth.signUp(
        _email.text.trim(),
        _password.text.trim(),
        _fullName.text.trim(),
        _role,
      );

      if (!mounted) return;

      if (success) {
        // Успешная регистрация: Стильная подсказка
        _showSnackBar('Успешная регистрация', isError: false);
        // ВОЗВРАТ НА ЭКРАН ВХОДА
        Navigator.pop(context);
      }

    } on Exception catch (e) {
      if (mounted) {
        // Отображение ошибок
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Регулярное выражение для строгой проверки почты
    const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';

    return Scaffold(
      // AppBar добавлен для автоматической кнопки "назад"
      appBar: AppBar(
        title: const Text('Регистрация'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Поле Полное имя (Анимация flutter_animate)
                TextFormField(
                  controller: _fullName,
                  decoration: const InputDecoration(
                      labelText: 'Имя'),
                  validator: (v) =>
                  v == null || v.isEmpty ? 'Пожалуйста, введите имя' : null,
                )
                    .animate(delay: 0.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)), // Анимация

                const SizedBox(height: 16),

                // 2. Поле Email (Анимация flutter_animate)
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Email'),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Пожалуйста, введите email';
                    }
                    if (!RegExp(emailRegex).hasMatch(v)) {
                      return 'Неверный формат email';
                    }
                    return null;
                  },
                )
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)), // Анимация с задержкой

                const SizedBox(height: 16),

                // 3. Поле Пароль (Анимация flutter_animate)
                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    hintText: 'Пароль',
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        // Переключает состояние видимости
                        setState(() => _isPasswordVisible = !_isPasswordVisible);
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: (v) => v == null || v.length < 6
                      ? 'Пароль должен быть не менее 6 символов'
                      : null,
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)), // Анимация с задержкой

                const SizedBox(height: 16),

                // 4. Выбор роли (Анимация flutter_animate)
                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    // Текст Dropdown заменен на русский
                    DropdownMenuItem(
                        value: 'student', child: Text('Студент')),
                    DropdownMenuItem(
                        value: 'teacher', child: Text('Учитель')),
                    DropdownMenuItem(
                        value: 'leader', child: Text('Тимлид')),
                  ],
                  decoration:
                  const InputDecoration(labelText: 'Выберите роль'),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _role = v);
                    }
                  },
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)), // Анимация с задержкой

                const SizedBox(height: 30),

                // 5. Кнопка Регистрации (Анимация flutter_animate)
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                    onPressed: _register,
                    // Улучшение: Увеличиваем размер кнопки
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Зарегистрироваться'))
                    .animate(delay: 400.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)), // Анимация с задержкой
              ],
            ),
          ),
        ),
      ),
    );
  }
}