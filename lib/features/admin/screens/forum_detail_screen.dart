import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/env.dart';
import '../../../models/forum.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'fullscreen_image_screen.dart'; // importa el archivo de arriba
import 'dart:io';
import '../../../state/profile_controller.dart';
import '../../../core/constants/env.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

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
  Future<void> _openAttachmentFile(ForumAttachment att) async {
    try {
      final uri = Uri.parse(att.url);

      // 👇 si aquí el rol lo tienes fijo como admin/root, déjalo así,
      // o puedes pasar widget.currentUserId y el rol real desde el ProfileController.
      final headers = {
        'x-role': 'admin',
        'x-user-id': widget.currentUserId.toString(),
      };

      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo descargar el archivo (HTTP ${resp.statusCode})'),
          ),
        );
        return;
      }

      // Guardar en carpeta temporal
      final tempDir = await getTemporaryDirectory();
      final safeName = att.fileName.isNotEmpty ? att.fileName : 'archivo';
      final filePath = '${tempDir.path}/$safeName';

      final file = File(filePath);
      await file.writeAsBytes(resp.bodyBytes);

      // Abrir con app del sistema
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el archivo en el dispositivo'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir archivo: $e'),
        ),
      );
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
    final mimeType = _detectMimeType(file); // 👈 usamos la función de abajo

    await _sendFileMessage(
      base64Data: base64Data,
      fileName: fileName,
      mimeType: mimeType,
      text: _msgCtrl.text.trim().isEmpty ? null : _msgCtrl.text.trim(),
    );

    _msgCtrl.clear();
  }

  Future<void> _sendFileMessage({
    required String base64Data,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
    setState(() => _sending = true);

    try {
      final uri = Uri.parse(
          '${Env.apiBaseUrl}/api/forums/${widget.forum.id}/posts-with-file');

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': 'admin', // en dev
          'x-user-id': widget.currentUserId.toString(),
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
        final newMsg = ForumMessage.fromJson(
          data,
          currentUserId: widget.currentUserId,
        );

        setState(() {
          messages.add(newMsg);
          _sending = false;
        });
      } else {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar archivo: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al enviar archivo: $e'),
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
      // Por si no sabemos la extensión
        return 'application/octet-stream';
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

                            // 🔹 Texto (si hay)
                            if (m.text.isNotEmpty) ...[
                              Text(m.text),
                              const SizedBox(height: 8),
                            ],

                            // 🔹 Adjuntos (imágenes y documentos)
                            if (m.attachments.isNotEmpty)
                              _buildAttachmentsRow(context, m),

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
                  }
              ),
            ),

          // Caja de texto + botón enviar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _sending ? null : _pickAndSendFile,
                ),
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

  Widget _buildAttachmentsRow(BuildContext context, ForumMessage m) {
    // Si tienes ProfileController:
    // final profile = ProfileControllerProvider.maybeOf(context);
    // final role = profile?.role ?? 'admin';
    // final userId = profile?.userId ?? widget.currentUserId;

    final headers = {
      'x-role': 'admin', // en admin; en pantalla de usuario pon 'usuario'
      'x-user-id': widget.currentUserId.toString(),
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: m.attachments.map((att) {
        if (att.isImage) {
          // 🔹 Miniatura de imagen
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullscreenImageScreen(
                    imageUrl: att.url,
                    headers: headers,
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                att.url,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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