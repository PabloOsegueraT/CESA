import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../models/task.dart';
import '../../../design_system/widgets/task_card.dart';
import 'task_detail_screen.dart';
import '../../../core/constants/env.dart'; // Env.apiBaseUrl
import 'task_form_screen.dart';
import '../../../state/profile_controller.dart';
import 'task_detail_screen.dart';

enum _DateFilter { all, today, thisWeek }

class AdminTasksScreen extends StatefulWidget {
  final String adminName; // nombre visible del admin para "Mis tareas"

  const AdminTasksScreen({
    super.key,
    required this.adminName,
  });

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();


}

class _AdminTasksScreenState extends State<AdminTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  bool _loading = true;
  List<Task> _tasks = [];

  String _query = '';
  _DateFilter _date = _DateFilter.all;
  Set<TaskStatus> _status = {
    TaskStatus.pending,
    TaskStatus.inProgress,
    TaskStatus.done
  };
  Set<TaskPriority> _priority = {
    TaskPriority.low,
    TaskPriority.medium,
    TaskPriority.high
  };
  String? _userFilter; // solo se usa en la pestaña "Del equipo"

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ========= API =========

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/tasks');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // o 'root' en dev
          'x-user-id': '1',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['tasks'] as List<dynamic>? ?? []);
        final loaded = list
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _tasks = loaded;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
              Text('Error al cargar tareas: ${resp.statusCode}'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de red al cargar tareas: $e'),
          ),
        );
      }
    }
  }

  Future<void> openCreateTask(BuildContext context) async {
    // 1) Cargar usuarios de la API
    List<Map<String, dynamic>> users = [];
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/users');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // o 'root' en dev
          'x-user-id': '1',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['users'] as List<dynamic>? ?? []);
        users = list
            .map((u) => {
          'id': u['id'] as int,
          'name': (u['name'] ?? '').toString(),
          'email': (u['email'] ?? '').toString(),
        })
            .toList()
          ..sort(
                (a, b) => a['name'].toString().compareTo(b['name'].toString()),
          );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al cargar usuarios para asignar: ${resp.statusCode}',
              ),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error de red al cargar usuarios para asignar: $e'),
          ),
        );
      }
      return;
    }

    if (users.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay usuarios para asignar tareas'),
          ),
        );
      }
      return;
    }

    // 2) Nombres para el dropdown del formulario
    final assigneeNames = users.map((u) => u['name'] as String).toList();

    // 3) Abrir formulario y esperar la Task local
    final Task? localTask = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (_) => AdminTaskFormScreen(assignees: assigneeNames),
      ),
    );

    // Si canceló, no hacemos nada
    if (localTask == null) return;

    // 4) Mapear prioridad enum -> string
    String priorityCode;
    switch (localTask.priority) {
      case TaskPriority.low:
        priorityCode = 'low';
        break;
      case TaskPriority.medium:
        priorityCode = 'medium';
        break;
      case TaskPriority.high:
        priorityCode = 'high';
        break;
    }

    // 5) Buscar el id del usuario por nombre seleccionado
    final assigneeName = localTask.assignee;
    final assignee = users.firstWhere(
          (u) => u['name'] == assigneeName,
      orElse: () => {'id': null},
    );
    final int? assigneeId = assignee['id'] as int?;

    final body = {
      'title': localTask.title,
      'description': localTask.description,
      'priority': priorityCode,
      'dueDate': localTask.dueDate.toIso8601String().substring(0, 10),
      'assigneeId': assigneeId,
    };

    // 6) POST /api/tasks
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/tasks');
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // o 'root'
          'x-user-id': '1',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final created = Task.fromJson(data);

        if (!mounted) return;

        // 🔥 AQUÍ ES DONDE SE ACTUALIZA LA LISTA, IGUAL QUE EN FOROS
        setState(() {
          _tasks.insert(0, created); // o _tasks.add(created);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea creada correctamente')),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear tarea: ${resp.statusCode}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de red al crear tarea: $e'),
          ),
        );
      }
    }
  }
  Future<void> _updateTaskStatus(Task task) async {
    String statusCode;
    switch (task.status) {
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
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/tasks/${task.id}/status');
      final resp = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          // Aquí podrías usar el rol real del usuario logueado:
          'x-role': 'admin', // o 'usuario'
          'x-user-id': '1',
        },
        body: jsonEncode({'status': statusCode}),
      );

      if (resp.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'No se pudo actualizar el estado (${resp.statusCode})'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error de red al actualizar estado de tarea: $e'),
          ),
        );
      }
    }
  }

  // ========= UI =========

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Split de tareas basado en adminName
    final myTasks =
    _tasks.where((t) => t.assignee == widget.adminName).toList();
    final teamTasks =
    _tasks.where((t) => t.assignee != widget.adminName).toList();

    return Column(
      children: [
        // Encabezado con búsqueda + filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por título o descripción',
                  ),
                  onChanged: (q) =>
                      setState(() => _query = q.trim().toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Filtros',
                onPressed: _openFilters,
                icon: const Icon(Icons.filter_list_rounded),
              ),
            ],
          ),
        ),

        // Pestañas
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TabBar(
            controller: _tab,
            labelStyle:
            const TextStyle(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Mis tareas'),
              Tab(text: 'Del equipo'),
            ],
          ),
        ),

        // Contenido
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _TasksList(
                tasks: _applyAllFilters(myTasks, alsoFilterUser: false),
                onTap: _openDetail,
                onEdit: _editTask,
                onResetToPending: _resetTaskToPending,
                onDelete: _deleteTask,
              ),
              _TasksList(
                tasks: _applyAllFilters(teamTasks, alsoFilterUser: true),
                onTap: _openDetail,
                onEdit: _editTask,
                onResetToPending: _resetTaskToPending,
                onDelete: _deleteTask,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Aplica texto, fecha, estado, prioridad; y usuario (solo en “Del equipo”)
  List<Task> _applyAllFilters(
      List<Task> source, {
        required bool alsoFilterUser,
      }) {
    final now = DateTime.now();

    bool inThisWeek(DateTime d) {
      // semana "natural": lunes-domingo
      final start = DateTime(now.year, now.month, now.day)
          .subtract(Duration(
          days: (DateTime.now().weekday + 6) % 7));
      final end = start.add(const Duration(days: 7));
      return (d.isAfter(start) || _sameDay(d, start)) &&
          d.isBefore(end);
    }

    return source.where((t) {
      // texto
      final matchText = _query.isEmpty ||
          t.title.toLowerCase().contains(_query) ||
          t.description.toLowerCase().contains(_query);

      // fecha
      final onlyDate = DateTime(
          t.dueDate.year, t.dueDate.month, t.dueDate.day);
      final today = DateTime(now.year, now.month, now.day);
      final matchDate = switch (_date) {
        _DateFilter.all => true,
        _DateFilter.today => _sameDay(onlyDate, today),
        _DateFilter.thisWeek => inThisWeek(onlyDate),
      };

      // estado
      final matchStatus = _status.contains(t.status);

      // prioridad
      final matchPriority = _priority.contains(t.priority);

      // usuario (solo en “Del equipo”)
      final matchUser = !alsoFilterUser ||
          _userFilter == null ||
          _userFilter == '' ||
          t.assignee == _userFilter;

      return matchText &&
          matchDate &&
          matchStatus &&
          matchPriority &&
          matchUser;
    }).toList();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _openDetail(Task t) async {
    final updated = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (_) => UserTaskDetailScreen(
          task: t,
          role: 'admin',      // 👈 MUY IMPORTANTE: exactamente 'admin'
          userId: 1,          // 👈 en dev, tu admin “demo”
          canManageTask: true,
          canDeleteAttachments: true,
        ),
      ),
    );

    if (updated == null) return;

    // Si cambió el estado, lo mandamos al backend
    if (updated.status != t.status) {
      await _updateTaskStatus(updated);
    }

    // Actualizamos en memoria
    setState(() {
      final idx = _tasks.indexWhere((element) => element.id == updated.id);
      if (idx != -1) {
        _tasks[idx] = updated;
      }
    });
  }

  void _openFilters() {
    // Construimos el set de usuarios para el combo (en “Del equipo”)
    final users =
    _tasks.map((t) => t.assignee).toSet().toList()
      ..sort();
    // Remueve admin
    users.removeWhere((u) => u == widget.adminName);
    users.insert(0, 'Todos');

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: false,
      builder: (ctx) {
        _DateFilter tempDate = _date;
        final tempStatus = Set<TaskStatus>.from(_status);
        final tempPriority = Set<TaskPriority>.from(_priority);
        String? tempUser = _userFilter;

        return StatefulBuilder(
          builder: (context, setLocal) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ListView(
                shrinkWrap: true,
                children: [
                  const Text(
                    'Filtrar por',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fecha
                  const Text(
                    'Fecha',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: tempDate == _DateFilter.all,
                        onSelected: (_) =>
                            setLocal(() => tempDate = _DateFilter.all),
                      ),
                      ChoiceChip(
                        label: const Text('Hoy'),
                        selected: tempDate == _DateFilter.today,
                        onSelected: (_) =>
                            setLocal(() => tempDate = _DateFilter.today),
                      ),
                      ChoiceChip(
                        label: const Text('Semana'),
                        selected: tempDate == _DateFilter.thisWeek,
                        onSelected: (_) => setLocal(
                                () => tempDate = _DateFilter.thisWeek),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Estado
                  const Text(
                    'Estado',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Pendiente'),
                        selected:
                        tempStatus.contains(TaskStatus.pending),
                        onSelected: (_) {
                          setLocal(() {
                            tempStatus.toggle(TaskStatus.pending);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('En proceso'),
                        selected: tempStatus
                            .contains(TaskStatus.inProgress),
                        onSelected: (_) {
                          setLocal(() {
                            tempStatus
                                .toggle(TaskStatus.inProgress);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Completada'),
                        selected:
                        tempStatus.contains(TaskStatus.done),
                        onSelected: (_) {
                          setLocal(() {
                            tempStatus.toggle(TaskStatus.done);
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Prioridad
                  const Text(
                    'Prioridad',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Baja'),
                        selected:
                        tempPriority.contains(TaskPriority.low),
                        onSelected: (_) {
                          setLocal(() {
                            tempPriority.toggle(TaskPriority.low);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Media'),
                        selected: tempPriority
                            .contains(TaskPriority.medium),
                        onSelected: (_) {
                          setLocal(() {
                            tempPriority.toggle(TaskPriority.medium);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Alta'),
                        selected:
                        tempPriority.contains(TaskPriority.high),
                        onSelected: (_) {
                          setLocal(() {
                            tempPriority.toggle(TaskPriority.high);
                          });
                        },
                      ),
                    ],
                  ),

                  // Usuario (solo si estamos en la pestaña "Del equipo")
                  if (_tab.index == 1) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Usuario',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: (tempUser?.isEmpty ?? true)
                          ? 'Todos'
                          : tempUser,
                      items: users
                          .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u),
                      ))
                          .toList(),
                      onChanged: (v) => setLocal(() {
                        tempUser =
                        (v == 'Todos') ? null : v;
                      }),
                      decoration: const InputDecoration(
                        prefixIcon:
                        Icon(Icons.person_outline),
                        labelText: 'Asignado a',
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _date = tempDate;
                        _status = tempStatus;
                        _priority = tempPriority;
                        _userFilter = tempUser;
                      });
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.done_all),
                    label: const Text('Aplicar filtros'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper para prioridad
  String _priorityToCode(TaskPriority p) => switch (p) {
    TaskPriority.low => 'low',
    TaskPriority.medium => 'medium',
    TaskPriority.high => 'high',
  };

  void _openMore(BuildContext ctx, Task task) {
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar tarea'),
              onTap: () {
                Navigator.pop(ctx);
                _editTask(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Devolver a pendiente'),
              onTap: () async {
                Navigator.pop(ctx);
                final updated = task.copyWith(status: TaskStatus.pending);
                await _updateTaskStatus(updated);
                setState(() {
                  final idx =
                  _tasks.indexWhere((e) => e.id == updated.id);
                  if (idx != -1) _tasks[idx] = updated;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Eliminar tarea',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteTask(task);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }


  Future<void> _confirmDeleteTask(Task task) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text(
          '¿Seguro que quieres eliminar la tarea "${task.title}"?\n\n'
              'Se eliminarán también las evidencias asociadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteTask(task);
    }
  }


  Future<void> _editTask(Task task) async {
    // 1) Cargar usuarios de la API (igual que en openCreateTask)
    List<Map<String, dynamic>> users = [];
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/users');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // o 'root'
          'x-user-id': '1',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['users'] as List<dynamic>? ?? []);
        users = list
            .map((u) => {
          'id': u['id'] as int,
          'name': (u['name'] ?? '').toString(),
          'email': (u['email'] ?? '').toString(),
        })
            .toList()
          ..sort(
                (a, b) => a['name'].toString().compareTo(b['name'].toString()),
          );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
              Text('Error al cargar usuarios para editar: ${resp.statusCode}'),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error de red al cargar usuarios para editar: $e'),
          ),
        );
      }
      return;
    }

    if (users.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay usuarios para asignar tareas'),
          ),
        );
      }
      return;
    }

    final assigneeNames = users.map((u) => u['name'] as String).toList();

    // 2) Abrir el formulario en modo edición
    final Task? updatedLocal = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (_) => AdminTaskFormScreen(
          assignees: assigneeNames,
          initialTask: task,
        ),
      ),
    );

    if (updatedLocal == null) return; // canceló

    // 3) Mapear prioridad enum -> string
    String priorityCode;
    switch (updatedLocal.priority) {
      case TaskPriority.low:
        priorityCode = 'low';
        break;
      case TaskPriority.medium:
        priorityCode = 'medium';
        break;
      case TaskPriority.high:
        priorityCode = 'high';
        break;
    }

    // 4) Buscar id del usuario asignado por nombre
    final assigneeName = updatedLocal.assignee;
    final assignee = users.firstWhere(
          (u) => u['name'] == assigneeName,
      orElse: () => {'id': null},
    );
    final int? assigneeId = assignee['id'] as int?;

    // 5) Cuerpo para el backend
    final body = {
      'title': updatedLocal.title,
      'description': updatedLocal.description,
      'priority': priorityCode,
      'dueDate': updatedLocal.dueDate.toIso8601String().substring(0, 10),
      'assigneeId': assigneeId,
    };

    // 6) PUT /api/tasks/:id
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/tasks/${task.id}');
      final resp = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // o 'root'
          'x-user-id': '1',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final updatedFromApi = Task.fromJson(data);

        if (mounted) {
          setState(() {
            final idx = _tasks.indexWhere((t) => t.id == updatedFromApi.id);
            if (idx != -1) {
              _tasks[idx] = updatedFromApi;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarea actualizada')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
              Text('Error al actualizar tarea: ${resp.statusCode}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de red al actualizar tarea: $e'),
          ),
        );
      }
    }
  }

  Future<void> _resetTaskToPending(Task task) async {
    final updated = task.copyWith(status: TaskStatus.pending);
    await _updateTaskStatus(updated);
    if (mounted) {
      setState(() {
        final idx = _tasks.indexWhere((t) => t.id == task.id);
        if (idx != -1) {
          _tasks[idx] = updated;
        }
      });
    }
  }

  Future<void> _deleteTask(Task task) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text(
          '¿Seguro que quieres eliminar la tarea "${task.title}"?\n\n'
              'Se eliminarán también las evidencias asociadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/tasks/${task.id}');
      final resp = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // o 'root'
          'x-user-id': '1',
        },
      );

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        if (mounted) {
          setState(() {
            _tasks.removeWhere((t) => t.id == task.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarea eliminada')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
              Text('Error al eliminar tarea: ${resp.statusCode}'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error de red al eliminar tarea: $e'),
          ),
        );
      }
    }
  }

}

class _TasksList extends StatelessWidget {
  final List<Task> tasks;
  final void Function(Task) onTap;
  final void Function(Task) onEdit;
  final void Function(Task) onResetToPending;
  final void Function(Task) onDelete;

  const _TasksList({
    required this.tasks,
    required this.onTap,
    required this.onEdit,
    required this.onResetToPending,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sin resultados con los filtros actuales',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(.7),
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: tasks.length,
      itemBuilder: (_, i) => TaskCard(
        task: tasks[i],
        onTap: () => onTap(tasks[i]),
        onMore: () => _openMore(context, tasks[i]),
      ),
    );
  }

  void _openMore(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar tarea'),
              onTap: () {
                Navigator.pop(ctx);
                onEdit(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Devolver a pendiente'),
              onTap: () {
                Navigator.pop(ctx);
                onResetToPending(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar tarea'),
              onTap: () {
                Navigator.pop(ctx);
                onDelete(task);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// --- helpers ---
extension on Set<TaskStatus> {
  void toggle(TaskStatus s) => contains(s) ? remove(s) : add(s);
}

extension on Set<TaskPriority> {
  void toggle(TaskPriority p) => contains(p) ? remove(p) : add(p);
}