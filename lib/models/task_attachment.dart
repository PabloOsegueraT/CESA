// lib/models/task_attachment.dart

class TaskAttachment {
  final int id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  TaskAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  bool get isImage => mimeType.toLowerCase().startsWith('image/');
  bool get isPdf => mimeType.toLowerCase() == 'application/pdf';

  String get sizeLabel {
    if (sizeBytes <= 0) return '0.0 KB';
    final kb = sizeBytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }

  factory TaskAttachment.fromJson(Map<String, dynamic> json) {
    final rawDate = json['created_at'] ?? json['createdAt'];
    DateTime dt = DateTime.now();
    if (rawDate is String && rawDate.isNotEmpty) {
      try {
        dt = DateTime.parse(rawDate);
      } catch (_) {}
    }

    return TaskAttachment(
      id: (json['id'] as num).toInt(),
      fileName: (json['file_name'] ?? json['fileName'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? json['mimeType'] ?? 'application/octet-stream').toString(),
      sizeBytes: (json['size_bytes'] ?? json['sizeBytes'] ?? 0) as int,
      createdAt: dt,
    );
  }
}