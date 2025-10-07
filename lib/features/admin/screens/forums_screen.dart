import 'package:flutter/material.dart';
import '../../../models/forum.dart';
import 'forum_detail_screen.dart';

class AdminForumsScreen extends StatefulWidget {
  const AdminForumsScreen({super.key});
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          top: 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Nuevo foro',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
            FilledButton.icon(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                setState(() {
                  forums.insert(
                    0,
                    Forum(
                      id: DateTime.now()
                          .millisecondsSinceEpoch
                          .toString(),
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      messagesCount: 0,
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
            const SizedBox(height: 8),
          ],
        ),
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
