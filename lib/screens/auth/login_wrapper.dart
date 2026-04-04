import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/project_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

import '../../utils/app_logger.dart';
import '../../utils/error_mapper.dart';
import '../../utils/snackbar_manager.dart';
import '../../utils/localization_helper.dart';

import '../home/project_list_screen.dart';
import 'login_screen.dart';

class LoginWrapper extends StatefulWidget {
  const LoginWrapper({super.key});

  @override
  State<LoginWrapper> createState() => _LoginWrapperState();
}

class _LoginWrapperState extends State<LoginWrapper> {
  final AuthService _authService = AuthService();

  Future<void>? _profileFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final authProvider = context.read<AuthProvider>();

    if (authProvider.isAuthenticated && _profileFuture == null) {
      _profileFuture = _loadProfile();
    }

    if (!authProvider.isAuthenticated) {
      _profileFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // =============================
    // Guest
    // =============================

    if (authProvider.isGuest) {
      _profileFuture = null;
      return const ProjectListScreen();
    }

    // =============================
    // Not logged
    // =============================

    if (!authProvider.isAuthenticated) {
      _profileFuture = null;
      return const LoginScreen();
    }

    // =============================
    // Logged
    // =============================

    return FutureBuilder(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        if (snapshot.hasError) {
          return const LoginScreen();
        }

        return const ProjectListScreen();
      },
    );
  }

  Future<void> _loadProfile() async {
    final authProvider = context.read<AuthProvider>();
    final projectProvider = context.read<ProjectProvider>();

    try {
      AppLogger.info('LoginWrapper: fetching profile');

      final profile = await _authService.getProfile();

      if (!mounted) return;

      if (profile == null) {
        throw Exception('errors.fetch_failed');
      }

      /// Language
      await LocalizationHelper.applySavedLanguage(
        context,
        profile.language,
      );

      /// Set user
      await projectProvider.setUser(
        profile.id,
        profile.fullName,
      );

      AppLogger.info('Profile successfully loaded');

    } catch (e, st) {

      AppLogger.error('LoginWrapper error', e);
      AppLogger.error('StackTrace', st);

      if (!mounted) return;

      SnackbarManager.showError(
        ErrorMapper.map(e),
      );

      await authProvider.signOut();
      projectProvider.clear(keepProjects: false);

      rethrow;
    }
  }

  Widget _buildLoading() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('common.loading'.tr()),
          ],
        ),
      ),
    );
  }
}