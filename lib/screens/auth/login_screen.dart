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

import '../../widgets/project_list_skeleton.dart';

import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  final FocusNode _emailFocus =
  FocusNode();

  final FocusNode _passwordFocus =
  FocusNode();

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  late final AnimationController _animationController;

  static final RegExp _emailRegex = RegExp(
    r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$',
  );

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 600,
      ),
    );

    _animationController.forward();

    Future.delayed(
      const Duration(milliseconds: 300),
          () {
        if (!mounted) {
          return;
        }

        _emailFocus.requestFocus();
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();

    _animationController.dispose();

    super.dispose();
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) {
      return;
    }

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    try {
      setState(() {
        _isSubmitting = true;
      });

      // Важно:
      // Глобальный LoadingOverlay здесь не используем.
      // Пока идёт вход, экран заменяется на ProjectListSkeleton.

      if (authProvider.isGuest) {
        await authProvider.signOut();
      }

      await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'auth.login_success'.tr(),
      );
    } catch (e, st) {
      AppLogger.error(
        'Login error',
        error: e,
        stackTrace: st,
        tag: 'LoginScreen',
      );

      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // =========================================================
  // GUEST LOGIN
  // =========================================================

  Future<void> _signInAsGuest() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) {
      return;
    }

    final authProvider = context.read<AuthProvider>();

    try {
      setState(() {
        _isSubmitting = true;
      });

      // Важно:
      // Глобальный LoadingOverlay здесь не используем.
      // Skeleton показывается сразу после нажатия на кнопку.

      if (authProvider.isAuthenticated &&
          !authProvider.isGuest) {
        await authProvider.signOut();
      }

      await authProvider.signInAsGuest();

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'auth.guest_login_success'.tr(),
      );
    } catch (e, st) {
      AppLogger.error(
        'Guest login error',
        error: e,
        stackTrace: st,
        tag: 'LoginScreen',
      );

      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // =========================================================
  // LANGUAGE
  // =========================================================

  Future<void> _changeLanguage(
      Locale locale,
      ) async {
    try {
      LoadingOverlay.show();

      await LocalizationHelper.changeLanguage(
        context,
        locale.languageCode,
      );

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'profile.language_changed'.tr(),
      );
    } catch (e, st) {
      AppLogger.error(
        'Language change error',
        error: e,
        stackTrace: st,
        tag: 'LoginScreen',
      );

      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        'errors.unknown'.tr(),
      );
    } finally {
      LoadingOverlay.hide();
    }
  }

  // =========================================================
  // ANIMATION
  // =========================================================

  Widget _animated(
      Widget child,
      double delay,
      ) {
    return child
        .animate(
      controller: _animationController,
    )
        .fade(
      duration: 400.ms,
      delay: delay.ms,
    )
        .slide(
      begin: const Offset(
        0,
        0.2,
      ),
      duration: 400.ms,
      delay: delay.ms,
    );
  }

  // =========================================================
  // LOADING SKELETON
  // =========================================================

  Widget _buildLoadingSkeleton() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'navigation.my_projects'.tr(),
        ),
      ),
      body: const ProjectListSkeleton(),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) {
      return _buildLoadingSkeleton();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'auth.login'.tr(),
        ),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(
              Icons.language,
            ),
            onSelected: _changeLanguage,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: Locale('ru'),
                child: Text(
                  '🇷🇺 Русский',
                ),
              ),
              PopupMenuItem(
                value: Locale('en'),
                child: Text(
                  '🇬🇧 English',
                ),
              ),
            ],
          ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              autovalidateMode:
              AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  _animated(
                    TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      keyboardType:
                      TextInputType.emailAddress,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      textInputAction:
                      TextInputAction.next,
                      onFieldSubmitted: (_) {
                        _passwordFocus.requestFocus();
                      },
                      decoration: InputDecoration(
                        labelText:
                        'auth.email_label'.tr(),
                        hintText:
                        'auth.email_hint'.tr(),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                        ),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';

                        if (value.isEmpty) {
                          return 'validation.empty_email'.tr();
                        }

                        if (!_emailRegex.hasMatch(value)) {
                          return 'validation.invalid_email'.tr();
                        }

                        return null;
                      },
                    ),
                    0,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _animated(
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      autofillHints: const [
                        AutofillHints.password,
                      ],
                      obscureText: !_isPasswordVisible,
                      textInputAction:
                      TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText:
                        'auth.password_label'.tr(),
                        hintText:
                        'auth.password_hint'.tr(),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                        ),
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
                          return 'validation.empty_password'.tr();
                        }

                        if (v.length < 6) {
                          return 'validation.short_password'.tr();
                        }

                        return null;
                      },
                    ),
                    100,
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  _animated(
                    ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          50,
                        ),
                      ),
                      child: Text(
                        'auth.sign_in'.tr(),
                      ),
                    ),
                    200,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _animated(
                    OutlinedButton(
                      onPressed: _signInAsGuest,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          50,
                        ),
                      ),
                      child: Text(
                        'auth.sign_in_guest'.tr(),
                      ),
                    ),
                    250,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  _animated(
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Text(
                          'auth.no_account'.tr(),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'auth.sign_up'.tr(),
                            style: const TextStyle(
                              fontWeight:
                              FontWeight.bold,
                            ),
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
      ),
    );
  }
}