import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/auth_provider.dart';

import '../../utils/snackbar_manager.dart';
import '../../utils/app_logger.dart';
import '../../utils/error_mapper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() {
    return _RegisterScreenState();
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  String _role = 'student';

  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  static final RegExp _emailRegex = RegExp(
    r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,}$',
  );

  static final RegExp _usernameRegex = RegExp(
    r'^[a-zA-Z0-9_]{3,20}$',
  );

  static const List<String> _availableRoles = [
    'student',
    'teacher',
  ];

  @override
  void initState() {
    super.initState();

    Future.delayed(
      const Duration(milliseconds: 250),
          () {
        if (!mounted || _isSubmitting) {
          return;
        }

        _usernameFocus.requestFocus();
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();

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

    final authProvider = context.read<AuthProvider>();

    final username = _normalizeUsername(
      _usernameController.text,
    );

    final email = _emailController.text.trim().toLowerCase();

    final password = _passwordController.text;

    final role = _availableRoles.contains(_role) ? _role : 'student';

    try {
      setState(() {
        _isSubmitting = true;
      });

      if (authProvider.isGuest) {
        await authProvider.signOut();
      }

      await authProvider.signUp(
        email,
        password,
        username,
        role,
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

  String _normalizeUsername(String value) {
    final username = value.trim();

    if (username.startsWith('@')) {
      return username.substring(1).toLowerCase();
    }

    return username.toLowerCase();
  }

  String _roleLocalizationKey(String role) {
    switch (role) {
      case 'teacher':
        return 'roles.teacher';

      case 'student':
      default:
        return 'roles.student';
    }
  }

  // =========================================================
  // ROLE
  // =========================================================

  List<DropdownMenuItem<String>> _roleItems() {
    return _availableRoles.map((role) {
      return DropdownMenuItem<String>(
        value: role,
        child: _buildRoleText(
          _roleLocalizationKey(role).tr(),
        ),
      );
    }).toList();
  }

  List<Widget> _selectedRoleItems() {
    return _availableRoles.map((role) {
      return _buildSelectedRoleText(
        _roleLocalizationKey(role).tr(),
      );
    }).toList();
  }

  Widget _buildRoleText(String text) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSelectedRoleText(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
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
  // UI
  // =========================================================

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _register,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _isSubmitting
              ? const SizedBox(
            key: ValueKey('register_loading'),
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
            ),
          )
              : Text(
            key: const ValueKey('register_text'),
            'auth.sign_up'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
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
                controller: _usernameController,
                focusNode: _usernameFocus,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.text,
                autofillHints: const [
                  AutofillHints.username,
                ],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'profile.username'.tr(),
                  hintText: 'users.search_hint'.tr(),
                  prefixIcon: const Icon(
                    Icons.alternate_email,
                  ),
                ),
                onChanged: (value) {
                  final normalized = _normalizeUsername(value);

                  if (value != normalized && value.isNotEmpty) {
                    _usernameController.value = TextEditingValue(
                      text: normalized,
                      selection: TextSelection.collapsed(
                        offset: normalized.length,
                      ),
                    );
                  }
                },
                onFieldSubmitted: (_) {
                  _emailFocus.requestFocus();
                },
                validator: (value) {
                  final username = _normalizeUsername(
                    value ?? '',
                  );

                  if (username.isEmpty) {
                    return 'validation.empty_field'.tr();
                  }

                  if (username.length < 3) {
                    return 'validation.short_username'.tr();
                  }

                  if (!_usernameRegex.hasMatch(username)) {
                    return 'validation.invalid_username'.tr();
                  }

                  return null;
                },
              ),
              0,
            ),
            const SizedBox(height: 16),
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
                decoration: InputDecoration(
                  labelText: 'auth.email_label'.tr(),
                  hintText: 'auth.email_hint'.tr(),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                  ),
                ),
                onFieldSubmitted: (_) {
                  _passwordFocus.requestFocus();
                },
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
              100,
            ),
            const SizedBox(height: 16),
            _animated(
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                enabled: !_isSubmitting,
                autofillHints: const [
                  AutofillHints.newPassword,
                ],
                obscureText: !_isPasswordVisible,
                textInputAction: TextInputAction.done,
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
                onFieldSubmitted: (_) {
                  _register();
                },
              ),
              200,
            ),
            const SizedBox(height: 16),
            _animated(
              DropdownButtonFormField<String>(
                initialValue: _role,
                isExpanded: true,
                selectedItemBuilder: (_) {
                  return _selectedRoleItems();
                },
                decoration: InputDecoration(
                  labelText: 'auth.select_role'.tr(),
                  prefixIcon: const Icon(
                    Icons.school_outlined,
                  ),
                ),
                items: _roleItems(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _role = value;
                  });
                },
              ),
              300,
            ),
            const SizedBox(height: 30),
            _animated(
              _buildRegisterButton(),
              400,
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          'auth.register_title'.tr(),
        ),
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