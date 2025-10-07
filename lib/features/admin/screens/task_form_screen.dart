import 'package:flutter/material.dart';
import '../../../models/task.dart';

class AdminTaskFormScreen extends StatefulWidget {
  final List<String> assignees; // nombres de usuarios (incluyéndote)
  const AdminTaskFormScreen({super.key, required this.assignees});

  @override
  State<AdminTaskFormScreen> createState() => _AdminTaskFormScreenState();
}

class _AdminTaskFormScreenState extends State<AdminTaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  TaskPriority _priority = TaskPriority.medium;
  String? _assignee;

  @override
  void initState() {
    super.initState();
    _assignee = widget.assignees.isNotEmpty ? widget.assignees.first : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva tarea')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
                  DropdownMenuItem(value: TaskPriority.low, child: Text('Prioridad baja')),
                  DropdownMenuItem(value: TaskPriority.medium, child: Text('Prioridad media')),
                  DropdownMenuItem(value: TaskPriority.high, child: Text('Prioridad alta')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? TaskPriority.medium),
                decoration: const InputDecoration(labelText: 'Prioridad'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _assignee,
                items: widget.assignees.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
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
            label: const Text('Guardar tarea'),
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
    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      dueDate: _dueDate,
      priority: _priority,
      status: TaskStatus.pending,
      assignee: _assignee ?? 'Sin asignar',
    );
    Navigator.of(context).pop(task); // devolvemos la tarea creada al caller
  }

  String _dateLabel(DateTime d) {
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
