import 'package:flutter/material.dart';
import '../../../models/forum.dart';
import 'forum_detail_screen.dart';
import '../../../state/users_controller.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/env.dart'; // donde tienes Env.apiBaseUrl

// Al tope del archivo, después de los imports:
enum AudienceMode { all, selected }



class AdminForumsScreen extends StatefulWidget {
  const AdminForumsScreen({super.key, required this.assignees});
  final List<String> assignees; // ← NUEVO
  @override
  AdminForumsScreenState createState() => AdminForumsScreenState();

}

class AdminForumsScreenState extends State<AdminForumsScreen> {
  List<Forum> forums = [];
  bool _loading = true;

  Future<void> openCreateForum(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    // 1) Cargar usuarios reales desde la API
    List<Map<String, dynamic>> users = [];
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/users');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // en dev
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
          ..sort((a, b) =>
              a['name'].toString().compareTo(b['name'].toString()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar usuarios: ${resp.statusCode}'),
          ),
        );
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al cargar usuarios: $e'),
        ),
      );
      return;
    }

    // 2) Configuración de modo y selección
    AudienceMode mode = AudienceMode.all;
    final Set<int> selectedUserIds = {};

    // 3) Mostrar bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 12,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                const Text(
                  'Nuevo foro',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Participantes',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                // Selector: Todos / Elegir usuarios
                SegmentedButton<AudienceMode>(
                  segments: const [
                    ButtonSegment(
                      value: AudienceMode.all,
                      label: Text('Todos'),
                      icon: Icon(Icons.public_outlined),
                    ),
                    ButtonSegment(
                      value: AudienceMode.selected,
                      label: Text('Elegir usuarios'),
                      icon: Icon(Icons.group_add_outlined),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => setLocal(() {
                    mode = s.first;
                    if (mode == AudienceMode.all) selectedUserIds.clear();
                  }),
                ),

                const SizedBox(height: 12),

                if (mode == AudienceMode.selected) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: users.map((u) {
                      final id = u['id'] as int;
                      final isSelected = selectedUserIds.contains(id);
                      final name = u['name'] as String;
                      final email = u['email'] as String;

                      return FilterChip(
                        label: Text('$name ($email)'),
                        selected: isSelected,
                        onSelected: (v) => setLocal(() {
                          if (v) {
                            selectedUserIds.add(id);
                          } else {
                            selectedUserIds.remove(id);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedUserIds.isEmpty
                        ? 'Selecciona al menos un usuario'
                        : 'Seleccionados: ${selectedUserIds.length}',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurface.withOpacity(.7),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    final desc = descCtrl.text.trim();

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('El título no puede estar vacío'),
                        ),
                      );
                      return;
                    }

                    if (mode == AudienceMode.selected &&
                        selectedUserIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecciona al menos un usuario'),
                        ),
                      );
                      return;
                    }

                    // Obtenemos los correos de los usuarios seleccionados
                    final memberEmails = (mode == AudienceMode.all)
                        ? <String>[]
                        : users
                        .where((u) =>
                        selectedUserIds.contains(u['id'] as int))
                        .map((u) => u['email'] as String)
                        .toList();

                    final body = {
                      'title': title,
                      'description': desc,
                      'isPublic': mode == AudienceMode.all,
                      'memberEmails': memberEmails,
                    };

                    try {
                      final uri =
                      Uri.parse('${Env.apiBaseUrl}/api/forums');
                      final resp = await http.post(
                        uri,
                        headers: {
                          'Content-Type': 'application/json',
                          'x-role': 'admin', // dev
                          'x-user-id': '1',
                        },
                        body: jsonEncode(body),
                      );

                      if (resp.statusCode == 201) {
                        final data =
                        jsonDecode(resp.body) as Map<String, dynamic>;
                        final newForum = Forum.fromJson(data);

                        // Agregamos el foro a la lista local
                        // (asumiendo que estás dentro del State de AdminForumsScreen)
                        // ignore: use_build_context_synchronously
                        (context as Element).markNeedsBuild();
                        // mejor:
                        // usamos el setState del State real:
                        // pero estamos en otro State, así que:
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Error al crear foro: ${resp.statusCode}',
                            ),
                          ),
                        );
                        return;
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error de red: $e'),
                        ),
                      );
                      return;
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Foro creado correctamente')),
                    );
                  },
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Crear foro'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (forums.isEmpty) {
      return const Center(
        child: Text('No hay foros creados todavía'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: forums.length,
      itemBuilder: (_, i) {
        final f = forums[i];
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
              Text('${f.messagesCount}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminForumDetailScreen(forum: f),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadForums();
  }

  Future<void> _loadForums() async {
    try {
      final uri = Uri.parse('${Env.apiBaseUrl}/api/forums');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin',   // o 'root' en dev
          'x-user-id': '1',    // opcional, por si luego filtras por creador
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['forums'] as List<dynamic>? ?? []);

        setState(() {
          forums = list
              .map((e) => Forum.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar foros: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al cargar foros: $e')),
      );
    }
  }

}
