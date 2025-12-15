import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _role = 'student';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
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

  void _register() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _fullNameController.text.trim(),
        _role,
      );

      if (!mounted) return;

      _showSnackBar('Успешная регистрация', isError: false);

      // Возвращаемся на экран входа
      Navigator.of(context).pop();

    } on Exception catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''), isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';

    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Пожалуйста, введите имя' : null,
                )
                    .animate(delay: 0.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Пожалуйста, введите email';
                    if (!RegExp(emailRegex).hasMatch(v)) return 'Неверный формат email';
                    return null;
                  },
                )
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Пароль',
                    hintText: 'Пароль',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: (v) => v == null || v.length < 6
                      ? 'Пароль должен быть не менее 6 символов'
                      : null,
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Студент')),
                    DropdownMenuItem(value: 'teacher', child: Text('Учитель')),
                    DropdownMenuItem(value: 'leader', child: Text('Тимлид')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Выберите роль',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  onChanged: (v) {
                    if (v != null) setState(() => _role = v);
                  },
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)),

                const SizedBox(height: 30),

                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Зарегистрироваться'),
                )
                    .animate(delay: 400.ms)
                    .fadeIn(duration: 500.ms)
                    .slide(duration: 500.ms, begin: const Offset(0, 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}