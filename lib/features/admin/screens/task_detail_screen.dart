// lib/features/user/screens/task_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/task.dart';
import '../../../core/constants/env.dart'; // Env.apiBaseUrl
import '../../../models/task_attachment.dart';
import '../../user/screens/attachment_preview_screen.dart';


class UserTaskDetailScreen extends StatefulWidget {
  final Task task;
  const UserTaskDetailScreen({super.key, required this.task});

  @override
  State<UserTaskDetailScreen> createState() => _UserTaskDetailScreenState();
}

class _UserTaskDetailScreenState extends State<UserTaskDetailScreen> {
  late Task _current;
  bool _saving = false;

  // ===== Estado de evidencias =====
  List<TaskAttachment> _attachments = [];
  bool _loadingAttachments = true;
  bool _uploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _current = widget.task;
    _loadAttachments();
  }

  // ==== SECCIÓN VISUAL DE EVIDENCIAS ====
  Widget _buildAttachmentsSection(BuildContext context) {
    final theme = Theme.of(context);

    // Cargando
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

    // Sin evidencias
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

    // Lista de evidencias
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

          _buildAttachmentsSection(context),


          const SizedBox(height: 16),

          // Acciones
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

  // =================== LÓGICA: evidencias ===================

  Future<void> _loadAttachments() async {
    setState(() => _loadingAttachments = true);

    try {
      final uri =
      Uri.parse('${Env.apiBaseUrl}/api/tasks/${_current.id}/attachments');

      final resp = await http.get(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'x-role': 'usuario', // en dev
          'x-user-id': '2',
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
        withData: true, // para tener los bytes directamente
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('No se pudo leer el archivo seleccionado'),
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
        headers: const {
          'Content-Type': 'application/json',
          'x-role': 'usuario', // en dev
          'x-user-id': '2',
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
            content: Text(
              'Error al subir evidencia: ${resp.statusCode}',
            ),
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
        trailing: const Icon(Icons.open_in_new),
        // ✅ Ahora abrimos la pantalla de preview dentro de la app
        onTap: () => _openAttachmentPreview(context, a),
      ),
    );
  }

  void _openAttachmentPreview(BuildContext context, TaskAttachment a) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AttachmentPreviewScreen(
          taskId: _current.id,    // _current.id es String, está bien
          attachment: a,
        ),
      ),
    );
  }

  Future<void> _openAttachment(TaskAttachment a) async {
    // Construimos la URL de descarga que definimos en el backend:
    final url =
        '${Env.apiBaseUrl}/api/attachments/${a.id}/download';
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

  // =================== LÓGICA DE ESTADO / API (estatus tarea) ===================

  Future<void> _saveChanges() async {
    setState(() => _saving = true);

    // 1) Mapear TaskStatus -> código del backend
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
        headers: const {
          'Content-Type': 'application/json',
          // En dev, simulamos que es un usuario normal:
          // TODO: reemplazar con el id real del usuario logueado
          'x-role': 'usuario',
          'x-user-id': '2',
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
                'Error al guardar en el servidor: ${resp.statusCode}'),
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
}