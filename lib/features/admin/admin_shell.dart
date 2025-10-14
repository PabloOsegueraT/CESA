import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../design_system/widgets/task_card.dart';
import '../../state/auth_controller.dart';
import '../../state/notifications_controller.dart';
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
  final GlobalKey<AdminForumsScreenState> _forumsKey = GlobalKey<AdminForumsScreenState>();
  final List<String> assignees = ['Pablo', 'Marco', 'Andoni', 'Joaquín', 'Admin'];


  final tasks = List.generate(8, (i) => Task(
    id: 't$i',
    title: 'Tarea crítica #$i',
    description: 'Descripción corta de la tarea número $i con detalles…',
    dueDate: DateTime.now().add(Duration(days: i - 2)),
    priority: i % 3 == 0 ? TaskPriority.high : (i % 3 == 1 ? TaskPriority.medium : TaskPriority.low),
    status: i % 3 == 0 ? TaskStatus.pending : (i % 3 == 1 ? TaskStatus.inProgress : TaskStatus.done),
    assignee: i % 2 == 0 ? 'Pablo' : 'Marco',
    evidenceCount: i,
    commentsCount: 2 * i,
  ));

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AdminDashboardScreen(),
      AdminTasksScreen(tasks: tasks, adminName: 'Admin'),
      AdminCalendarScreen(tasks: tasks),
      AdminForumsScreen(                    // ← antes: AdminForumsScreen(key: _forumsKey)
        key: _forumsKey,
        assignees: assignees,               // ← INYECTA LA LISTA
      ),
      const _AdminMoreScreen(),
    ];

    final titles = [
      'Dashboard', 'Tareas', 'Calendario', 'Foros', 'Más'
    ];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.checklist_rounded), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Foros'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Más'),
        ],
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<Task>(
            MaterialPageRoute(
              builder: (_) => AdminTaskFormScreen(assignees: assignees),
            ),
          );
          if (created != null) {
            setState(() {
              // Inserta arriba de la lista o como prefieras
              (context as Element); // no necesario, solo setState
            });
            // Si tus tareas están en 'tasks' dentro de este State:
            setState(() => tasks.insert(0, created));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tarea creada')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      )
          : _tab == 3
          ? FloatingActionButton.extended(
        onPressed: () => _forumsKey.currentState?.openCreateForum(context),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nuevo foro'),
      )
          : null,

    );
  }
}

class _AdminTasksList extends StatelessWidget {
  final List<Task> tasks;
  const _AdminTasksList({required this.tasks});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (_, i) => TaskCard(
        task: tasks[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UserTaskDetailScreen(task: tasks[i])),
        ),
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

        // Notificaciones (con globo si ya lo tienes)
        ListTile(
          leading: const Icon(Icons.notifications_none),
          title: const Text('Notificaciones'),
          onTap: () => Navigator.of(context).pushNamed('/notifications'),
        ),

        // --- Sección Usuarios (visible para Root y Admin) ---
        if (auth.canSeeUsersModule) ...[
          const Divider(),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: const Text('Usuarios'),
            subtitle: Text(auth.isRoot
                ? 'Ver, crear, eliminar, cambiar contraseñas'
                : 'Ver'), // <- AJUSTA EL SUBTÍTULO
            onTap: () => Navigator.of(context).pushNamed('/admin-users'),
          ),
        ],


        const Divider(),
        // Cerrar sesión (con confirmación)
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
    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
  }
}

