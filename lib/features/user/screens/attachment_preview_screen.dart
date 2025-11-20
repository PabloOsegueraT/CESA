// lib/features/user/screens/attachment_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/env.dart';
import '../../../models/task_attachment.dart';

class AttachmentPreviewScreen extends StatelessWidget {
  const AttachmentPreviewScreen({
    super.key,
    required this.taskId,
    required this.attachment,
  });

  final String taskId;
  final TaskAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final url =
        '${Env.apiBaseUrl}/api/tasks/$taskId/attachments/${attachment.id}/file';

    final isImage = attachment.mimeType.startsWith('image/');
    final isPdf = attachment.mimeType == 'application/pdf';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          attachment.fileName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPreviewBody(context, url, isImage, isPdf),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(url);
                        final ok = await launchUrl(
                          uri,
                          mode: LaunchMode.inAppWebView,
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo abrir la evidencia'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Ver / Descargar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(url);
                        final ok = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No se pudo descargar'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Abrir en otra app'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBody(
      BuildContext context,
      String url,
      bool isImage,
      bool isPdf,
      ) {
    if (isImage) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      );
    }

    if (isPdf) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 64),
            const SizedBox(height: 12),
            const Text(
              'Vista previa de PDF no integrada.\nUsa el botón "Ver / Descargar".',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              attachment.fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 64),
          const SizedBox(height: 12),
          Text(
            attachment.fileName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${attachment.mimeType} · ${attachment.sizeLabel}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Usa los botones de abajo para abrir o descargar.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}