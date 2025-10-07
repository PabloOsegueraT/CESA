import 'package:flutter/material.dart';
import '../../../models/forum.dart';
import '../../../design_system/widgets/message_bubble.dart';

class AdminForumDetailScreen extends StatefulWidget {
  final Forum forum;
  const AdminForumDetailScreen({super.key, required this.forum});

  @override
  State<AdminForumDetailScreen> createState() => _AdminForumDetailScreenState();
}

class _AdminForumDetailScreenState extends State<AdminForumDetailScreen> {
  final List<ForumMessage> messages = [
    ForumMessage(
      id: 'm1',
      author: 'Pablo',
      text: '¿Reviso la última evidencia?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 50)),
    ),
    ForumMessage(
      id: 'm2',
      author: 'Marco',
      text: 'Sí, por favor.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
    ForumMessage(
      id: 'm3',
      author: 'Admin',
      text: 'Recuerden la fecha límite del viernes.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      isAdmin: true,
    ),
  ];
  final _composer = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.forum.title, overflow: TextOverflow.ellipsis),
          Text(
            widget.forum.closed ? 'Cerrado' : 'Abierto',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(.7),
            ),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: widget.forum.closed ? 'Reabrir tema' : 'Cerrar tema',
            onPressed: () =>
                setState(() => widget.forum.closed = !widget.forum.closed),
            icon: Icon(
              widget.forum.closed ? Icons.lock_open : Icons.lock_outline,
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final msg = messages[i];
                final isMine = msg.isAdmin; // admin como \"mío\"
                return MessageBubble(message: msg, isMine: isMine);
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
                  IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded))
                ],
              ),
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
          author: 'Admin',
          text: text,
          timestamp: DateTime.now(),
          isAdmin: true,
        ),
      );
      widget.forum.messagesCount = messages.length;
      widget.forum.lastUpdated = DateTime.now();
    });
    _composer.clear();
  }
}
