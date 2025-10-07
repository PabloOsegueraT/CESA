import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../typography.dart';
import 'priority_chip.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onMore;

  const TaskCard({super.key, required this.task, this.onTap, this.onMore});

  bool get _isOverdue => DateTime.now().isAfter(task.dueDate) && task.status != TaskStatus.done;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PriorityChip(priority: task.priority),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: onMore,
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(radius: 10, child: Text(task.assignee.isNotEmpty ? task.assignee[0] : '?')),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task.assignee, style: const TextStyle(fontSize: 12))),
                  _DueDateBadge(date: task.dueDate, overdue: _isOverdue),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric(icon: Icons.attach_file, label: '${task.evidenceCount}'),
                  const SizedBox(width: 16),
                  _Metric(icon: Icons.chat_bubble_outline, label: '${task.commentsCount}'),
                  const Spacer(),
                  _StatusChip(status: task.status),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _DueDateBadge extends StatelessWidget {
  final DateTime date;
  final bool overdue;
  const _DueDateBadge({required this.date, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      color: overdue ? Colors.redAccent : Theme.of(context).colorScheme.onSurface.withOpacity(.9),
      fontWeight: FontWeight.w600,
    );
    return Row(children: [
      Icon(Icons.schedule, size: 16, color: style.color),
      const SizedBox(width: 4),
      Text(_label(date), style: style),
    ]);
  }

  String _label(DateTime d) {
    final now = DateTime.now();
    final inDays = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (inDays == 0) return 'Hoy';
    if (inDays == 1) return 'Mañana';
    if (inDays < 0) return '${inDays.abs()} d retraso';
    return 'En $inDays d';
  }
}

class _Metric extends StatelessWidget {
  final IconData icon; final String label;
  const _Metric({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 12))]);
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (status) {
      TaskStatus.pending => ('Pendiente', Colors.amberAccent),
      TaskStatus.inProgress => ('En proceso', Colors.lightBlueAccent),
      TaskStatus.done => ('Completada', Colors.greenAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.6)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}