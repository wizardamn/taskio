import 'package:flutter/material.dart';
import 'package:taskio/screens/auth/register_screen.dart'; // Импорт RegisterScreen
import '../../services/auth_service.dart';

// Для ручной анимации необходим SingleTickerProviderStateMixin
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState(); // ИСПРАВЛЕНО: Должен возвращать _LoginScreenState
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();

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

  void _login() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await _auth.signIn(
        _email.text.trim(),
        _password.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        // Успешный вход: Стильная подсказка
        _showSnackBar('Успешный вход', isError: false);
        // Предполагаем, что здесь будет навигация на главный экран
        // Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => HomeScreen()));
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

  // Функция перехода на экран регистрации
  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Регулярное выражение для строгой проверки почты
    const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';

    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Поле Email (Задержка 0ms)
                _buildAnimatedContent(
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Введите ваш Email'),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Пожалуйста, введите email';
                      }
                      if (!RegExp(emailRegex).hasMatch(v)) {
                        return 'Неверный формат email';
                      }
                      return null;
                    },
                  ),
                  0,
                ),
                const SizedBox(height: 16),

                // 2. Поле Пароль (Задержка 100ms)
                _buildAnimatedContent(
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      hintText: 'Введите пароль',
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
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Пожалуйста, введите пароль';
                      }
                      if (v.length < 6) {
                        return 'Пароль должен быть не менее 6 символов';
                      }
                      return null;
                    },
                  ),
                  100,
                ),
                const SizedBox(height: 30),

                // 3. Кнопка Входа (Задержка 200ms)
                _buildAnimatedContent(
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                      onPressed: _login,
                      // Улучшение: Увеличиваем размер кнопки
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Войти')),
                  200,
                ),

                const SizedBox(height: 20),

                // 4. Ссылка на регистрацию (Задержка 300ms)
                _buildAnimatedContent(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Нет аккаунта?'),
                      TextButton(
                        onPressed: _navigateToRegister, // Используем функцию перехода
                        child: const Text(
                          'Зарегистрироваться',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}