import 'package:flutter/material.dart';
import '../../../models/task.dart';
import '../../../design_system/widgets/task_card.dart';
import 'task_detail_screen.dart';

class AdminCalendarScreen extends StatefulWidget {
  final List<Task> tasks;
  const AdminCalendarScreen({super.key, required this.tasks});

  @override
  State<AdminCalendarScreen> createState() => _AdminCalendarScreenState();
}

class _AdminCalendarScreenState extends State<AdminCalendarScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildMonthDays(_month);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header de mes con navegación
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1);
              }),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Text(
              _monthLabel(_month),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1);
              }),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Encabezados de días
        Row(
          children: const [
            _Dow('Lun'), _Dow('Mar'), _Dow('Mié'), _Dow('Jue'),
            _Dow('Vie'), _Dow('Sáb'), _Dow('Dom'),
          ],
        ),
        const SizedBox(height: 6),

        // Grilla del mes
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (_, i) {
            final d = days[i];
            if (d == null) {
              // celda vacía (padding antes del día 1)
              return const SizedBox.shrink();
            }
            final hasTasks = _dayTasks(d).isNotEmpty;
            final isToday = _sameDay(d, DateTime.now());

            return _DayCell(
              date: d,
              isToday: isToday,
              hasDot: hasTasks,
              onTap: () => _openDayTasks(d),
            );
          },
        ),
        const SizedBox(height: 12),

        // Leyenda simple
        Row(
          children: [
            const _Dot(),
            const SizedBox(width: 6),
            Text('Día con tareas', style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
            )),
          ],
        ),
      ],
    );
  }

  // --- helpers de calendario ---

  List<DateTime?> _buildMonthDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    // weekday: 1=lunes ... 7=domingo. Queremos que la grilla empiece en Lunes.
    final leadingEmpty = (first.weekday + 6) % 7; // 0 si lunes, 6 si domingo
    final totalCells = leadingEmpty + last.day;
    final rows = (totalCells / 7).ceil();
    final cells = rows * 7;

    final List<DateTime?> out = List.filled(cells, null);
    for (int day = 1; day <= last.day; day++) {
      out[leadingEmpty + day - 1] = DateTime(month.year, month.month, day);
    }
    return out;
  }

  List<Task> _dayTasks(DateTime d) {
    return widget.tasks.where((t) => _sameDay(t.dueDate, d)).toList()
      ..sort((a, b) => a.priority.index.compareTo(b.priority.index));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthLabel(DateTime m) {
    const months = ['enero','febrero','marzo','abril','mayo','junio',
      'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return '${months[m.month - 1]} ${m.year}';
  }

  void _openDayTasks(DateTime day) {
    final items = _dayTasks(day);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: items.isEmpty
            ? Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No hay tareas el ${day.day}/${day.month}/${day.year}'),
        )
            : ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) => TaskCard(
            task: items[i],
            onTap: () {
              Navigator.pop(context); // cierra el sheet
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => UserTaskDetailScreen(task: items[i])),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Dow extends StatelessWidget {
  final String text;
  const _Dow(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final bool hasDot;
  final VoidCallback onTap;

  const _DayCell({
    super.key,
    required this.date,
    required this.isToday,
    required this.hasDot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? Theme.of(context).colorScheme.primary.withOpacity(.12) : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(.25),
          ),
        ),
        child: Stack(
          children: [
            // Número de día
            Positioned(
              top: 8, left: 10,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            // Punto indicador
            if (hasDot)
              const Positioned(
                bottom: 8, left: 0, right: 0,
                child: Center(child: _Dot()),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6, height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
