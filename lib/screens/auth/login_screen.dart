import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/auth_provider.dart';
import '../../utils/snackbar_manager.dart';
import '../../utils/loading_overlay.dart';
import '../../utils/app_logger.dart';
import '../../utils/error_mapper.dart';
import '../../utils/localization_helper.dart';

import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    try {
      setState(() => _isSubmitting = true);
      LoadingOverlay.show();

      final authProvider = context.read<AuthProvider>();

      await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      SnackbarManager.showSuccess(
          'auth.login_success'.tr());

    } catch (e, st) {
      AppLogger.error('Login error', e);
      AppLogger.error('StackTrace', st);

      SnackbarManager.showError(
          ErrorMapper.map(e).tr());
    } finally {
      LoadingOverlay.hide();
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // =========================================================
  // GUEST LOGIN
  // =========================================================

  Future<void> _signInAsGuest() async {
    if (_isSubmitting) return;

    try {
      setState(() => _isSubmitting = true);
      LoadingOverlay.show();

      final authProvider = context.read<AuthProvider>();

      await authProvider.signInAsGuest();

      if (!mounted) return;

      SnackbarManager.showSuccess(
          'auth.guest_login_success'.tr());

    } catch (e) {
      SnackbarManager.showError(
          ErrorMapper.map(e).tr());
    } finally {
      LoadingOverlay.hide();
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // =========================================================
  // LANGUAGE
  // =========================================================

  Future<void> _changeLanguage(Locale locale) async {
    try {
      LoadingOverlay.show();

      await LocalizationHelper.changeLanguage(
          context, locale.languageCode);

      if (!mounted) return;

      SnackbarManager.showSuccess(
          'profile.language_changed'.tr());

    } finally {
      LoadingOverlay.hide();
    }
  }

  Widget _animated(Widget child, double delay) {
    return child
        .animate(controller: _animationController)
        .fade(duration: 400.ms, delay: delay.ms)
        .slide(begin: const Offset(0, 0.2),
        duration: 400.ms,
        delay: delay.ms);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    const emailRegex =
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

    return Scaffold(
      appBar: AppBar(
        title: Text('auth.login'.tr()),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            onSelected: _changeLanguage,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: Locale('ru'),
                child: Text('🇷🇺 Русский'),
              ),
              PopupMenuItem(
                value: Locale('en'),
                child: Text('🇬🇧 English'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _animated(
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'auth.email_label'.tr(),
                      hintText: 'auth.email_hint'.tr(),
                      prefixIcon:
                      const Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'validation.empty_email'.tr();
                      }
                      if (!RegExp(emailRegex).hasMatch(v)) {
                        return 'validation.invalid_email'.tr();
                      }
                      return null;
                    },
                  ),
                  0,
                ),
                const SizedBox(height: 16),
                _animated(
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText:
                      'auth.password_label'.tr(),
                      hintText:
                      'auth.password_hint'.tr(),
                      prefixIcon:
                      const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible =
                            !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'validation.empty_password'
                            .tr();
                      }
                      if (v.length < 6) {
                        return 'validation.short_password'
                            .tr();
                      }
                      return null;
                    },
                  ),
                  100,
                ),
                const SizedBox(height: 30),
                _animated(
                  ElevatedButton(
                    onPressed:
                    _isSubmitting ? null : _login,
                    child: Text('auth.sign_in'.tr()),
                  ),
                  200,
                ),
                const SizedBox(height: 20),
                _animated(
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : _signInAsGuest,
                    child:
                    Text('auth.sign_in_guest'.tr()),
                  ),
                  250,
                ),
                const SizedBox(height: 20),
                _animated(
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.center,
                    children: [
                      Text('auth.no_account'.tr()),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                const RegisterScreen()),
                          );
                        },
                        child: Text(
                          'auth.sign_up'.tr(),
                          style: const TextStyle(
                              fontWeight:
                              FontWeight.bold),
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