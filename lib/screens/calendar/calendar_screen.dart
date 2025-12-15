import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../../providers/project_provider.dart';
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
    // Получаем провайдер и все проекты
    final ProjectProvider projectProvider = context.watch<ProjectProvider>();

    // Группируем проекты по дате дедлайна
    final Map<DateTime, List<ProjectModel>> events = _groupProjectsByDate(projectProvider.view);

    return Scaffold(
      appBar: AppBar(title: const Text('Календарь проектов')),
      body: Column(
        children: [
          TableCalendar(
            locale: 'ru_RU', // Убедитесь, что инициализация локали в main.dart поддерживает это
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
            // Загрузчик событий: возвращает список проектов для данного дня
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
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedDay == null
                ? const Center(child: Text('Выберите дату для просмотра проектов'))
                : _buildEventList(events[DateUtils.dateOnly(_selectedDay!)] ?? []),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<ProjectModel>> _groupProjectsByDate(List<ProjectModel> projects) {
    final Map<DateTime, List<ProjectModel>> data = {};
    for (final project in projects) {
      // Используем DateUtils.dateOnly, чтобы игнорировать время
      final DateTime date = DateUtils.dateOnly(project.deadline);
      data.putIfAbsent(date, () => []);
      data[date]!.add(project);
    }
    return data;
  }

  Widget _buildEventList(List<ProjectModel> projects) {
    if (projects.isEmpty) {
      return const Center(child: Text('На этот день нет проектов'));
    }

    return ListView.separated(
      itemCount: projects.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ProjectModel p = projects[index];
        return ListTile(
          leading: Icon(Icons.assignment, color: p.statusEnum.color), // Используем цвет статуса
          title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            'Дедлайн: ${DateFormat('dd.MM.yyyy HH:mm').format(p.deadline)}\nСтатус: ${p.statusEnum.text}',
          ),
          onTap: () => _showProjectDetails(context, p),
        );
      },
    );
  }

  void _showProjectDetails(BuildContext context, ProjectModel project) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(project.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Описание: ${project.description.isEmpty ? "Нет" : project.description}'),
            const SizedBox(height: 8),
            Text('Статус: ${project.statusEnum.text}'),
            Text('Дедлайн: ${DateFormat('dd.MM.yyyy HH:mm').format(project.deadline)}'),
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