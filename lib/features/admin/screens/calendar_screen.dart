// lib/features/admin/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../models/task.dart';

class AdminCalendarScreen extends StatefulWidget {
  final List<Task> tasks;

  const AdminCalendarScreen({
    super.key,
    required this.tasks,
  });

  @override
  State<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends State<AdminCalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
  }

  /// Tareas cuya fecha límite coincide con [day]
  List<Task> _tasksForDay(DateTime day) {
    return widget.tasks.where((t) {
      final d = t.dueDate;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        final date = _selectedDay ?? _focusedDay;
        final tasksForDay = _tasksForDay(date);

        final calendarCard = Card(
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TableCalendar<Task>(
              locale: 'es_MX',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2035, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                markersMaxCount: 3,
                todayDecoration: BoxDecoration(
                  color: Colors.purpleAccent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
              ),
              eventLoader: _tasksForDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
            ),
          ),
        );

        final tasksPanel = _DayTasksPanel(
          date: date,
          tasks: tasksForDay,
        );

        // Pantalla ancha: calendario a la izquierda, lista a la derecha
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 5,
                child: calendarCard,
              ),
              Flexible(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: tasksPanel,
                ),
              ),
            ],
          );
        }

        // Pantalla chica (cel / tablet en vertical): todo en scroll vertical
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            calendarCard,
            const SizedBox(height: 16),
            tasksPanel,
          ],
        );
      },
    );
  }
}

class _DayTasksPanel extends StatelessWidget {
  final DateTime date;
  final List<Task> tasks;

  const _DayTasksPanel({
    required this.date,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = DateFormat('d MMM y', 'es_MX').format(date);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 👈 evita overflow dentro de la card
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tareas para $dateStr',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vista rápida de las tareas con fecha límite en este día.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No hay tareas para este día.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const Divider(height: 8),
                itemBuilder: (_, i) {
                  final t = tasks[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Asignado a: ${t.assignee}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _StatusChip(status: t.status),
                    // Si luego quieres abrir el detalle:
                    // onTap: () { ... },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;

    switch (status) {
      case TaskStatus.pending:
        label = 'Pendiente';
        color = Colors.orangeAccent;
        break;
      case TaskStatus.inProgress:
        label = 'En proceso';
        color = Colors.lightBlueAccent;
        break;
      case TaskStatus.done:
        label = 'Completada';
        color = Colors.greenAccent;
        break;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
