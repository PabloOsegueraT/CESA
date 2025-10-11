import 'package:flutter/material.dart';
import '../../../models/forum.dart';
import 'forum_detail_screen.dart';
import '../../../state/users_controller.dart';

// Al tope del archivo, después de los imports:
enum AudienceMode { all, selected }



class AdminForumsScreen extends StatefulWidget {
  const AdminForumsScreen({super.key, required this.assignees});
  final List<String> assignees; // ← NUEVO
  @override
  AdminForumsScreenState createState() => AdminForumsScreenState();

}

class AdminForumsScreenState extends State<AdminForumsScreen> {
  final List<Forum> forums = [
    Forum(
      id: 'f1',
      title: 'Sprint 10 - Entregables',
      description: 'Hilo para dudas y acuerdos del sprint.',
      messagesCount: 12,
    ),
    Forum(
      id: 'f2',
      title: 'Evidencias y revisiones',
      description: 'Subida de evidencias y feedback.',
      messagesCount: 8,
    ),
    Forum(
      id: 'f3',
      title: 'Anuncios',
      description: 'Comunicados importantes del admin.',
      messagesCount: 3,
    ),
  ];

  void openCreateForum(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    // Usuarios disponibles (inyectados desde AdminShell vía: AdminForumsScreen(assignees: ...))
    final users = [...widget.assignees]..sort();

    // Modo: Todos vs Elegir usuarios
    AudienceMode mode = AudienceMode.all;
    final Set<String> selected = {};

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
                    if (mode == AudienceMode.all) selected.clear();
                  }),
                ),

                const SizedBox(height: 12),

                // Lista de usuarios SOLO cuando el modo es "Elegir usuarios"
                if (mode == AudienceMode.selected) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: users.map((name) {
                      final isSelected = selected.contains(name);
                      return FilterChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected: (v) => setLocal(() {
                          if (v) {
                            selected.add(name);
                          } else {
                            selected.remove(name);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selected.isEmpty
                        ? 'Selecciona al menos un usuario'
                        : 'Seleccionados: ${selected.length}',
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurface.withOpacity(.7),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;

                    // Validación cuando es "Elegir usuarios"
                    if (mode == AudienceMode.selected && selected.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selecciona al menos un usuario'),
                        ),
                      );
                      return;
                    }

                    setState(() {
                      forums.insert(
                        0,
                        Forum(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          description: descCtrl.text.trim(),
                          messagesCount: 0,
                          forAll: mode == AudienceMode.all,
                          members: mode == AudienceMode.all
                              ? <String>[]
                              : selected.toList(),
                        ),
                      );
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Foro creado (demo)')),
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: forums.length,
      itemBuilder: (_, i) {
        final f = forums[i];
        return ListTile(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            MaterialPageRoute(builder: (_) => AdminForumDetailScreen(forum: f)),
          ),
        );
      },
    );
  }
}
