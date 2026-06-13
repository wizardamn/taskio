import 'dart:async';

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

import '../../widgets/project_list_skeleton.dart';

import '../home/project_list_screen.dart';
import 'login_screen.dart';

class LoginWrapper extends StatefulWidget {
  const LoginWrapper({
    super.key,
  });

  @override
  State<LoginWrapper> createState() {
    return _LoginWrapperState();
  }
}

class _LoginWrapperState extends State<LoginWrapper> {
  final AuthService _authService = AuthService();

  Future<void>? _profileFuture;

  String? _loadedUserId;
  String? _lastProjectProviderUserId;
  String? _lastClearedState;

  bool _isSigningOut = false;

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // =====================================================
    // GUEST MODE
    // =====================================================

    if (authProvider.isGuest) {
      _resetProfileLoadingState();

      _scheduleProjectProviderClear(
        reason: 'guest',
      );

      return const ProjectListScreen();
    }

    // =====================================================
    // NOT AUTHORIZED
    // =====================================================

    if (!authProvider.isAuthenticated) {
      _resetProfileLoadingState();

      _scheduleProjectProviderClear(
        reason: 'unauthenticated',
      );

      return const LoginScreen();
    }

    final currentUserId = authProvider.userId?.trim();

    if (currentUserId == null || currentUserId.isEmpty) {
      _resetProfileLoadingState();

      _scheduleProjectProviderClear(
        reason: 'empty_user_id',
      );

      return const LoginScreen();
    }

    // =====================================================
    // LOAD PROFILE
    // =====================================================

    if (_loadedUserId != currentUserId || _profileFuture == null) {
      _loadedUserId = currentUserId;
      _lastClearedState = null;

      _profileFuture = _loadProfile(
        currentUserId,
      );
    }

    return FutureBuilder<void>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        if (snapshot.hasError) {
          AppLogger.error(
            'LoginWrapper FutureBuilder error',
            error: snapshot.error,
            tag: 'LoginWrapper',
          );

          _scheduleProjectProviderClear(
            reason: 'profile_error',
          );

          return const LoginScreen();
        }

        return const ProjectListScreen();
      },
    );
  }

  // =====================================================
  // PROJECT PROVIDER CLEAR
  // =====================================================

  void _scheduleProjectProviderClear({
    required String reason,
  }) {
    if (_lastClearedState == reason) {
      return;
    }

    _lastClearedState = reason;
    _lastProjectProviderUserId = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<ProjectProvider>().clear(
        keepProjects: false,
      );
    });
  }

  // =====================================================
  // RESET
  // =====================================================

  void _resetProfileLoadingState() {
    _profileFuture = null;
    _loadedUserId = null;
    _isSigningOut = false;
  }

  // =====================================================
  // LOAD PROFILE
  // =====================================================

  Future<void> _loadProfile(String userId) async {
    final authProvider = context.read<AuthProvider>();
    final projectProvider = context.read<ProjectProvider>();

    try {
      AppLogger.info(
        'Loading profile',
        tag: 'LoginWrapper',
      );

      final profile = authProvider.profile ?? await _authService.getProfile();

      if (!mounted) {
        return;
      }

      final currentAuthUserId = authProvider.userId?.trim();

      if (currentAuthUserId != userId) {
        return;
      }

      if (profile == null) {
        throw Exception(
          'errors.fetch_failed',
        );
      }

      final language = profile.language?.trim() ?? '';

      if (language.isNotEmpty) {
        await LocalizationHelper.applySavedLanguage(
          context,
          language,
        );
      }

      if (!mounted) {
        return;
      }

      String displayName = profile.fullName.trim();

      final username = profile.username.trim();

      if (displayName.isEmpty && username.isNotEmpty) {
        displayName = username;
      }

      if (displayName.isEmpty) {
        displayName = authProvider.user?.email ?? 'common.user'.tr();
      }

      final profileId = profile.id.trim();

      if (profileId.isEmpty) {
        throw Exception(
          'errors.fetch_failed',
        );
      }

      if (_lastProjectProviderUserId != profileId) {
        _lastProjectProviderUserId = profileId;

        await projectProvider.setUser(
          profileId,
          displayName,
        );
      }

      AppLogger.info(
        'Profile loaded successfully',
        tag: 'LoginWrapper',
      );
    } catch (e, st) {
      AppLogger.error(
        'Profile load failed',
        error: e,
        stackTrace: st,
        tag: 'LoginWrapper',
      );

      if (!mounted || _isSigningOut) {
        return;
      }

      _isSigningOut = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        SnackbarManager.showError(
          ErrorMapper.map(e),
        );
      });

      await authProvider.signOut();

      if (!mounted) {
        return;
      }

      projectProvider.clear(
        keepProjects: false,
      );

      _lastProjectProviderUserId = null;
    }
  }

  // =====================================================
  // UI
  // =====================================================

  Widget _buildLoading() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'navigation.my_projects'.tr(),
        ),
      ),
      body: const ProjectListSkeleton(),
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _profileFuture = null;
    _loadedUserId = null;
    _lastProjectProviderUserId = null;
    _lastClearedState = null;
    _isSigningOut = false;

    super.dispose();
  }
}