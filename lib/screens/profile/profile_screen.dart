import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../providers/project_provider.dart';
import '../../models/profile_model.dart';
import '../../models/project_model.dart'; // <-- Нужно для ProjectStatus

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
        _nameController.text = profile.fullName;
      } else {
        debugPrint('[ProfileScreen] Профиль не найден при загрузке.');
        if (mounted) {
          setState(() {
            _loading = false;
            _profile = null;
          });
        }
        return;
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки профиля: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!mounted || !_formKey.currentState!.validate() || _profile == null) return;

    final newName = _nameController.text.trim();

    if (_profile != null && newName == _profile!.fullName) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет изменений для сохранения')),
        );
      }
      return;
    }

    try {
      // 1. Обновляем в БД
      if (_profile != null) {
        await Supabase.instance.client.from('profiles').update({
          'full_name': newName,
        }).eq('id', _profile!.id);
      }

      // 2. Обновляем метаданные Auth
      await Supabase.instance.client.auth.updateUser(UserAttributes(
        data: {'full_name': newName},
      ));

      if (!mounted) return;

      // Уведомляем ProjectProvider
      final prov = context.read<ProjectProvider>();
      // ИСПРАВЛЕНИЕ: Используем setUser вместо updateUserName.
      // Это обновит имя и безопасно перезагрузит состояние пользователя.
      await prov.setUser(_profile!.id, newName);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль успешно обновлён')),
      );

      if (_profile != null) {
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

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'student': return 'Учащийся';
      case 'teacher': return 'Преподаватель';
      case 'leader': return 'Руководитель проекта';
      default: return role;
    }
  }

  // --- БЛОК СТАТИСТИКИ (НОВОЕ) ---
  Widget _buildStatistics(BuildContext context) {
    // Получаем список проектов через watch, чтобы статистика обновлялась
    final projects = context.watch<ProjectProvider>().view;

    int totalProjects = projects.length;
    int completedProjects = projects.where((p) => p.statusEnum == ProjectStatus.completed).length;
    int inProgressProjects = projects.where((p) => p.statusEnum == ProjectStatus.inProgress).length;

    // Глобальный прогресс по задачам (считаем сумму задач из всех проектов)
    int totalTasks = 0;
    int completedTasks = 0;
    for (var p in projects) {
      totalTasks += p.totalTasks;
      completedTasks += p.completedTasks;
    }
    double overallProgress = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Статистика", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Ряд карточек с цифрами
        Row(
          children: [
            Expanded(child: _StatCard(title: 'Всего', value: '$totalProjects', color: Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(title: 'В работе', value: '$inProgressProjects', color: Colors.orange)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(title: 'Завершено', value: '$completedProjects', color: Colors.green)),
          ],
        ),

        const SizedBox(height: 12),

        // Глобальный прогресс выполнения задач
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4)
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Выполнение задач", style: TextStyle(fontWeight: FontWeight.w600)),
                  Text("${(overallProgress * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: overallProgress,
                  minHeight: 8,
                  backgroundColor: Colors.blue.shade50,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Выполнено $completedTasks из $totalTasks задач во всех проектах",
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              )
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
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

              // --- СТАТИСТИКА (ВСТАВКА) ---
              _buildStatistics(context),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Имя',
                    hintText: 'Иванов Иван Иванович'
                ),
                validator: (v) => v == null || v.isEmpty ? 'Введите имя' : null,
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, delay: 100.ms, duration: 300.ms, curve: Curves.easeOut),

              const SizedBox(height: 12),

              TextFormField(
                enabled: false,
                initialValue: profile.email,
                decoration: const InputDecoration(labelText: 'Email'),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, delay: 200.ms, duration: 300.ms, curve: Curves.easeOut),

              const SizedBox(height: 12),

              TextFormField(
                readOnly: true,
                initialValue: displayRole,
                decoration: const InputDecoration(
                    labelText: 'Роль',
                    prefixIcon: Icon(Icons.badge_outlined)
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, delay: 300.ms, duration: 300.ms, curve: Curves.easeOut),

              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить изменения'),
              ).animate().fadeIn(delay: 400.ms).scaleY(begin: 0.5, alignment: Alignment.bottomCenter, delay: 400.ms, duration: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// Виджет карточки статистики
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Используем withValues вместо deprecated withOpacity
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)
          ),
          const SizedBox(height: 4),
          Text(
              title,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8)),
              textAlign: TextAlign.center
          ),
        ],
      ),
    );
  }
}