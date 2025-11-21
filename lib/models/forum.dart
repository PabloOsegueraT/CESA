import '../core/constants/env.dart'; // 👈 ajusta la ruta según tu proyecto

class Forum {
  final String id;
  String title;
  String description;
  bool closed;
  int messagesCount;
  DateTime lastUpdated;

  /// Si es para todos los usuarios (true) o sólo para un subconjunto (false)
  bool forAll;

  /// Nombres (o correos) de usuarios participantes (se usa si forAll == false)
  List<String> members;

  Forum({
    required this.id,
    required this.title,
    required this.description,
    this.closed = false,
    this.messagesCount = 0,
    DateTime? lastUpdated,
    this.forAll = true,
    List<String>? members,
  })  : members = members ?? <String>[],
        lastUpdated = lastUpdated ?? DateTime.now();

  factory Forum.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final idStr = rawId?.toString() ?? '';

    final rawCount = json['messagesCount'];
    final intCount = switch (rawCount) {
      int v => v,
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };

    final isPublic = json['isPublic'];
    final boolForAll = (isPublic is bool)
        ? isPublic
        : (isPublic == 1 || isPublic == '1');

    final membersList = (json['members'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    DateTime parsedLastUpdated = DateTime.now();
    final rawLastUpdated = json['lastUpdated'] ?? json['updated_at'];
    if (rawLastUpdated is String && rawLastUpdated.isNotEmpty) {
      try {
        parsedLastUpdated = DateTime.parse(rawLastUpdated);
      } catch (_) {}
    }

    final rawClosed = json['closed'];
    final boolClosed = (rawClosed is bool)
        ? rawClosed
        : (rawClosed == 1 || rawClosed == '1');

    return Forum(
      id: idStr,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      closed: boolClosed,
      messagesCount: intCount,
      forAll: boolForAll,
      members: membersList,
      lastUpdated: parsedLastUpdated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'closed': closed,
      'messagesCount': messagesCount,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isPublic': forAll,
      'members': members,
    };
  }
}

/* =======================
 *  Adjuntos de foros
 * ===================== */

class ForumAttachment {
  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  ForumAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  /// ¿Es una imagen? (png, jpg, etc.)
  bool get isImage => mimeType.toLowerCase().startsWith('image/');

  /// URL construida a partir del id
  /// Coincide con la ruta del backend:
  ///   GET /api/forums/attachments/:id/file
  String get url =>
      '${Env.apiBaseUrl}/api/forums/attachments/$id/file';

  factory ForumAttachment.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final idStr = rawId?.toString() ?? '';

    final mime = (json['mimeType'] ?? json['mime_type'] ?? 'application/octet-stream')
        .toString();

    final rawSize = json['sizeBytes'] ?? json['size_bytes'];

    return ForumAttachment(
      id: idStr,
      fileName: json['fileName']?.toString() ??
          json['file_name']?.toString() ??
          '',
      mimeType: mime,
      sizeBytes: switch (rawSize) {
        int v => v,
        String v => int.tryParse(v) ?? 0,
        _ => 0,
      },
    );
  }
}

/* =======================
 *  Mensajes de foro
 * ===================== */

class ForumMessage {
  final String id;
  final String author; // nombre visible
  final String text;
  final DateTime timestamp;
  final bool isAdmin;
  final bool isMine;
  final List<ForumAttachment> attachments;

  ForumMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.timestamp,
    this.isAdmin = false,
    this.isMine = false,
    this.attachments = const [],
  });

  factory ForumMessage.fromJson(
      Map<String, dynamic> json, {
        int? currentUserId,
      }) {
    final rawId = json['id'];
    final idStr = rawId?.toString() ?? '';

    final rawTs = json['createdAt'] ?? json['timestamp'];
    DateTime ts = DateTime.now();
    if (rawTs is String && rawTs.isNotEmpty) {
      try {
        ts = DateTime.parse(rawTs);
      } catch (_) {}
    }

    final rawAdmin = json['isAdmin'];
    final boolAdmin = switch (rawAdmin) {
      bool v => v,
      int v => v == 1,
      String v => v == '1' || v.toLowerCase() == 'true',
      _ => false,
    };

    int? authorId;
    final rawAuthorId = json['authorId'];
    if (rawAuthorId is int) {
      authorId = rawAuthorId;
    } else if (rawAuthorId is String) {
      authorId = int.tryParse(rawAuthorId);
    }
    final boolMine =
        currentUserId != null && authorId != null && authorId == currentUserId;

    // Adjuntos
    final atts = (json['attachments'] as List<dynamic>? ?? [])
        .map((e) => ForumAttachment.fromJson(e as Map<String, dynamic>))
        .toList();

    return ForumMessage(
      id: idStr,
      author: json['author']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      timestamp: ts,
      isAdmin: boolAdmin,
      isMine: boolMine,
      attachments: atts,
    );
  }
}