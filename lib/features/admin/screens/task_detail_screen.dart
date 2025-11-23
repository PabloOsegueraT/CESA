import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/env.dart';
import '../../../models/task.dart';
import '../../../models/task_attachment.dart';
import '../../../models/task_comment.dart';
import '../../user/screens/attachment_preview_screen.dart';

class UserTaskDetailScreen extends StatefulWidget {
  final Task task;

  /// Rol actual: 'usuario', 'admin', 'root'
  final String role;

  /// ID real del usuario logueado
  final int userId;

  /// Si puede gestionar la tarea (editarla / administrarla)
  final bool canManageTask;

  /// Si puede eliminar evidencias
  final bool canDeleteAttachments;

  const UserTaskDetailScreen({
    super.key,
    required this.task,
    required this.role,
    required this.userId,
    this.canManageTask = false,
    this.canDeleteAttachments = true,
  });

  @override
  State<UserTaskDetailScreen> createState() => _UserTaskDetailScreenState();
}

class _UserTaskDetailScreenState extends State<UserTaskDetailScreen> {
  late Task _current;
  bool _saving = false;

  // Evidencias
  List<TaskAttachment> _attachments = [];
  bool _loadingAttachments = true;
  bool _uploadingAttachment = false;

  // Comentarios
  List<TaskComment> _comments = [];
  bool _loadingComments = true;
  bool _sendingComment = false;
  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _current = widget.task;
    _loadAttachments();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // ===================== UI PRINCIPAL =====================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_current.title, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Estado (selector)
          const Text('Estado', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<TaskStatus>(
            segments: const [
              ButtonSegment(
                value: TaskStatus.pending,
                label: Text('Pendiente'),
                icon: Icon(Icons.pause_circle_outline),
              ),
              ButtonSegment(
                value: TaskStatus.inProgress,
                label: Text('En proceso'),
                icon: Icon(Icons.play_circle_outline),
              ),
              ButtonSegment(
                value: TaskStatus.done,
                label: Text('Completada'),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {_current.status},
            onSelectionChanged: (s) {
              final status = s.first;
              setState(() => _current = _current.copyWith(status: status));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Estado: ${_label(status)}')),
              );
            },
          ),

          const SizedBox(height: 20),
          const Text('Prioridad', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_priorityLabel(_current.priority)),

          const SizedBox(height: 20),
          const Text('Asignado a', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                child: Text(
                  _current.assignee.isNotEmpty ? _current.assignee[0] : '?',
                ),
              ),
              const SizedBox(width: 8),
              Text(_current.assignee),
            ],
          ),

          const SizedBox(height: 20),
          const Text('Fecha límite', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_dateLabel(_current.dueDate)),

          const SizedBox(height: 20),
          const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_current.description.isEmpty ? '—' : _current.description),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Evidencias
          _buildAttachmentsSection(context),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Comentarios
          _buildCommentsSection(context),

          const SizedBox(height: 16),

          // Acciones (subir evidencia + guardar estado)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                  _uploadingAttachment ? null : _pickAndUploadAttachment,
                  icon: _uploadingAttachment
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    _uploadingAttachment
                        ? 'Subiendo...'
                        : 'Subir evidencia',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveChanges,
                  icon: _saving
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =================== SECCIÓN VISUAL DE EVIDENCIAS ===================

  Widget _buildAttachmentsSection(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingAttachments) {
      return Row(
        children: const [
          Text(
            'Evidencias',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    if (_attachments.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evidencias',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Aún no hay evidencias para esta tarea.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidencias',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ..._attachments.map((a) => _buildAttachmentTile(context, a)),
      ],
    );
  }

  Widget _buildAttachmentTile(BuildContext context, TaskAttachment a) {
    final theme = Theme.of(context);
    final icon = a.isImage
        ? Icons.image_outlined
        : a.isPdf
        ? Icons.picture_as_pdf_outlined
        : Icons.insert_drive_file_outlined;

    final sizeKb = (a.sizeBytes / 1024).toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon, size: 20),
        ),
        title: Text(
          a.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${a.mimeType} • ${sizeKb} KB',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Abrir',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openAttachmentPreview(context, a),
            ),
            if (widget.canDeleteAttachments)
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDeleteAttachment(a),
              ),
          ],
        ),
      ),
    );
  }

  void _openAttachmentPreview(BuildContext context, TaskAttachment a) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentPreviewScreen(
          taskId: _current.id,
          attachment: a,
        ),
      ),
    );
  }

  Future<void> _openAttachment(TaskAttachment a) async {
    final url = '${Env.apiBaseUrl}/api/attachments/${a.id}/download';
    final uri = Uri.parse(url);

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la evidencia')),
      );
    }
  }

  // =================== LÓGICA: CARGAR / SUBIR / ELIMINAR EVIDENCIAS ===================

  Future<void> _loadAttachments() async {
    setState(() => _loadingAttachments = true);

    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/tasks/${_current.id}/attachments');

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': widget.role.toLowerCase(),
          'x-user-id': widget.userId.toString(),
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['attachments'] as List<dynamic>? ?? [])
            .map((e) => TaskAttachment.fromJson(e as Map<String, dynamic>))
            .toList();

        if (!mounted) return;
        setState(() {
          _attachments = list;
          _loadingAttachments = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingAttachments = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error al cargar evidencias: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAttachments = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al cargar evidencias: $e')),
      );
    }
  }

  Future<void> _pickAndUploadAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo leer el archivo seleccionado'),
          ),
        );
        return;
      }

      final base64Data = base64Encode(bytes);
      final mimeType = _guessMimeType(file.name);

      setState(() => _uploadingAttachment = true);

      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/tasks/${_current.id}/attachments');

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': widget.role.toLowerCase(),
          'x-user-id': widget.userId.toString(),
        },
        body: jsonEncode({
          'fileName': file.name,
          'mimeType': mimeType,
          'base64Data': base64Data,
        }),
      );

      if (!mounted) return;

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final att = TaskAttachment.fromJson(data);
        setState(() {
          _attachments.insert(0, att);
          _uploadingAttachment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidencia subida correctamente')),
        );
      } else {
        setState(() => _uploadingAttachment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error al subir evidencia: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAttachment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de red al subir evidencia: $e')),
      );
    }
  }

  Future<void> _confirmDeleteAttachment(TaskAttachment a) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evidencia'),
        content: Text(
          '¿Seguro que quieres eliminar "${a.fileName}"?\n'
              'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteAttachment(a);
    }
  }

  Future<void> _deleteAttachment(TaskAttachment a) async {
    try {
      final uri = Uri.parse(
        '${Env.apiBaseUrl}/api/tasks/${_current.id}/attachments/${a.id}',
      );

      final resp = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': widget.role.toLowerCase(),
          'x-user-id': widget.userId.toString(),
        },
      );

      if (!mounted) return;

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        setState(() {
          _attachments.removeWhere((att) => att.id == a.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidencia eliminada')),
        );
      } else if (resp.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No puedes eliminar esta evidencia porque la subió otro usuario.',
            ),
          ),
        );
      } else if (resp.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La evidencia ya no existe en el servidor.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al eliminar evidencia: ${resp.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al eliminar evidencia: $e'),
        ),
      );
    }
  }

  // =================== SECCIÓN DE COMENTARIOS ===================

  // =================== SECCIÓN VISUAL DE COMENTARIOS ===================

  Widget _buildCommentsSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Comentarios',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),

        if (_loadingComments)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_comments.isEmpty)
          Text(
            'Aún no hay comentarios en esta tarea.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          )
        else
          Column(
            children: _comments
                .map((c) => _buildCommentTile(context, c))
                .toList(),
          ),

        const SizedBox(height: 12),
        _buildNewCommentField(context),
      ],
    );
  }

  Widget _buildCommentTile(BuildContext context, TaskComment c) {
    final theme = Theme.of(context);
    final isMine = c.isMine;
    final isAdmin = c.isAdmin;

    final bubbleColor = isMine
        ? theme.colorScheme.primary.withOpacity(0.08)
        : theme.colorScheme.surfaceVariant;
    final align =
    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMine)
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    c.author.isNotEmpty ? c.author[0].toUpperCase() : '?',
                  ),
                ),
              if (!isMine) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isMine ? 'Tú' : c.author,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 0.7,
                                ),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.body,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCommentDate(c.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isMine) const SizedBox(width: 8),
              if (isMine)
                CircleAvatar(
                  radius: 14,
                  child: Text(
                    c.author.isNotEmpty ? c.author[0].toUpperCase() : '?',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewCommentField(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentCtrl,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Escribe un comentario...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _sendingComment ? null : _sendComment,
          icon: _sendingComment
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.send_rounded),
        ),
      ],
    );
  }

  String _formatCommentDate(DateTime d) {
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');

    if (sameDay) {
      return 'Hoy $hh:$mm';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} $hh:$mm';
  }

  Widget _buildCommentsGrouped(BuildContext context) {
    final theme = Theme.of(context);

    // Separamos por rol
    final adminComments = _comments.where((c) {
      final r = c.role.toLowerCase();
      return r == 'admin' || r == 'root';
    }).toList();

    final userComments = _comments.where((c) {
      final r = c.role.toLowerCase();
      return !(r == 'admin' || r == 'root');
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (adminComments.isNotEmpty) ...[
          Text(
            'Comentarios del equipo (admin / root)',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...adminComments.map((c) => _buildCommentBubble(context, c)),
          const SizedBox(height: 16),
        ],
        if (userComments.isNotEmpty) ...[
          Text(
            'Comentarios de usuarios',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...userComments.map((c) => _buildCommentBubble(context, c)),
        ],
      ],
    );
  }

  Widget _buildCommentBubble(BuildContext context, TaskComment c) {
    final theme = Theme.of(context);
    final isMine = c.userId == widget.userId;
    final r = c.role.toLowerCase();
    final isAdminOrRoot = r == 'admin' || r == 'root';

    final bgColor = isMine
        ? theme.colorScheme.primary
        : isAdminOrRoot
        ? theme.colorScheme.surfaceVariant
        : theme.colorScheme.surface;

    final textColor = isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final align =
    isMine ? Alignment.centerRight : Alignment.centerLeft;

    final authorAndRole = '${c.author} (${_roleLabel(c.role)})';

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
              isMine ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
              isMine ? const Radius.circular(4) : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: isMine
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (!isMine) ...[
                    CircleAvatar(
                      radius: 12,
                      child: Text(
                        c.author.isNotEmpty
                            ? c.author[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      authorAndRole,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                c.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(c.createdAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String rawRole) {
    final r = rawRole.toLowerCase();
    if (r == 'admin') return 'Admin';
    if (r == 'root') return 'Root';
    return 'Usuario';
  }

  String _formatDateTime(DateTime dt) {
    final d = dt;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hh:$mm';
  }

  // =================== LÓGICA: COMENTARIOS ===================

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);

    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/tasks/${_current.id}/comments');

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': widget.role.toLowerCase(),
          'x-user-id': widget.userId.toString(),
        },
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (data['comments'] as List<dynamic>? ?? [])
            .map((e) => TaskComment.fromJson(e as Map<String, dynamic>))
            .toList();

        if (!mounted) return;
        setState(() {
          _comments = list;
          _loadingComments = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingComments = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Error al cargar comentarios: ${resp.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingComments = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al cargar comentarios: $e'),
        ),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un comentario primero')),
      );
      return;
    }

    setState(() => _sendingComment = true);

    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/tasks/${_current.id}/comments');

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': widget.role.toLowerCase(),
          'x-user-id': widget.userId.toString(),
        },
        body: jsonEncode({'body': text}),
      );

      if (!mounted) return;

      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final comment = TaskComment.fromJson(data);

        setState(() {
          _comments.add(comment);
          _sendingComment = false;
          _commentCtrl.clear();
        });
      } else {
        setState(() => _sendingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al enviar comentario: ${resp.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingComment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al enviar comentario: $e'),
        ),
      );
    }
  }



  // =================== GUARDAR CAMBIOS DE ESTADO ===================

  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    String statusCode;
    switch (_current.status) {
      case TaskStatus.pending:
        statusCode = 'pending';
        break;
      case TaskStatus.inProgress:
        statusCode = 'in_progress';
        break;
      case TaskStatus.done:
        statusCode = 'done';
        break;
    }

    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/tasks/${_current.id}/status');

      final resp = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-role': widget.role.toLowerCase(),
          'x-user-id': widget.userId.toString(),
        },
        body: jsonEncode({'status': statusCode}),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cambios guardados')),
        );
        Navigator.pop(context, _current);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar en el servidor: ${resp.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de red al guardar cambios: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // =================== HELPERS ===================

  String _label(TaskStatus s) => switch (s) {
    TaskStatus.pending => 'Pendiente',
    TaskStatus.inProgress => 'En proceso',
    TaskStatus.done => 'Completada',
  };

  String _priorityLabel(TaskPriority p) => switch (p) {
    TaskPriority.low => 'Baja',
    TaskPriority.medium => 'Media',
    TaskPriority.high => 'Alta',
  };

  String _dateLabel(DateTime d) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
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
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }

}