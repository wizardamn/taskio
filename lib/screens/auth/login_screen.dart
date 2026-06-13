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
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() {
    return _LoginScreenState();
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  static final RegExp _emailRegex = RegExp(
    r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$',
  );

  @override
  void initState() {
    super.initState();

    Future.delayed(
      const Duration(milliseconds: 300),
          () {
        if (!mounted || _isSubmitting) {
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

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    try {
      setState(() {
        _isSubmitting = true;
      });

      if (authProvider.isGuest) {
        await authProvider.signOut();
      }

      await authProvider.signIn(
        email,
        password,
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

      if (authProvider.isAuthenticated) {
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
    if (_isSubmitting) {
      return;
    }

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
      int delay,
      ) {
    return child
        .animate(delay: delay.ms)
        .fadeIn(duration: 450.ms)
        .slide(
      begin: const Offset(0, 0.18),
      duration: 450.ms,
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
  // UI
  // =========================================================

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _login,
        child: Text(
          'auth.sign_in'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildGuestButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : _signInAsGuest,
        child: Text(
          'auth.sign_in_guest'.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 0,
      children: [
        Text(
          'auth.no_account'.tr(),
          textAlign: TextAlign.center,
        ),
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) {
                  return const RegisterScreen();
                },
              ),
            );
          },
          child: Text(
            'auth.sign_up'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _animated(
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.email,
                ],
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  _passwordFocus.requestFocus();
                },
                decoration: InputDecoration(
                  labelText: 'auth.email_label'.tr(),
                  hintText: 'auth.email_hint'.tr(),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                  ),
                ),
                validator: (value) {
                  final email = value?.trim().toLowerCase() ?? '';

                  if (email.isEmpty) {
                    return 'validation.empty_email'.tr();
                  }

                  if (!_emailRegex.hasMatch(email)) {
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
                focusNode: _passwordFocus,
                enabled: !_isSubmitting,
                autofillHints: const [
                  AutofillHints.password,
                ],
                obscureText: !_isPasswordVisible,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  _login();
                },
                decoration: InputDecoration(
                  labelText: 'auth.password_label'.tr(),
                  hintText: 'auth.password_hint'.tr(),
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  suffixIcon: IconButton(
                    tooltip: _isPasswordVisible
                        ? 'auth.hide_password'.tr()
                        : 'auth.show_password'.tr(),
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'validation.empty_password'.tr();
                  }

                  if (value.length < 6) {
                    return 'validation.short_password'.tr();
                  }

                  return null;
                },
              ),
              100,
            ),
            const SizedBox(height: 30),
            _animated(
              _buildLoginButton(),
              200,
            ),
            const SizedBox(height: 20),
            _animated(
              _buildGuestButton(),
              250,
            ),
            const SizedBox(height: 20),
            _animated(
              _buildRegisterLink(),
              300,
            ),
          ],
        ),
      ),
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'auth.login'.tr(),
        ),
        actions: [
          PopupMenuButton<Locale>(
            enabled: !_isSubmitting,
            icon: const Icon(
              Icons.language,
            ),
            tooltip: 'profile.language'.tr(),
            onSelected: _changeLanguage,
            itemBuilder: (_) {
              return const [
                PopupMenuItem<Locale>(
                  value: Locale('ru'),
                  child: Text(
                    '🇷🇺 Русский',
                  ),
                ),
                PopupMenuItem<Locale>(
                  value: Locale('en'),
                  child: Text(
                    '🇬🇧 English',
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 520,
                      ),
                      child: _buildFormContent(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}