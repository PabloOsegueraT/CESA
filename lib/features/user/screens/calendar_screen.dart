// lib/features/user/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../models/task.dart';
import '../../../design_system/widgets/task_card.dart';

class UserCalendarScreen extends StatefulWidget {
  final List<Task> tasks;

  const UserCalendarScreen({
    super.key,
    required this.tasks,
  });

  @override
  State<UserCalendarScreen> createState() => _UserCalendarScreenState();
}

class _UserCalendarScreenState extends State<UserCalendarScreen> {
  late Map<DateTime, List<Task>> _eventsByDay;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  List<Task> _selectedTasks = [];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );
    _eventsByDay = _groupTasksByDay(widget.tasks);
    _selectedTasks = _getTasksForDay(_selectedDay);
  }

  // Se vuelve a agrupar si cambia la lista de tareas que viene del UserShell
  @override
  void didUpdateWidget(covariant UserCalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks) {
      _eventsByDay = _groupTasksByDay(widget.tasks);
      _selectedTasks = _getTasksForDay(_selectedDay);
    }
  }

  Map<DateTime, List<Task>> _groupTasksByDay(List<Task> tasks) {
    final Map<DateTime, List<Task>> data = {};

    for (final t in tasks) {
      final day = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
      data.putIfAbsent(day, () => []).add(t);
    }

    return data;
  }

  List<Task> _getTasksForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventsByDay[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return const Center(
        child: Text('Aún no tienes tareas asignadas'),
      );
    }

    return Column(
      children: [
        TableCalendar<Task>(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2100, 12, 31),
          focusedDay: _focusedDay,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarFormat: CalendarFormat.month,

          selectedDayPredicate: (day) =>
          day.year == _selectedDay.year &&
              day.month == _selectedDay.month &&
              day.day == _selectedDay.day,

          eventLoader: _getTasksForDay,

          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = DateTime(
                selectedDay.year,
                selectedDay.month,
                selectedDay.day,
              );
              _focusedDay = focusedDay;
              _selectedTasks = _getTasksForDay(selectedDay);
            });
          },

          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),

          calendarStyle: const CalendarStyle(
            // 👉 Puntitos debajo de los días con tareas
            markerDecoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            markersMaxCount: 3,

            // Día de hoy con borde
            todayDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(width: 2, color: Colors.blueAccent),
              ),
            ),

            // Día seleccionado rellenito
            selectedDecoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _selectedTasks.isEmpty
              ? const Center(
            child: Text('No tienes tareas para este día'),
          )
              : ListView.builder(
            itemCount: _selectedTasks.length,
            itemBuilder: (context, index) {
              final task = _selectedTasks[index];
              return TaskCard(task: task);
            },
          ),
        ),
      ],
    );
  }
}
