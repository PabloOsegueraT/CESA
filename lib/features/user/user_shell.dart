import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../design_system/widgets/task_card.dart';
import '../../models/forum.dart';
import '../../design_system/widgets/message_bubble.dart';
import '../admin/screens/task_detail_screen.dart';
import 'screens/calendar_screen.dart';



class UserShell extends StatefulWidget {
  const UserShell({super.key});
  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _tab = 0;

  final tasks = List.generate(10, (i) => Task(
    id: 'u$i',
    title: 'Mi tarea #$i',
    description: 'Detalle breve para practicar cambios de estado…',
    dueDate: DateTime.now().add(Duration(days: i - 1)),
    priority: i % 3 == 0 ? TaskPriority.high : (i % 3 == 1 ? TaskPriority.medium : TaskPriority.low),
    status: TaskStatus.pending,
    assignee: 'Yo',
    evidenceCount: 0,
    commentsCount: 0,
  ));

  @override
  Widget build(BuildContext context) {
    final pages = [
      _UserTasksList(tasks: tasks),
      UserCalendarScreen(tasks: tasks, userName: 'Yo'), // ← aquí
      const _UserForumsScreen(),
      const _UserProgressScreen(),
      const _UserMoreScreen(),
    ];
    final titles = ['Mis tareas', 'Calendario', 'Foros', 'Progreso', 'Más'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_tab])),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outlined), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Foros'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Progreso'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Más'),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subir evidencia (demo)'))),
        icon: const Icon(Icons.upload_file),
        label: const Text('Subir evidencia'),
      )
          : null,
    );
  }
}
class _UserTasksList extends StatefulWidget {
  final List<Task> tasks;
  const _UserTasksList({required this.tasks});
  @override
  State<_UserTasksList> createState() => _UserTasksListState();
}

class _UserTasksListState extends State<_UserTasksList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.tasks.length,
      itemBuilder: (_, i) => TaskCard(
        task: widget.tasks[i],
        onTap: () async {
          final updated = await Navigator.of(context).push<Task>(
            MaterialPageRoute(builder: (_) => UserTaskDetailScreen(task: widget.tasks[i])),
          );
          if (updated != null) {
            setState(() => widget.tasks[i] = updated);
          }
        },
        onMore: () => _changeStatus(context, i),
      ),
    );
  }

  void _changeStatus(BuildContext context, int i) {
    final t = widget.tasks[i];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pause_circle_outline),
              title: const Text('Marcar como Pendiente'),
              onTap: () { setState(() => widget.tasks[i] = t.copyWith(status: TaskStatus.pending)); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Marcar como En proceso'),
              onTap: () { setState(() => widget.tasks[i] = t.copyWith(status: TaskStatus.inProgress)); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Marcar como Completada'),
              onTap: () { setState(() => widget.tasks[i] = t.copyWith(status: TaskStatus.done)); Navigator.pop(context); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _UserCalendarScreen extends StatelessWidget {
  const _UserCalendarScreen();
  @override
  Widget build(BuildContext context) => const Center(child: Text('Calendario (demo)'));
}

class _UserForumsScreen extends StatefulWidget {
  const _UserForumsScreen();
  @override
  State<_UserForumsScreen> createState() => _UserForumsScreenState();
}

class _UserForumsScreenState extends State<_UserForumsScreen> {
  final List<Forum> forums = [
    Forum(
      id: 'f1',
      title: 'Ayuda con tarea #2',
      description: 'Preguntas y respuestas entre usuarios y admin.',
      messagesCount: 5,
    ),
    Forum(
      id: 'f2',
      title: 'Dudas generales',
      description: 'Espacio para dudas varias.',
      messagesCount: 11,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: forums.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final f = forums[i];
        return ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: Theme.of(context).colorScheme.surface,
          leading: const Icon(Icons.forum_outlined),
          title: Text(
            f.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            f.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 18),
              Text('${f.messagesCount}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _UserForumDetailScreen(forum: f)),
          ),
        );
      },
    );
  }
}

class _UserForumDetailScreen extends StatefulWidget {
  final Forum forum;
  const _UserForumDetailScreen({required this.forum});
  @override
  State<_UserForumDetailScreen> createState() => _UserForumDetailScreenState();
}

class _UserForumDetailScreenState extends State<_UserForumDetailScreen> {
  final List<ForumMessage> messages = [
    ForumMessage(
      id: 'm1',
      author: 'Marco',
      text: '¿Cómo subo la evidencia?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
    ForumMessage(
      id: 'm2',
      author: 'Pablo',
      text: 'Desde la tarjeta de la tarea, botón subir.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 38)),
    ),
    ForumMessage(
      id: 'm3',
      author: 'Admin',
      text: 'Correcto, revisen fechas límite 👀',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      isAdmin: true,
    ),
  ];
  final _composer = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
      AppBar(title: Text(widget.forum.title, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final msg = messages[i];
                final isMine = msg.author == 'Yo'; // demo
                return MessageBubble(message: msg, isMine: isMine);
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _composer,
                    decoration:
                    const InputDecoration(hintText: 'Escribe un mensaje…'),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded),
                )
              ]),
            ),
          )
        ],
      ),
    );
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(
        ForumMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          author: 'Yo',
          text: text,
          timestamp: DateTime.now(),
        ),
      );
      widget.forum.messagesCount = messages.length;
      widget.forum.lastUpdated = DateTime.now();
    });
    _composer.clear();
  }
}


class _UserProgressScreen extends StatelessWidget {
  const _UserProgressScreen();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      _ProgressCard(title: 'Semanal', value: '72%'),
      _ProgressCard(title: 'Mensual', value: '65%'),
    ],
  );
}

class _ProgressCard extends StatelessWidget {
  final String title; final String value; const _ProgressCard({required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(height: 120, child: Center(child: Text('$title: $value'))),
    );
  }
}

class _UserMoreScreen extends StatelessWidget {
  const _UserMoreScreen();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('Perfil'),
          onTap: () => Navigator.of(context).pushNamed('/profile'),
        ),
        const ListTile(leading: Icon(Icons.notifications_none), title: Text('Notificaciones')),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Ajustes'),
          onTap: () => Navigator.of(context).pushNamed('/settings'),
        ),

        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Cerrar sesión'),
          onTap: () => _confirmLogout(context),
        ),

      ]

  );
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
