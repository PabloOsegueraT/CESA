import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/env.dart';
import '../../../models/forum.dart';
import 'package:intl/intl.dart';

class AdminForumDetailScreen extends StatefulWidget {
  const AdminForumDetailScreen({
    super.key,
    required this.forum,
    required this.currentUserId,
  });

  final Forum forum;
  final int currentUserId;

  @override
  State<AdminForumDetailScreen> createState() => _AdminForumDetailScreenState();
}

class _AdminForumDetailScreenState extends State<AdminForumDetailScreen> {
  List<ForumMessage> messages = [];
  bool _loading = true;
  final TextEditingController _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/forums/${widget.forum.id}/posts');
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // en dev; luego puedes usar el rol real
          'x-user-id': widget.currentUserId.toString(), // 👈 USAR EL REAL
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['posts'] as List<dynamic>? ?? [])
            .map(
              (e) => ForumMessage.fromJson(
            e as Map<String, dynamic>,
            currentUserId: widget.currentUserId, // 👈 AQUÍ
          ),
        )
            .toList();

        setState(() {
          messages = list;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar mensajes: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al cargar mensajes: $e'),
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/forums/${widget.forum.id}/posts');
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // en dev
          'x-user-id': widget.currentUserId.toString(), // 👈 USAR EL REAL
        },
        body: jsonEncode({'text': text}),
      );

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final newMsg = ForumMessage.fromJson(
          data,
          currentUserId: widget.currentUserId, // 👈 AQUÍ TAMBIÉN
        );

        setState(() {
          messages.add(newMsg);
          _sending = false;
        });
        _msgCtrl.clear();
      } else {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar mensaje: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al enviar mensaje: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forum.title),
      ),
      body: Column(
        children: [
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (messages.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No hay mensajes en este foro todavía'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final m = messages[i];

                    // 👇 Formatear solo la hora (24h). Si quieres 12h con am/pm: 'hh:mm a'
                    final timeStr = DateFormat('HH:mm').format(m.timestamp.toLocal());

                    return Align(
                      alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: m.isMine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.author,
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
                            Text(m.text),
                            const SizedBox(height: 4),
                            Text(
                              timeStr, // 👈 solo la hora
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
                  }
              ),
            ),

          // Caja de texto + botón enviar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _sendMessage,
                  icon: _sending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}