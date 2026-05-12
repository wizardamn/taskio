import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/auth_provider.dart';
import '../../utils/snackbar_manager.dart';
import '../../utils/loading_overlay.dart';
import '../../utils/app_logger.dart';
import '../../utils/error_mapper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController =
  TextEditingController();

  final _passwordController =
  TextEditingController();

  final _fullNameController =
  TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _nameFocus = FocusNode();

  String _role = 'student';

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  static final RegExp _emailRegex = RegExp(
    r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();
    _nameFocus.dispose();

    super.dispose();
  }

  // =========================================================
  // REGISTER
  // =========================================================

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) {
      return;
    }

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    final authProvider =
    context.read<AuthProvider>();

    try {
      setState(() {
        _isSubmitting = true;
      });

      LoadingOverlay.show();

      /// FIX guest mode
      if (authProvider.isGuest) {
        await authProvider.signOut();
      }

      final fullName =
      _fullNameController.text.trim();

      await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        fullName,
        _role,
      );

      if (!mounted) {
        return;
      }

      SnackbarManager.showSuccess(
        'auth.register_success'.tr(),
      );

      Navigator.of(context).pop();
    } catch (e, st) {
      AppLogger.error(
        'Register error',
        error: e,
        stackTrace: st,
        tag: 'RegisterScreen',
      );

      if (!mounted) {
        return;
      }

      SnackbarManager.showError(
        ErrorMapper.map(e).tr(),
      );
    } finally {
      LoadingOverlay.hide();

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
        .fadeIn(duration: 500.ms)
        .slide(
      duration: 500.ms,
      begin: const Offset(0, 0.3),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'auth.register_title'.tr(),
        ),
      ),
      body: GestureDetector(
        onTap: () =>
            FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              autovalidateMode:
              AutovalidateMode
                  .onUserInteraction,
              child: Column(
                children: [
                  _animated(
                    TextFormField(
                      controller:
                      _fullNameController,
                      focusNode: _nameFocus,
                      enabled: !_isSubmitting,
                      autofillHints: const [
                        AutofillHints.name,
                      ],
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      InputDecoration(
                        labelText:
                        'auth.full_name'.tr(),
                        prefixIcon:
                        const Icon(
                          Icons
                              .person_outline,
                        ),
                      ),
                      onFieldSubmitted: (_) {
                        _emailFocus
                            .requestFocus();
                      },
                      validator: (v) {
                        final name =
                            v?.trim() ?? '';

                        if (name.isEmpty) {
                          return 'validation.empty_name'.tr();
                        }

                        if (name.length < 2) {
                          return 'validation.invalid_name'.tr();
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
                      controller:
                      _emailController,
                      focusNode: _emailFocus,
                      enabled: !_isSubmitting,
                      keyboardType:
                      TextInputType
                          .emailAddress,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      InputDecoration(
                        labelText:
                        'auth.email_label'.tr(),
                        hintText:
                        'auth.email_hint'.tr(),
                        prefixIcon:
                        const Icon(
                          Icons
                              .email_outlined,
                        ),
                      ),
                      onFieldSubmitted: (_) {
                        _passwordFocus
                            .requestFocus();
                      },
                      validator: (v) {
                        final email =
                            v?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'validation.empty_email'.tr();
                        }

                        if (!_emailRegex
                            .hasMatch(email)) {
                          return 'validation.invalid_email'.tr();
                        }

                        return null;
                      },
                    ),
                    100,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _animated(
                    TextFormField(
                      controller:
                      _passwordController,
                      focusNode:
                      _passwordFocus,
                      enabled: !_isSubmitting,
                      autofillHints: const [
                        AutofillHints.password,
                      ],
                      obscureText:
                      !_isPasswordVisible,
                      textInputAction:
                      TextInputAction.done,
                      decoration:
                      InputDecoration(
                        labelText:
                        'auth.password_label'.tr(),
                        hintText:
                        'auth.password_hint'.tr(),
                        prefixIcon:
                        const Icon(
                          Icons
                              .lock_outline,
                        ),
                        suffixIcon:
                        IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons
                                .visibility
                                : Icons
                                .visibility_off,
                          ),
                          onPressed:
                          _isSubmitting
                              ? null
                              : () {
                            setState(
                                  () {
                                _isPasswordVisible =
                                !_isPasswordVisible;
                              },
                            );
                          },
                        ),
                      ),
                      validator: (v) {
                        if (v == null ||
                            v.isEmpty) {
                          return 'validation.empty_password'.tr();
                        }

                        if (v.length < 6) {
                          return 'validation.short_password'.tr();
                        }

                        return null;
                      },
                      onFieldSubmitted: (_) =>
                          _register(),
                    ),
                    200,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _animated(
                    DropdownButtonFormField<
                        String>(
                      initialValue: _role,
                      decoration:
                      InputDecoration(
                        labelText:
                        'auth.select_role'
                            .tr(),
                        prefixIcon:
                        const Icon(
                          Icons
                              .work_outline,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'student',
                          child: Text(
                            'roles.student'.tr(),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text(
                            'roles.teacher'.tr(),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'leader',
                          child: Text(
                            'roles.leader'.tr(),
                          ),
                        ),
                      ],
                      onChanged:
                      _isSubmitting
                          ? null
                          : (v) {
                        if (v ==
                            null) {
                          return;
                        }

                        setState(() {
                          _role = v;
                        });
                      },
                    ),
                    300,
                  ),

                  const SizedBox(
                    height: 30,
                  ),

                  _animated(
                    ElevatedButton(
                      onPressed:
                      _isSubmitting
                          ? null
                          : _register,
                      style:
                      ElevatedButton
                          .styleFrom(
                        minimumSize:
                        const Size(
                          double.infinity,
                          50,
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                        CircularProgressIndicator(
                          strokeWidth:
                          2,
                          color: Colors
                              .white,
                        ),
                      )
                          : Text(
                        'auth.sign_up'.tr(),
                      ),
                    ),
                    400,
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