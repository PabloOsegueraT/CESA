// lib/features/user/user_shell.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/env.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/task.dart';
import '../../design_system/widgets/task_card.dart';
import '../../models/forum.dart';
import '../../design_system/widgets/message_bubble.dart';
import '../admin/screens/task_detail_screen.dart';
import 'screens/calendar_screen.dart';
import '../../state/profile_controller.dart';


class UserShell extends StatefulWidget {
  const UserShell({super.key});
  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _tab = 0;

  bool _loading = true;
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();

    // Ejecutar después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyTasks(); // ✅ aquí ya puedes usar ScaffoldMessenger.of(context)
    });
  }

  Future<void> _loadMyTasks() async {
    setState(() => _loading = true);

    try {
      // Obtenemos el perfil para saber el userId
      final profile = ProfileControllerProvider.maybeOf(context);
      final userId = profile?.userId;

      if (userId == null) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo determinar el usuario actual'),
            ),
          );
        }
        return;
      }

      final uri = Uri.parse('${Env.apiBaseUrl}/api/tasks/my');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          // En este módulo el usuario es "Usuario"
          'x-role': 'usuario',
          'x-user-id': userId.toString(),
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
              content: Text('Error al cargar tareas: ${resp.statusCode}'),
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

  /// Cuando una tarea cambia (por ejemplo, su estado) desde el detalle
  /// o el bottom sheet, actualizamos la lista _tasks del padre.
  void _onTaskUpdated(Task updated) {
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == updated.id);
      if (idx != -1) {
        _tasks[idx] = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileControllerProvider.maybeOf(context);
    final userName = (profile?.displayName ?? '').trim().isEmpty
        ? 'Yo'
        : profile!.displayName;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Las tareas que llegan de /api/tasks/my ya son de este usuario,
    // pero igual filtramos por nombre por seguridad.
    final myTasks = _tasks.where((t) => t.assignee == userName).toList();

    final pages = [
      _UserTasksList(
        tasks: myTasks,
        onTaskUpdated: _onTaskUpdated, // 👈 avisar al padre
      ),
      UserCalendarScreen(tasks: myTasks, userName: userName),
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
          NavigationDestination(
            icon: Icon(Icons.check_circle_outlined),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            label: 'Foros',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            label: 'Progreso',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            label: 'Más',
          ),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subir evidencia (demo)')),
          );
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('Subir evidencia'),
      )
          : null,
    );
  }
}

class _UserTasksList extends StatefulWidget {
  final List<Task> tasks;
  final void Function(Task) onTaskUpdated; // 👈 callback al padre

  const _UserTasksList({
    required this.tasks,
    required this.onTaskUpdated,
  });

  @override
  State<_UserTasksList> createState() => _UserTasksListState();
}

class _UserTasksListState extends State<_UserTasksList> {
  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No tienes tareas asignadas'),
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.tasks.length,
      itemBuilder: (_, i) => TaskCard(
        task: widget.tasks[i],
        onTap: () async {
          final updated = await Navigator.of(context).push<Task>(
            MaterialPageRoute(
              builder: (_) => UserTaskDetailScreen(task: widget.tasks[i]),
            ),
          );
          if (updated != null) {
            // ✅ Actualizamos en el padre, que es el dueño de _tasks
            widget.onTaskUpdated(updated);
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
              onTap: () {
                final updated = t.copyWith(status: TaskStatus.pending);
                widget.onTaskUpdated(updated); // 👈 actualiza en el padre
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Marcar como En proceso'),
              onTap: () {
                final updated =
                t.copyWith(status: TaskStatus.inProgress);
                widget.onTaskUpdated(updated); // 👈 actualiza en el padre
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Marcar como Completada'),
              onTap: () {
                final updated = t.copyWith(status: TaskStatus.done);
                widget.onTaskUpdated(updated); // 👈 actualiza en el padre
                Navigator.pop(context);
              },
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
  Widget build(BuildContext context) =>
      const Center(child: Text('Calendario (demo)'));
}

class _UserForumsScreen extends StatefulWidget {
  const _UserForumsScreen();
  @override
  State<_UserForumsScreen> createState() => _UserForumsScreenState();
}

class _UserForumsScreenState extends State<_UserForumsScreen> {
  bool _loading = true;
  List<Forum> _forums = [];

  @override
  void initState() {
    super.initState();
    // Esperamos al primer frame para tener un context estable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyForums();
    });
  }

  Future<void> _loadMyForums() async {
    setState(() => _loading = true);

    try {
      // Necesitamos el userId para mandarlo en x-user-id
      final profile = ProfileControllerProvider.maybeOf(context);
      final userId = profile?.userId;

      if (userId == null) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo determinar el usuario actual')),
          );
        }
        return;
      }

      final uri = Uri.parse('${Env.apiBaseUrl}/api/forums/my');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'usuario',
          'x-user-id': userId.toString(),
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['forums'] as List<dynamic>? ?? []);

        final loaded = list
            .map((e) => Forum.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _forums = loaded;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar foros: ${resp.statusCode}')),
          );
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de red al cargar foros: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_forums.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No estás agregado a ningún foro todavía'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyForums,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _forums.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final f = _forums[i];
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
                Text(
                  '${f.messagesCount}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _UserForumDetailScreen(forum: f),
              ),
            ),
          );
        },
      ),
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
  bool _loading = true;
  final _composer = TextEditingController();
  List<ForumMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    // Cargamos los mensajes después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);

    try {
      final profile = ProfileControllerProvider.maybeOf(context);
      final userId = profile?.userId;

      if (userId == null) {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo determinar el usuario actual'),
            ),
          );
        }
        return;
      }

      final uri = Uri.parse(
        '${Env.apiBaseUrl}/api/forums/${widget.forum.id}/posts',
      );

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'usuario',
          'x-user-id': userId.toString(),
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['posts'] as List<dynamic>? ?? []);

        final loaded = list
            .map((e) => ForumMessage.fromJson(e as Map<String, dynamic>))
            .toList();

        setState(() {
          _messages = loaded;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al cargar mensajes: ${resp.statusCode}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de red al cargar mensajes: $e'),
          ),
        );
      }
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;

    try {
      final profile = ProfileControllerProvider.maybeOf(context);
      final userId = profile?.userId;

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo determinar el usuario actual'),
            ),
          );
        }
        return;
      }

      final uri = Uri.parse(
        '${Env.apiBaseUrl}/api/forums/${widget.forum.id}/posts',
      );

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'usuario',
          'x-user-id': userId.toString(),
        },
        body: jsonEncode({'text': text}),
      );

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final msg = ForumMessage.fromJson(data);

        setState(() {
          _messages.add(msg);
          widget.forum.messagesCount = _messages.length;
          widget.forum.lastUpdated = msg.timestamp;
        });
        _composer.clear();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al enviar mensaje: ${resp.statusCode}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de red al enviar mensaje: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileControllerProvider.maybeOf(context);
    final myName = (profile?.displayName ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.forum.title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aún no hay mensajes en este foro'),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final isMine = myName.isNotEmpty &&
                    msg.author == myName; // burbuja "mía"

                return MessageBubble(
                  message: msg,
                  isMine: isMine,
                );
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
                    decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje…'),
                    onSubmitted: (_) => _send(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserProgressScreen extends StatelessWidget {
  const _UserProgressScreen();

  @override
  Widget build(BuildContext context) {
    // Por ahora valores demo; luego puedes sustituirlos
    // por datos reales calculados a partir de las tareas.
    final double weeklyProgress = 0.72; // 72%
    final double monthlyProgress = 0.65; // 65%

    // Ejemplo de datos para la gráfica (progreso diario en %)
    final List<double> dailyProgress = [20, 40, 60, 55, 72, 80, 90];
    final List<String> dayLabels = [
      'Lun',
      'Mar',
      'Mié',
      'Jue',
      'Vie',
      'Sáb',
      'Dom'
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProgressCard(
          title: 'Semanal',
          progress: weeklyProgress,
        ),
        const SizedBox(height: 16),
        _ProgressCard(
          title: 'Mensual',
          progress: monthlyProgress,
        ),
        const SizedBox(height: 24),
        Text(
          'Mi gráfica de progreso',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _UserProgressChart(
          points: dailyProgress,
          labels: dayLabels,
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String title;
  final double progress; // 0.0–1.0

  const _ProgressCard({
    required this.title,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toStringAsFixed(0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '$title: $percentage%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

/// Gráfica individual de progreso del usuario
class _UserProgressChart extends StatelessWidget {
  final List<double> points; // valores 0-100
  final List<String> labels; // etiquetas eje X

  const _UserProgressChart({
    required this.points,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: 0,
              maxY: 100,
              gridData: FlGridData(
                show: true,
                horizontalInterval: 20,
                verticalInterval: 1,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 20,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[index],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  spots: [
                    for (int i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i]),
                  ],
                  barWidth: 3,
                  color: color,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      const ListTile(
        leading: Icon(Icons.notifications_none),
        title: Text('Notificaciones'),
      ),
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
    ],
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
    Navigator.of(context)
        .pushNamedAndRemoveUntil('/auth', (route) => false);
  }
}

