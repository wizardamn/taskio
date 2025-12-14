import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Анимации сохранены

import '../../services/auth_service.dart';
import '../../providers/project_provider.dart';
import '../../models/profile_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  ProfileModel? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getProfile();

      if (profile != null && mounted) {
        _profile = profile;
        // Обновляем контроллер только если _profile != null
        _nameController.text = profile.fullName;
      } else {
        // Если профиль не найден, можно установить значения по умолчанию или сообщить пользователю
        debugPrint('[ProfileScreen] Профиль не найден при загрузке.');
        // Например, можно установить _loading = false и показать ошибку в UI.
        if (mounted) {
          setState(() {
            _loading = false;
            _profile = null; // Убедимся, что _profile null
          });
        }
        return; // Прерываем выполнение, если профиль не найден
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _loading = false); // Убедимся, что спиннер исчезнет
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки профиля: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted && _loading) { // Обновляем состояние только если оно не было обновлено в catch
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    // --- ИСПРАВЛЕНО: Проверка на mounted, валидацию и !_profile!.isNull ---
    if (!mounted || !_formKey.currentState!.validate() || _profile == null) return;

    final newName = _nameController.text.trim();

    // --- ИСПРАВЛЕНО: Проверка на null перед сравнением ---
    if (_profile != null && newName == _profile!.fullName) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет изменений для сохранения')),
        );
      }
      return;
    }

    try {
      // 1. Обновляем полное имя в таблице profiles
      // --- ИСПРАВЛЕНО: Проверка на null перед доступом к .id ---
      if (_profile != null) {
        await Supabase.instance.client.from('profiles').update({
          'full_name': newName,
        }).eq('id', _profile!.id);
      }

      // 2. Обновляем метаданные Auth-пользователя
      await Supabase.instance.client.auth.updateUser(UserAttributes(
        data: {'full_name': newName},
      ));


      if (!mounted) return;

      // Уведомляем ProjectProvider об изменении имени
      final prov = context.read<ProjectProvider>();
      prov.updateUserName(newName);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль успешно обновлён')),
      );

      // --- ИСПРАВЛЕНО: Проверка на null перед обновлением локального состояния ---
      if (_profile != null) {
        // Обновляем локальное состояние
        setState(() {
          _profile = ProfileModel(
            id: _profile!.id,
            fullName: newName,
            role: _profile!.role,
            email: _profile!.email,
            createdAt: _profile!.createdAt,
          );
        });
      }

    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка БД: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось обновить профиль: $e')),
        );
      }
    }
  }

  // Утилита для получения отображаемого названия роли на русском
  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'student':
        return 'Учащийся';
      case 'teacher':
        return 'Преподаватель';
      case 'leader':
        return 'Руководитель проекта';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // --- ИСПРАВЛЕНО: Безопасная проверка на null перед использованием _profile ---
    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Профиль')),
        body: const Center(
          child: Text('Не удалось загрузить профиль. Пожалуйста, выйдите и войдите снова.'),
        ),
      );
    }

    final displayRole = _getRoleDisplayName(profile.role);

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Animate(
        effects: const [FadeEffect()],
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 12),
                // Аватар
                Center(
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.person, size: 50, color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ).animate().slideY(duration: 400.ms, curve: Curves.easeOut),

                const SizedBox(height: 30),

                // Поле для редактирования полного имени
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                      labelText: 'Поле имя',
                      hintText: 'Иванов Иван Иванович'
                  ),
                  validator: (v) =>
                  v == null || v.isEmpty ? 'Введите имя' : null,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, delay: 100.ms, duration: 300.ms, curve: Curves.easeOut),

                const SizedBox(height: 12),

                // Поле для email (только чтение)
                TextFormField(
                  enabled: false,
                  initialValue: profile.email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, delay: 200.ms, duration: 300.ms, curve: Curves.easeOut),

                const SizedBox(height: 12),

                // Поле для роли (только чтение)
                TextFormField(
                  readOnly: true,
                  initialValue: displayRole,
                  decoration: const InputDecoration(
                      labelText: 'Роль',
                      prefixIcon: Icon(Icons.badge_outlined)
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, delay: 300.ms, duration: 300.ms, curve: Curves.easeOut),

                const SizedBox(height: 30),

                // Кнопка сохранения
                ElevatedButton.icon(
                  onPressed: _saveProfile,
                  icon: const Icon(Icons.save),
                  label: const Text('Сохранить изменения'),
                ).animate().fadeIn(delay: 400.ms).scaleY(begin: 0.5, alignment: Alignment.bottomCenter, delay: 400.ms, duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}