// lib/features/admin/admin_shell.dart
import 'dart:convert';
import 'screens/users_screen.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/env.dart';
import '../../models/task.dart';
import '../../design_system/widgets/task_card.dart';
import '../../state/auth_controller.dart';
import '../../state/notifications_controller.dart';
import '../../state/profile_controller.dart';

import 'screens/dashboard_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/forums_screen.dart';
import 'screens/task_detail_screen.dart';
import 'screens/task_form_screen.dart';
import 'screens/tasks_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  final GlobalKey<AdminForumsScreenState> _forumsKey =
  GlobalKey<AdminForumsScreenState>();

  // 🔥 AHORA: estado real para tareas del calendario
  bool _loading = true;
  final List<Task> _tasks = [];

  // Solo se usa para el módulo de foros
  final List<String> assignees = ['Pablo', 'Marco', 'Andoni', 'Joaquín', 'Admin'];

  // 🔥 NUEVO: cargar TODAS las tareas desde el backend
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllTasks();
    });
  }

  Future<void> _loadAllTasks() async {
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/tasks');
      final resp = await http.get(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'x-role': 'admin', // o 'root' si quieres
          'x-user-id': '1',
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        // 👇 Ajusta esto si tu API regresa otro formato
        // Caso 1: { "tasks": [ ... ] }
        List<dynamic> rawList;
        if (data is Map<String, dynamic>) {
          rawList = (data['tasks'] as List<dynamic>? ?? []);
        } else if (data is List<dynamic>) {
          // Caso 2: [ ... ] directo
          rawList = data;
        } else {
          rawList = [];
        }

        final loaded = rawList
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();

        if (!mounted) return;
        setState(() {
          _tasks
            ..clear()
            ..addAll(loaded);
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar tareas: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al cargar tareas: $e'),
        ),
      );
    }
  }

  /// Abre el formulario de nueva tarea,
  /// manda la tarea al backend y la agrega a `_tasks` (para el calendario).
  Future<void> _openCreateTask() async {
    // 1) Cargar usuarios reales desde la API
    List<Map<String, dynamic>> users = [];
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/users');
      final resp = await http.get(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          // En dev simulamos ser admin
          'x-role': 'admin',
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar usuarios para asignar: ${resp.statusCode}',
            ),
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al cargar usuarios para asignar: $e'),
        ),
      );
      return;
    }

    if (users.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay usuarios para asignar tareas'),
        ),
      );
      return;
    }

    // 2) Nombres para el dropdown del formulario (ya no demos)
    final assigneeNames = users.map((u) => u['name'] as String).toList();

    // 3) Abrir tu pantalla de formulario con nombres reales
    final Task? localTask = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (_) => AdminTaskFormScreen(assignees: assigneeNames),
      ),
    );

    // Usuario canceló
    if (localTask == null) return;

    // 4) Mapear prioridad enum -> string para el backend
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

    // 5) Buscar el id del usuario por nombre seleccionado (sin usar orElse)
    final assigneeName = localTask.assignee;
    Map<String, dynamic>? assigneeMap;

    for (final u in users) {
      if (u['name'] == assigneeName) {
        assigneeMap = u;
        break;
      }
    }

    final int? assigneeId =
    assigneeMap != null ? assigneeMap['id'] as int : null;

    // 6) Cuerpo para el backend
    final body = {
      'title': localTask.title,
      'description': localTask.description,
      // yyyy-MM-dd
      'dueDate': localTask.dueDate.toIso8601String().substring(0, 10),
      'priority': priorityCode,
      'assigneeId': assigneeId, // id real de la BD (o null = sin asignar)
    };

    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/tasks');
      final resp = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'x-role': 'admin', // o 'root'
          'x-user-id': '1',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;

        // Task.fromJson debe convertir el JSON de la API a tu modelo
        final created = Task.fromJson(data);

        if (!mounted) return;

        // 🔥 Lo agregamos a la lista que usa el calendario
        setState(() {
          _tasks.insert(0, created);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea creada correctamente')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear tarea: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al crear tarea: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👇 TOMAMOS EL NOMBRE REAL DEL PERFIL
    final profile = ProfileControllerProvider.maybeOf(context);
    final adminName = profile?.displayName ?? 'Admin';

    final pages = [
      const AdminDashboardScreen(),
      AdminTasksScreen(
        adminName: adminName, // 👈 aquí se usa el nombre logueado
      ),
      // 🔥 Calendario ahora recibe _tasks (de la BD)
      AdminCalendarScreen(tasks: _tasks),
      AdminForumsScreen(
        key: _forumsKey,
        assignees: assignees,
      ),
      const _AdminMoreScreen(),
    ];

    final titles = [
      'Dashboard',
      'Tareas',
      'Calendario',
      'Foros',
      'Más',
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rounded),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            label: 'Foros',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            label: 'Más',
          ),
        ],
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
        onPressed: _openCreateTask,
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      )
          : _tab == 3
          ? FloatingActionButton.extended(
        onPressed: () =>
            _forumsKey.currentState?.openCreateForum(context),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nuevo foro'),
      )
          : null,
    );
  }
}


class _AdminMoreScreen extends StatelessWidget {
  const _AdminMoreScreen();

  @override
  Widget build(BuildContext context) {
    final auth = AuthControllerProvider.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Perfil
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Perfil'),
          onTap: () => Navigator.of(context).pushNamed('/profile'),
        ),

        // Ajustes
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Ajustes'),
          onTap: () => Navigator.of(context).pushNamed('/settings'),
        ),

        // Notificaciones
        ListTile(
          leading: const Icon(Icons.notifications_none),
          title: const Text('Notificaciones'),
          onTap: () => Navigator.of(context).pushNamed('/notifications'),
        ),

        // --- Usuarios (root / admin) ---
        if (auth.canSeeUsersModule) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('Usuarios'),
            subtitle: Text(
              auth.isRoot
                  ? 'Ver, crear, eliminar, cambiar contraseñas'
                  : 'Ver',
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminUsersScreen(),
                ),
              );
            },
          ),
        ],


        const Divider(),
        // Cerrar sesión
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Cerrar sesión'),
          onTap: () => _confirmLogout(context),
        ),
      ],
    );
  }
}

Future<void> _confirmLogout(BuildContext context) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cerrar sesión'),
      content: const Text('¿Seguro que quieres salir de tu cuenta?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(ctx).pop(true),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );

  if (ok == true) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/auth', (route) => false);
  }
}
