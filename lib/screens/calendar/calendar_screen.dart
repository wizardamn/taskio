import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/project_provider.dart';
import '../../models/project_model.dart';
import '../../utils/app_logger.dart';
import '../../utils/snackbar_manager.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<ProjectModel>> _cachedEvents = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateEvents();
  }

  void _updateEvents() {
    final projects = context.read<ProjectProvider>().projects;
    _cachedEvents = _groupProjectsByDate(projects);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final projects = provider.projects;

    _cachedEvents = _groupProjectsByDate(projects);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('navigation.calendar'.tr()),
      ),
      body: Column(
        children: [
          TableCalendar(
            locale: context.locale.toString(),
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) =>
                isSameDay(day, _selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            eventLoader: (day) =>
            _cachedEvents[DateUtils.dateOnly(day)] ?? [],
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: colorScheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _selectedDay == null
                ? _buildEmptyState('calendar.select_date'.tr())
                : _buildEventList(
              _cachedEvents[
              DateUtils.dateOnly(_selectedDay!)] ??
                  [],
            ),
          ),
        ],
      ),
    );
  }

  // ================= GROUP =================

  Map<DateTime, List<ProjectModel>> _groupProjectsByDate(
      List<ProjectModel> projects) {
    final Map<DateTime, List<ProjectModel>> data = {};

    for (final project in projects) {
      final date = DateUtils.dateOnly(project.deadline);
      data.putIfAbsent(date, () => []);
      data[date]!.add(project);
    }

    return data;
  }

  // ================= EMPTY =================

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, size: 48),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ================= LIST =================

  Widget _buildEventList(List<ProjectModel> projects) {
    if (projects.isEmpty) {
      return _buildEmptyState('calendar.no_projects'.tr());
    }

    final formatter =
    DateFormat('dd.MM.yyyy HH:mm', context.locale.languageCode);

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = projects[index];

        return Card(
          child: ListTile(
            leading: Icon(
              Icons.assignment,
              color: p.statusEnum.color,
            ),
            title: Text(
              p.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${'projects.deadline'.tr()}: '
                  '${formatter.format(p.deadline)}\n'
                  '${'projects.status'.tr()}: '
                  '${p.statusEnum.localizedText()}',
            ),
            onTap: () => _showProjectDetails(context, p),
          ),
        );
      },
    );
  }

  // ================= DETAILS =================

  void _showProjectDetails(
      BuildContext context,
      ProjectModel project) {
    try {
      final formatter =
      DateFormat('dd.MM.yyyy HH:mm', context.locale.languageCode);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(project.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${'projects.description'.tr()}: '
                    '${project.description.isEmpty
                    ? 'common.not_specified'.tr()
                    : project.description}',
              ),
              const SizedBox(height: 8),
              Text(
                '${'projects.status'.tr()}: '
                    '${project.statusEnum.localizedText()}',
              ),
              Text(
                '${'projects.deadline'.tr()}: '
                    '${formatter.format(project.deadline)}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.ok'.tr()),
            ),
          ],
        ),
      );
    } catch (e, st) {
      AppLogger.error(
        'Calendar dialog error',
        error: e,
        stackTrace: st,
      );
      SnackbarManager.showError('errors.unknown'.tr());
    }
  }
}