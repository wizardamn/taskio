import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../providers/project_provider.dart';
// ✅ ИСПРАВЛЕНИЕ 1: Используем ProjectModel
import '../../models/project_model.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ProjectProvider>();

    // ✅ ИСПРАВЛЕНИЕ 2: Используем List<ProjectModel>
    final events = _groupProjectsByDate(prov.view);

    return Scaffold(
      appBar: AppBar(title: const Text('Календарь проектов')),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ru_RU',
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            // ✅ ИСПРАВЛЕНИЕ 3: eventLoader использует List<ProjectModel>
            eventLoader: (day) => events[DateUtils.dateOnly(day)] ?? [],
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.deepOrange,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text('Выберите дату'))
            // ✅ ИСПРАВЛЕНИЕ 4: _buildEventList использует List<ProjectModel>
                : _buildEventList(events[DateUtils.dateOnly(_selectedDay!)] ?? []),
          ),
        ],
      ),
    );
  }

  /// Группировка проектов по дате дедлайна
  // ✅ ИСПРАВЛЕНИЕ 5: Используем ProjectModel в сигнатуре и теле
  Map<DateTime, List<ProjectModel>> _groupProjectsByDate(List<ProjectModel> projects) {
    final Map<DateTime, List<ProjectModel>> data = {};
    for (final project in projects) {
      final date = DateUtils.dateOnly(project.deadline);
      data.putIfAbsent(date, () => []);
      data[date]!.add(project);
    }
    return data;
  }

  /// Список проектов для выбранного дня
  // ✅ ИСПРАВЛЕНИЕ 6: Используем List<ProjectModel>
  Widget _buildEventList(List<ProjectModel> projects) {
    if (projects.isEmpty) {
      return const Center(child: Text('На этот день нет проектов'));
    }

    return ListView.separated(
      itemCount: projects.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = projects[index];
        return ListTile(
          leading: const Icon(Icons.assignment, color: Colors.blue),
          title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            // ✅ ИСПРАВЛЕНИЕ 7: Используем p.statusEnum.text
            'Дедлайн: ${DateFormat('dd.MM.yyyy').format(p.deadline)}\nСтатус: ${p.statusEnum.text}',
          ),
          onTap: () => _showProjectDetails(context, p),
        );
      },
    );
  }

  /// Диалог с подробностями проекта
  // ✅ ИСПРАВЛЕНИЕ 8: Используем ProjectModel
  void _showProjectDetails(BuildContext context, ProjectModel project) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(project.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 💡 ПРИМЕЧАНИЕ: description не может быть null в ProjectModel
            Text('Описание: ${project.description.isEmpty ? "Нет" : project.description}'),
            const SizedBox(height: 8),
            // ✅ ИСПРАВЛЕНИЕ 9: Используем p.statusEnum.text
            Text('Статус: ${project.statusEnum.text}'),
            Text('Дедлайн: ${DateFormat('dd.MM.yyyy').format(project.deadline)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}