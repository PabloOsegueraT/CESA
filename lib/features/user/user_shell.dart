// lib/features/user/user_shell.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/constants/env.dart';
import '../../models/task.dart';
import '../../models/forum.dart';
import '../../design_system/widgets/task_card.dart';
import '../admin/screens/task_detail_screen.dart';
import '../admin/screens/fullscreen_image_screen.dart';
import 'screens/calendar_screen.dart';
import '../../state/profile_controller.dart';
import 'screens/progress_screen.dart';
import '../../models/user_dashboard_summary.dart';


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
        final loaded =
        list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();

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
        onTaskUpdated: _onTaskUpdated,
      ),
      UserCalendarScreen(tasks: myTasks),
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

    final profile = ProfileControllerProvider.maybeOf(context);
    final int userId = profile?.userId ?? 0;

    return ListView.builder(
      itemCount: widget.tasks.length,
      itemBuilder: (_, i) => TaskCard(
        task: widget.tasks[i],
        onTap: () async {
          final updated = await Navigator.of(context).push<Task>(
            MaterialPageRoute(
              builder: (_) => UserTaskDetailScreen(
                task: widget.tasks[i],
                role: 'usuario',
                userId: userId,
                canManageTask: false, // el usuario no edita meta de la tarea
                canDeleteAttachments:
                true, // pero SÍ puede borrar sus evidencias
              ),
            ),
          );
          if (updated != null) {
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
                final updated = t.copyWith(status: TaskStatus.inProgress);
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

/* ============================
 *  FOROS – USUARIO
 * ========================== */

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
            const SnackBar(
                content: Text('No se pudo determinar el usuario actual')),
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

        final loaded =
        list.map((e) => Forum.fromJson(e as Map<String, dynamic>)).toList();

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
  State<_UserForumDetailScreen> createState() =>
      _UserForumDetailScreenState();
}

class _UserForumDetailScreenState extends State<_UserForumDetailScreen> {
  bool _loading = true;
  bool _sending = false;
  final _composer = TextEditingController();
  List<ForumMessage> _messages = [];
  int? _currentUserId;

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
      _currentUserId = userId;

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
            .map(
              (e) => ForumMessage.fromJson(
            e as Map<String, dynamic>,
            currentUserId: userId,
          ),
        )
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
              content:
              Text('Error al cargar mensajes: ${resp.statusCode}'),
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
    if (text.isEmpty || _sending) return;

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

      setState(() => _sending = true);

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
        final msg = ForumMessage.fromJson(
          data,
          currentUserId: userId,
        );

        setState(() {
          _messages.add(msg);
          widget.forum.messagesCount = _messages.length;
          widget.forum.lastUpdated = msg.timestamp;
          _sending = false;
        });
        _composer.clear();
      } else {
        setState(() => _sending = false);
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
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de red al enviar mensaje: $e'),
          ),
        );
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_sending) return;

    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final base64Data = base64Encode(bytes);
    final fileName = file.name;
    final mimeType = _detectMimeType(file);

    await _sendFileMessage(
      base64Data: base64Data,
      fileName: fileName,
      mimeType: mimeType,
      text: _composer.text.trim().isEmpty ? null : _composer.text.trim(),
    );

    _composer.clear();
  }

  Future<void> _sendFileMessage({
    required String base64Data,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
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

      setState(() => _sending = true);

      final uri = Uri.parse(
        '${Env.apiBaseUrl}/api/forums/${widget.forum.id}/posts-with-file',
      );

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'usuario',
          'x-user-id': userId.toString(),
        },
        body: jsonEncode({
          'text': text ?? '',
          'fileName': fileName,
          'mimeType': mimeType,
          'base64Data': base64Data,
        }),
      );

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final msg = ForumMessage.fromJson(
          data,
          currentUserId: userId,
        );

        setState(() {
          _messages.add(msg);
          widget.forum.messagesCount = _messages.length;
          widget.forum.lastUpdated = msg.timestamp;
          _sending = false;
        });
      } else {
        setState(() => _sending = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al enviar archivo: ${resp.statusCode}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de red al enviar archivo: $e'),
          ),
        );
      }
    }
  }

  Future<void> _openAttachmentFile(ForumAttachment att) async {
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

      final url =
          '${Env.apiBaseUrl}/api/forums/attachments/${att.id}/file';

      final headers = {
        'x-role': 'usuario',
        'x-user-id': userId.toString(),
      };

      final resp = await http.get(Uri.parse(url), headers: headers);

      if (resp.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo descargar el archivo (HTTP ${resp.statusCode})',
              ),
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = att.fileName.isNotEmpty ? att.fileName : 'archivo';
      final filePath = '${tempDir.path}/$safeName';

      final file = File(filePath);
      await file.writeAsBytes(resp.bodyBytes);

      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el archivo en el dispositivo'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir archivo: $e'),
          ),
        );
      }
    }
  }

  String _detectMimeType(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final myName =
    (ProfileControllerProvider.maybeOf(context)?.displayName ?? '')
        .trim();

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
                final isMine = msg.isMine ||
                    (myName.isNotEmpty && msg.author == myName);

                final timeStr = DateFormat('HH:mm')
                    .format(msg.timestamp.toLocal());

                return Align(
                  alignment: isMine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin:
                    const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMine
                          ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          : Theme.of(context)
                          .colorScheme
                          .surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.author,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (msg.text.isNotEmpty) ...[
                          Text(msg.text),
                          const SizedBox(height: 8),
                        ],
                        if (msg.attachments.isNotEmpty)
                          _buildAttachmentsRow(
                              context, msg, _currentUserId),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _sending ? null : _pickAndSendFile,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje…',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                      CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsRow(
      BuildContext context,
      ForumMessage msg,
      int? userId,
      ) {
    final uid = userId ?? 0;

    final headers = {
      'x-role': 'usuario',
      'x-user-id': uid.toString(),
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: msg.attachments.map((att) {
        final isImage = att.mimeType.startsWith('image/');
        final url =
            '${Env.apiBaseUrl}/api/forums/attachments/${att.id}/file';

        if (isImage) {
          // Imagen en miniatura + pantalla completa al tocar
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullscreenImageScreen(
                    imageUrl: url,
                    headers: headers,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                headers: headers,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 140,
                  height: 140,
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 32),
                ),
              ),
            ),
          );
        } else {
          // Documento (PDF, Word, etc.)
          return GestureDetector(
            onTap: () => _openAttachmentFile(att),
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    att.fileName,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }
      }).toList(),
    );
  }
}

/* ============================
 *  PROGRESO – USUARIO
 * ========================== */

class _UserProgressScreen extends StatefulWidget {
  const _UserProgressScreen();

  @override
  State<_UserProgressScreen> createState() => _UserProgressScreenState();
}

class _UserProgressScreenState extends State<_UserProgressScreen> {
  bool _loading = true;
  String? _error;
  UserDashboardSummary? _summary;

  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;

    // Cargar después del primer frame para tener context válido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSummary();
    });
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = ProfileControllerProvider.maybeOf(context);
      final userId = profile?.userId;

      if (userId == null || userId <= 0) {
        setState(() {
          _loading = false;
          _error = 'No se encontró el usuario en sesión.';
        });
        return;
      }

      final uri = Uri.parse(
        '${Env.apiBaseUrl}/api/dashboard/my-summary'
            '?year=$_selectedYear&month=$_selectedMonth',
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
        final s = UserDashboardSummary.fromJson(data);

        setState(() {
          _summary = s;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Error HTTP ${resp.statusCode} al cargar datos.';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error de red: $e';
      });
    }
  }

  void _changeMonth(int delta) {
    var year = _selectedYear;
    var month = _selectedMonth + delta;
    if (month <= 0) {
      month = 12;
      year -= 1;
    } else if (month >= 13) {
      month = 1;
      year += 1;
    }
    setState(() {
      _selectedYear = year;
      _selectedMonth = month;
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final monthName = DateFormat.yMMMM('es_MX')
            .format(DateTime(_selectedYear, _selectedMonth, 1));

        final summary = _summary;

        return RefreshIndicator(
          onRefresh: _loadSummary,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header de mes + flechas
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _loading ? null : () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Mes anterior',
                  ),
                  Column(
                    children: [
                      Text(
                        'Mi progreso',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        monthName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _loading ? null : () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Mes siguiente',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (summary == null || !summary.hasTasks)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Aún no tienes tareas registradas en este periodo.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                    // === Tarjetas con íconos (responsive) ===
                    _buildStatsCards(context, summary, isSmall, constraints),
                    const SizedBox(height: 24),

                    Text(
                      'Progreso por estado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _UserProgressChart(
                      points: [
                        summary.pending.toDouble(),
                        summary.inProgress.toDouble(),
                        summary.done.toDouble(),
                      ],
                      labels: const ['Pend.', 'En proc.', 'Hechas'],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Prioridad de mis tareas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildPriorityRow(context, summary),
                  ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCards(
      BuildContext context,
      UserDashboardSummary summary,
      bool isSmall,
      BoxConstraints constraints,
      ) {
    final double fullWidth = constraints.maxWidth;
    final double cardWidth =
    isSmall ? fullWidth : (fullWidth - 16) / 2; // 2 por fila en pantallas grandes

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: cardWidth,
          child: _StatCard(
            icon: Icons.assignment_outlined,
            iconColor: Theme.of(context).colorScheme.primary,
            title: 'Total tareas',
            value: summary.total.toString(),
            subtitle: 'Asignadas en el mes',
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _StatCard(
            icon: Icons.pending_actions_outlined,
            iconColor: Colors.orange,
            title: 'Pendientes',
            value: summary.pending.toString(),
            subtitle:
            '${(summary.pendingPercent * 100).toStringAsFixed(0)}% del total',
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _StatCard(
            icon: Icons.play_circle_outline,
            iconColor: Colors.blue,
            title: 'En proceso',
            value: summary.inProgress.toString(),
            subtitle:
            '${(summary.inProgressPercent * 100).toStringAsFixed(0)}% del total',
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _StatCard(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
            title: 'Completadas',
            value: summary.done.toString(),
            subtitle:
            '${(summary.donePercent * 100).toStringAsFixed(0)}% del total',
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _StatCard(
            icon: Icons.access_time,
            iconColor: Colors.redAccent,
            title: 'Vencen en 48h',
            value: summary.dueSoon48h.toString(),
            subtitle: 'Tareas próximas a vencer',
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityRow(
      BuildContext context,
      UserDashboardSummary summary,
      ) {
    final cs = Theme.of(context).colorScheme;

    Widget pill(String label, int count, Color color) {
      return Chip(
        avatar: CircleAvatar(
          backgroundColor: color,
          radius: 8,
        ),
        label: Text('$label: $count'),
        backgroundColor: cs.surfaceVariant.withOpacity(0.6),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        pill('Baja', summary.low, Colors.green),
        pill('Media', summary.medium, Colors.orange),
        pill('Alta', summary.high, Colors.red),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gráfica de progreso del usuario (usa fl_chart)
class _UserProgressChart extends StatelessWidget {
  final List<double> points; // valores 0-100 (en este caso, conteos)
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
              maxY: (points.fold<double>(0, (m, v) => v > m ? v : m) + 1)
                  .clamp(1, double.infinity),
              gridData: FlGridData(
                show: true,
                horizontalInterval: 1,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
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

/* ============================
 *  MÁS
 * ========================== */

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
