import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // Импорт для локализации
import 'package:flutter_animate/flutter_animate.dart'; // Импорт для анимаций
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();
  String _role = 'student'; // Роль по умолчанию
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Контроллер для анимации формы
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Инициализация контроллера анимации
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // Анимация (кривая - отскок для большего эффекта)
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );

    // Запускаем анимацию сразу после создания виджета
    _animationController.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    _animationController.dispose(); // Освобождаем контроллер
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
      final success = await _auth.signUp(
        _email.text.trim(),
        _password.text.trim(),
        _fullName.text.trim(),
        _role,
      );

      if (!mounted) return;

      if (success) {
        // Успешная регистрация: Стильная подсказка
        _showSnackBar('register_success_message'.tr(), isError: false);
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

  // Вспомогательный виджет для анимации смещения (slide-up)
  Widget _buildAnimatedContent(Widget child, double delay) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double value = _animation.value;
        // Задержка анимации для элементов
        if (value * 1000 < delay) return Opacity(opacity: 0, child: child);

        final adjustedValue = (value * 1000 - delay) / (700 - delay);
        final opacity = Curves.easeIn.transform(adjustedValue.clamp(0.0, 1.0));
        final yOffset = 30 * (1 - opacity);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, yOffset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Регулярное выражение для строгой проверки почты
    const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';

    return Scaffold(
      appBar: AppBar(title: Text('register_title'.tr())), // Локализация
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Поле Полное имя (Задержка 0ms)
                _buildAnimatedContent(
                  TextFormField(
                    controller: _fullName,
                    decoration: InputDecoration(
                        labelText: 'full_name'.tr()), // Локализация
                    validator: (v) =>
                    v == null || v.isEmpty ? 'name_empty_warning'.tr() : null, // Локализация
                  ),
                  0,
                ),
                const SizedBox(height: 16),

                // 2. Поле Email (Задержка 100ms)
                _buildAnimatedContent(
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                        labelText: 'email'.tr(), // Локализация
                        hintText: 'email_hint'.tr()), // Локализация
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'email_empty_warning'.tr(); // Локализация
                      }
                      if (!RegExp(emailRegex).hasMatch(v)) {
                        return 'email_format_warning'.tr(); // Локализация
                      }
                      return null;
                    },
                  ),
                  100,
                ),
                const SizedBox(height: 16),

                // 3. Поле Пароль (Задержка 200ms)
                _buildAnimatedContent(
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: 'password'.tr(), // Локализация
                      hintText: 'password_hint'.tr(), // Локализация
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
                    obscureText: !_isPasswordVisible, // Привязка к состоянию
                    validator: (v) => v == null || v.length < 6
                        ? 'password_length_warning'.tr() // Локализация
                        : null,
                  ),
                  200,
                ),
                const SizedBox(height: 16),

                // 4. Выбор роли (Задержка 300ms)
                _buildAnimatedContent(
                  DropdownButtonFormField<String>(
                    value: _role,
                    items: [
                      // Локализация: Элементы Dropdown
                      DropdownMenuItem(
                          value: 'student', child: Text('role_student'.tr())),
                      DropdownMenuItem(
                          value: 'teacher', child: Text('role_teacher'.tr())),
                      DropdownMenuItem(
                          value: 'leader', child: Text('role_leader'.tr())),
                    ],
                    decoration:
                    InputDecoration(labelText: 'select_role'.tr()), // Локализация
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _role = v);
                      }
                    },
                  ),
                  300,
                ),
                const SizedBox(height: 30),

                // 5. Кнопка Регистрации (Задержка 400ms)
                _buildAnimatedContent(
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
                      child: Text('register_button'.tr())), // Локализация
                  400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}