// lib/features/user/screens/task_detail_screen.dart
import 'package:flutter/material.dart';
import '../../../models/task.dart';

class UserTaskDetailScreen extends StatefulWidget {
  final Task task;
  const UserTaskDetailScreen({super.key, required this.task});


  @override
  State<UserTaskDetailScreen> createState() => _UserTaskDetailScreenState();
}

class _UserTaskDetailScreenState extends State<UserTaskDetailScreen> {
  late Task _current;

  @override
  void initState() {
    super.initState();
    _current = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_current.title, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Estado (selector)
          const Text('Estado', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<TaskStatus>(
            segments: const [
              ButtonSegment(value: TaskStatus.pending, label: Text('Pendiente'), icon: Icon(Icons.pause_circle_outline)),
              ButtonSegment(value: TaskStatus.inProgress, label: Text('En proceso'), icon: Icon(Icons.play_circle_outline)),
              ButtonSegment(value: TaskStatus.done, label: Text('Completada'), icon: Icon(Icons.check_circle_outline)),
            ],
            selected: {_current.status},
            onSelectionChanged: (s) {
              final status = s.first;
              setState(() => _current = _current.copyWith(status: status));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Estado: ${_label(status)}')),
              );
            },
          ),

          const SizedBox(height: 20),
          const Text('Prioridad', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_priorityLabel(_current.priority)),

          const SizedBox(height: 20),
          const Text('Asignado a', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(radius: 14, child: Text(_current.assignee.isNotEmpty ? _current.assignee[0] : '?')),
              const SizedBox(width: 8),
              Text(_current.assignee),
            ],
          ),

          const SizedBox(height: 20),
          const Text('Fecha límite', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_dateLabel(_current.dueDate)),

          const SizedBox(height: 20),
          const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_current.description.isEmpty ? '—' : _current.description),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Acciones comunes (demo)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Aquí podrías abrir subir evidencia
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Subir evidencia (demo)')),
                    );
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Subir evidencia'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _current), // devolver tarea actualizada
                  icon: const Icon(Icons.check),
                  label: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _label(TaskStatus s) => switch (s) {
    TaskStatus.pending => 'Pendiente',
    TaskStatus.inProgress => 'En proceso',
    TaskStatus.done => 'Completada',
  };

  String _priorityLabel(TaskPriority p) => switch (p) {
    TaskPriority.low => 'Baja',
    TaskPriority.medium => 'Media',
    TaskPriority.high => 'Alta',
  };

  String _dateLabel(DateTime d) {
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
