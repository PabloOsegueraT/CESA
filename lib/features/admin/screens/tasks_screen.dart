import 'package:flutter/material.dart';
import '../../../models/task.dart';
import '../../../design_system/widgets/task_card.dart';
import 'task_detail_screen.dart';

enum _DateFilter { all, today, thisWeek }

class AdminTasksScreen extends StatefulWidget {
  final List<Task> tasks;
  final String adminName; // nombre visible del admin para "Mis tareas"
  const AdminTasksScreen({super.key, required this.tasks, required this.adminName});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _query = '';
  _DateFilter _date = _DateFilter.all;
  Set<TaskStatus> _status = { TaskStatus.pending, TaskStatus.inProgress, TaskStatus.done };
  Set<TaskPriority> _priority = { TaskPriority.low, TaskPriority.medium, TaskPriority.high };
  String? _userFilter; // solo se usa en la pestaña "Del equipo"

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Split de tareas
    final myTasks = widget.tasks.where((t) => t.assignee == widget.adminName).toList();
    final teamTasks = widget.tasks.where((t) => t.assignee != widget.adminName).toList();

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
                  onChanged: (q) => setState(() => _query = q.trim().toLowerCase()),
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
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
              ),
              _TasksList(
                tasks: _applyAllFilters(teamTasks, alsoFilterUser: true),
                onTap: _openDetail,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Aplica texto, fecha, estado, prioridad; y usuario (solo en “Del equipo”)
  List<Task> _applyAllFilters(List<Task> source, {required bool alsoFilterUser}) {
    final now = DateTime.now();
    bool inThisWeek(DateTime d) {
      // semana "natural": lunes-domingo
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: (DateTime.now().weekday + 6) % 7));
      final end = start.add(const Duration(days: 7));
      return (d.isAfter(start) || _sameDay(d, start)) && d.isBefore(end);
    }

    return source.where((t) {
      // texto
      final matchText = _query.isEmpty ||
          t.title.toLowerCase().contains(_query) ||
          t.description.toLowerCase().contains(_query);

      // fecha
      final onlyDate = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day);
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
      final matchUser = !alsoFilterUser || _userFilter == null || _userFilter == '' || t.assignee == _userFilter;

      return matchText && matchDate && matchStatus && matchPriority && matchUser;
    }).toList();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _openDetail(Task t) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserTaskDetailScreen(task: t)),
    );
  }

  void _openFilters() {
    // Construimos el set de usuarios para el combo (en “Del equipo”)
    final users = widget.tasks.map((t) => t.assignee).toSet().toList()..sort();
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
                  const Text('Filtrar por', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),

                  // Fecha
                  const Text('Fecha', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: tempDate == _DateFilter.all,
                        onSelected: (_) => setLocal(() => tempDate = _DateFilter.all),
                      ),
                      ChoiceChip(
                        label: const Text('Hoy'),
                        selected: tempDate == _DateFilter.today,
                        onSelected: (_) => setLocal(() => tempDate = _DateFilter.today),
                      ),
                      ChoiceChip(
                        label: const Text('Semana'),
                        selected: tempDate == _DateFilter.thisWeek,
                        onSelected: (_) => setLocal(() => tempDate = _DateFilter.thisWeek),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Estado
                  const Text('Estado', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Pendiente'),
                        selected: tempStatus.contains(TaskStatus.pending),
                        onSelected: (_) {
                          setLocal(() {
                            tempStatus.toggle(TaskStatus.pending);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('En proceso'),
                        selected: tempStatus.contains(TaskStatus.inProgress),
                        onSelected: (_) {
                          setLocal(() {
                            tempStatus.toggle(TaskStatus.inProgress);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Completada'),
                        selected: tempStatus.contains(TaskStatus.done),
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
                  const Text('Prioridad', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Baja'),
                        selected: tempPriority.contains(TaskPriority.low),
                        onSelected: (_) {
                          setLocal(() {
                            tempPriority.toggle(TaskPriority.low);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Media'),
                        selected: tempPriority.contains(TaskPriority.medium),
                        onSelected: (_) {
                          setLocal(() {
                            tempPriority.toggle(TaskPriority.medium);
                          });
                        },
                      ),
                      FilterChip(
                        label: const Text('Alta'),
                        selected: tempPriority.contains(TaskPriority.high),
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
                    const Text('Usuario', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: (tempUser?.isEmpty ?? true) ? 'Todos' : tempUser,
                      items: users.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setLocal(() {
                        tempUser = (v == 'Todos') ? null : v;
                      }),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
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
}

class _TasksList extends StatelessWidget {
  final List<Task> tasks;
  final void Function(Task) onTap;
  const _TasksList({required this.tasks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Sin resultados con los filtros actuales',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(.7))),
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
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Editar'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.reply_outlined), title: const Text('Devolver a pendiente'), onTap: () => Navigator.pop(context)),
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
