import 'package:flutter/material.dart';
import '../../../models/task.dart';

class AdminTaskFormScreen extends StatefulWidget {
  final List<String> assignees; // nombres de usuarios (incluyéndote)
  final Task? initialTask;      // 👈 null = nueva, != null = editar

  const AdminTaskFormScreen({
    super.key,
    required this.assignees,
    this.initialTask,
  });

  @override
  State<AdminTaskFormScreen> createState() => _AdminTaskFormScreenState();
}

class _AdminTaskFormScreenState extends State<AdminTaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  late DateTime _dueDate;
  late TaskPriority _priority;
  String? _assignee;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      final t = widget.initialTask!;
      _titleCtrl.text = t.title;
      _descCtrl.text = t.description;
      _priority = t.priority;
      _dueDate = t.dueDate;
      // si no encontramos el nombre, tomamos el primero de la lista
      _assignee = t.assignee.isNotEmpty
          ? t.assignee
          : (widget.assignees.isNotEmpty ? widget.assignees.first : null);
    } else {
      _priority = TaskPriority.medium;
      _dueDate = DateTime.now().add(const Duration(days: 3));
      _assignee = widget.assignees.isNotEmpty ? widget.assignees.first : null;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar tarea' : 'Nueva tarea'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskPriority>(
                value: _priority,
                items: const [
                  DropdownMenuItem(
                    value: TaskPriority.low,
                    child: Text('Prioridad baja'),
                  ),
                  DropdownMenuItem(
                    value: TaskPriority.medium,
                    child: Text('Prioridad media'),
                  ),
                  DropdownMenuItem(
                    value: TaskPriority.high,
                    child: Text('Prioridad alta'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _priority = v ?? TaskPriority.medium),
                decoration: const InputDecoration(labelText: 'Prioridad'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _assignee,
                items: widget.assignees
                    .map(
                      (u) => DropdownMenuItem(
                    value: u,
                    child: Text(u),
                  ),
                )
                    .toList(),
                onChanged: (v) => setState(() => _assignee = v),
                decoration: const InputDecoration(labelText: 'Asignar a'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: const Text('Fecha límite'),
                subtitle: Text(_dateLabel(_dueDate)),
                onTap: _pickDate,
                trailing: const Icon(Icons.edit_calendar_outlined),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_isEditing ? 'Guardar cambios' : 'Guardar tarea'),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (res != null) setState(() => _dueDate = res);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final base = widget.initialTask;

    final task = Task(
      id: base?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      dueDate: _dueDate,
      priority: _priority,
      status: base?.status ?? TaskStatus.pending,
      assignee: _assignee ?? base?.assignee ?? 'Sin asignar',
      evidenceCount: base?.evidenceCount ?? 0,
      commentsCount: base?.commentsCount ?? 0,
    );

    Navigator.of(context).pop(task); // devolvemos la tarea al caller
  }

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