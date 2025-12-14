// lib/screens/auth/login_screen.dart
// ...
import 'package:flutter/material.dart';
import 'package:taskio/screens/auth/register_screen.dart';
import 'package:taskio/screens/home/project_list_screen.dart';
import 'package:taskio/providers/auth_provider.dart'; // Убедитесь, что импортировали AuthProvider
import 'package:provider/provider.dart'; // Убедитесь, что импортировали Provider

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Используем AuthProvider для вызова signIn
      final authProvider = context.read<AuthProvider>();
      await authProvider.signIn(_email.text.trim(), _password.text.trim());

      if (!mounted) return;

      _showSnackBar('Успешный вход', isError: false);

      // После успешного входа переходим на ProjectListScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProjectListScreen()),
      );
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

  // --- НОВЫЙ МЕТОД: Вход как гость ---
  Future<void> _signInAsGuest() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // Используем AuthProvider для вызова входа как гость
      final authProvider = context.read<AuthProvider>();
      await authProvider.signInAsGuest(); // Предполагаем, что этот метод будет добавлен в AuthProvider

      if (!mounted) return;

      _showSnackBar('Вход как гость', isError: false);

      // После входа как гость переходим на ProjectListScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProjectListScreen()),
      );
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
  // --- КОНЕЦ НОВОГО МЕТОДА ---

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }

  Widget _buildAnimatedContent(Widget child, double delay) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final double value = _animation.value;
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
                _buildAnimatedContent(
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Введите ваш Email',
                    ),
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

                _buildAnimatedContent(
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                      onPressed: _login,
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

                // --- КНОПКА "ВОЙТИ КАК ГОСТЬ" ---
                _buildAnimatedContent(
                  OutlinedButton(
                    onPressed: _signInAsGuest, // Вызываем новый метод
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Войти как гость'),
                  ),
                  250, // Задержка для анимации
                ),
                const SizedBox(height: 20),
                // --- КОНЕЦ КНОПКИ ---

                _buildAnimatedContent(
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Нет аккаунта?'),
                      TextButton(
                        onPressed: _navigateToRegister,
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