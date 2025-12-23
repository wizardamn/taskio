import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../screens/auth/register_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/project_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      final authProvider = context.read<AuthProvider>();
      await authProvider.signIn(_emailController.text.trim(), _passwordController.text.trim());

    } on Exception catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Вход как гость ---
  Future<void> _signInAsGuest() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final projectProvider = context.read<ProjectProvider>();

      // 1. Устанавливаем флаг гостя в AuthProvider
      await authProvider.signInAsGuest();

      // 2. Инициализируем ProjectProvider для гостя (очищаем старые данные)
      projectProvider.setGuestUser();

      if (!mounted) return;
      _showSnackBar('Вход как гость', isError: false);

      // LoginWrapper (который слушает AuthProvider) сам перерисует экран

    } on Exception catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const RegisterScreen(),
      ),
    );
  }

  Widget _buildAnimatedContent(Widget child, double delay) {
    return child.animate(controller: _animationController)
        .fade(duration: 500.ms, delay: (delay).ms)
        .slide(begin: const Offset(0, 0.3), duration: 500.ms, delay: (delay).ms);
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
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Введите ваш Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Пожалуйста, введите email';
                      if (!RegExp(emailRegex).hasMatch(v)) return 'Неверный формат email';
                      return null;
                    },
                  ),
                  0,
                ),
                const SizedBox(height: 16),

                _buildAnimatedContent(
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      hintText: 'Введите пароль',
                      prefixIcon: const Icon(Icons.lock_outline),
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
                      if (v == null || v.isEmpty) return 'Пожалуйста, введите пароль';
                      if (v.length < 6) return 'Пароль должен быть не менее 6 символов';
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
                      ),
                      child: const Text('Войти')),
                  200,
                ),

                const SizedBox(height: 20),

                _buildAnimatedContent(
                  OutlinedButton(
                    onPressed: _signInAsGuest,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('Войти как гость'),
                  ),
                  250,
                ),
                const SizedBox(height: 20),

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