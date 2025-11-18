import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart'; // ✅ ИМПОРТ: Добавлен для локализации
import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // ✅ АНИМАЦИИ: Контроллер для анимации входа формы
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
    _animationController.dispose(); // ✅ АНИМАЦИИ: Освобождаем контроллер
    super.dispose();
  }

  // Функция для показа стильных подсказок
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // ✅ УЛУЧШЕНИЕ: Используем цветовую схему темы
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
      await _auth.signIn(_email.text.trim(), _password.text.trim());
      if (!mounted) return;
    } on Exception catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ АНИМАЦИИ: Вспомогательный виджет для анимации смещения (slide-up)
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
    // Регулярное выражение для проверки почты:
    const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';

    return Scaffold(
      appBar: AppBar(title: Text('login_title'.tr())), // ✅ ЛОКАЛИЗАЦИЯ
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
                    decoration: InputDecoration(
                        labelText: 'email'.tr(), // ✅ ЛОКАЛИЗАЦИЯ
                        hintText: 'email_hint'.tr() // ✅ ЛОКАЛИЗАЦИЯ
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'email_empty_warning'.tr(); // ✅ ЛОКАЛИЗАЦИЯ
                      }
                      if (!RegExp(emailRegex).hasMatch(v)) {
                        return 'email_format_warning'.tr(); // ✅ ЛОКАЛИЗАЦИЯ
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
                      labelText: 'password'.tr(), // ✅ ЛОКАЛИЗАЦИЯ
                      hintText: 'password_hint'.tr(), // ✅ ЛОКАЛИЗАЦИЯ
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() => _isPasswordVisible = !_isPasswordVisible);
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (v) => v == null || v.length < 6
                        ? 'password_length_warning'.tr() // ✅ ЛОКАЛИЗАЦИЯ
                        : null,
                  ),
                  100,
                ),
                const SizedBox(height: 30),

                // 3. Кнопка Войти (Задержка 200ms)
                _buildAnimatedContent(
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _login,
                    // ✅ УЛУЧШЕНИЕ: Увеличиваем размер кнопки
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('login_button'.tr()), // ✅ ЛОКАЛИЗАЦИЯ
                  ),
                  200,
                ),
                const SizedBox(height: 20),

                // 4. Кнопка Зарегистрироваться (Задержка 300ms)
                _buildAnimatedContent(
                  TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen())),
                    child: Text('register_link'.tr()), // ✅ ЛОКАЛИЗАЦИЯ
                  ),
                  300,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}