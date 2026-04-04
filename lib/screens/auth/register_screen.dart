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

  String _role = 'student';

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  // =========================================================
  // REGISTER
  // =========================================================

  Future<void> _register() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isSubmitting = true);
      LoadingOverlay.show();

      final authProvider =
      context.read<AuthProvider>();

      await authProvider.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _fullNameController.text.trim(),
        _role,
      );

      if (!mounted) return;

      SnackbarManager.showSuccess(
        'auth.register_success'.tr(),
      );

      Navigator.of(context).pop();
    } catch (e, st) {
      AppLogger.error(
          'Register error', e);
      AppLogger.error(
          'StackTrace', st);

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
      LoadingOverlay.hide();
    }
  }

  Widget _animated(
      Widget child, int delay) {
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
    const emailRegex =
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';

    return Scaffold(
      appBar: AppBar(
        title:
        Text('auth.register_title'.tr()),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding:
          const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _animated(
                  TextFormField(
                    controller:
                    _fullNameController,
                    decoration:
                    InputDecoration(
                      labelText:
                      'auth.full_name'
                          .tr(),
                      prefixIcon:
                      const Icon(
                        Icons
                            .person_outline,
                      ),
                    ),
                    validator: (v) {
                      if (v == null ||
                          v.isEmpty) {
                        return 'validation.empty_name'
                            .tr();
                      }
                      return null;
                    },
                  ),
                  0,
                ),

                const SizedBox(
                    height: 16),

                _animated(
                  TextFormField(
                    controller:
                    _emailController,
                    keyboardType:
                    TextInputType
                        .emailAddress,
                    decoration:
                    InputDecoration(labelText: 'auth.email_label'.tr(),
                      hintText: 'auth.email_hint'.tr(),
                      prefixIcon:
                      const Icon(
                        Icons
                            .email_outlined,
                      ),
                    ),
                    validator: (v) {
                      if (v == null ||
                          v.isEmpty) {
                        return 'validation.empty_email'.tr();
                      }
                      if (!RegExp(
                          emailRegex)
                          .hasMatch(v)) {
                        return 'validation.invalid_email'.tr();
                      }
                      return null;
                    },
                  ),
                  100,
                ),

                const SizedBox(
                    height: 16),

                _animated(
                  TextFormField(
                    controller:
                    _passwordController,
                    obscureText:
                    !_isPasswordVisible,
                    decoration:
                    InputDecoration(
                      labelText:
                      'auth.password_label'
                          .tr(),
                      hintText:
                      'auth.password_hint'
                          .tr(),
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
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible =
                            !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (v) {
                      if (v == null ||
                          v.isEmpty) {
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
                  200,
                ),

                const SizedBox(
                    height: 16),

                _animated(
                  DropdownButtonFormField<
                      String>(
                    value: _role,
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
                        value:
                        'student',
                        child: Text(
                          'roles.student'
                              .tr(),
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                        'teacher',
                        child: Text(
                          'roles.teacher'
                              .tr(),
                        ),
                      ),
                      DropdownMenuItem(
                        value:
                        'leader',
                        child: Text(
                          'roles.leader'
                              .tr(),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() =>
                        _role = v);
                      }
                    },
                  ),
                  300,
                ),

                const SizedBox(
                    height: 30),

                _animated(
                  ElevatedButton(
                    onPressed:
                    _isSubmitting
                        ? null
                        : _register,
                    style: ElevatedButton
                        .styleFrom(
                      minimumSize:
                      const Size(
                          double.infinity,
                          50),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                        color:
                        Colors
                            .white,
                      ),
                    )
                        : Text(
                      'auth.sign_up'
                          .tr(),
                    ),
                  ),
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