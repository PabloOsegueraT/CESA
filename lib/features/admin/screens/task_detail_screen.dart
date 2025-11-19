// lib/features/user/screens/task_detail_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../models/task.dart';
import '../../../core/constants/env.dart'; // Env.apiBaseUrl

class UserTaskDetailScreen extends StatefulWidget {
  final Task task;
  const UserTaskDetailScreen({super.key, required this.task});

  @override
  State<UserTaskDetailScreen> createState() => _UserTaskDetailScreenState();
}

class _UserTaskDetailScreenState extends State<UserTaskDetailScreen> {
  late Task _current;
  bool _saving = false;

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
              ButtonSegment(
                value: TaskStatus.pending,
                label: Text('Pendiente'),
                icon: Icon(Icons.pause_circle_outline),
              ),
              ButtonSegment(
                value: TaskStatus.inProgress,
                label: Text('En proceso'),
                icon: Icon(Icons.play_circle_outline),
              ),
              ButtonSegment(
                value: TaskStatus.done,
                label: Text('Completada'),
                icon: Icon(Icons.check_circle_outline),
              ),
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
              CircleAvatar(
                radius: 14,
                child: Text(_current.assignee.isNotEmpty ? _current.assignee[0] : '?'),
              ),
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

          // Acciones
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Aquí podrías abrir subir evidencia real
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
                  onPressed: _saving ? null : _saveChanges,
                  icon: _saving
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =================== LÓGICA DE ESTADO / API ===================

  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    // 1) Mapear TaskStatus -> código del backend
    String statusCode;
    switch (_current.status) {
      case TaskStatus.pending:
        statusCode = 'pending';
        break;
      case TaskStatus.inProgress:
        statusCode = 'in_progress';
        break;
      case TaskStatus.done:
        statusCode = 'done';
        break;
    }

    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/tasks/${_current.id}/status');

      final resp = await http.put(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          // En dev, simulamos que es un usuario normal:
          // TODO: reemplazar con el id real del usuario logueado
          'x-role': 'usuario',
          'x-user-id': '2',
        },
        body: jsonEncode({'status': statusCode}),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        // OK en servidor: regresamos la tarea actualizada al caller
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados')),
        );
        Navigator.pop(context, _current);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar en el servidor: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al guardar cambios: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // =================== HELPERS ===================

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
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}