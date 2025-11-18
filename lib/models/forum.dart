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

  /// Crea un Forum desde el JSON que manda tu API
  /// {
  ///   "id": 1,
  ///   "title": "...",
  ///   "description": "...",
  ///   "isPublic": true/false,
  ///   "members": ["user1@mail.com", "user2@mail.com"],
  ///   "messagesCount": 0
  /// }
  factory Forum.fromJson(Map<String, dynamic> json) {
    // Puede venir numérico o string
    final rawId = json['id'];
    final idStr = rawId?.toString() ?? '';

    // messagesCount viene como int, pero por si acaso:
    final rawCount = json['messagesCount'];
    final intCount = switch (rawCount) {
      int v => v,
      String v => int.tryParse(v) ?? 0,
      _ => 0,
    };

    // isPublic -> forAll
    final isPublic = json['isPublic'];
    final boolForAll = (isPublic is bool)
        ? isPublic
        : (isPublic == 1 || isPublic == '1');

    // members: lista de strings
    final membersList = (json['members'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    // lastUpdated: si el back algún día manda `updated_at` o `lastUpdated`
    DateTime parsedLastUpdated = DateTime.now();
    final rawLastUpdated = json['lastUpdated'] ?? json['updated_at'];
    if (rawLastUpdated is String && rawLastUpdated.isNotEmpty) {
      try {
        parsedLastUpdated = DateTime.parse(rawLastUpdated);
      } catch (_) {
        // si falla el parseo, nos quedamos con DateTime.now()
      }
    }

    // closed: tu API aún no lo manda, así que lo tomamos del json si existe, si no false
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

  /// Opcional: por si en algún momento quieres enviar un foro al back
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

class ForumMessage {
  final String id;
  final String author; // nombre visible
  final String text;
  final DateTime timestamp;
  final bool isAdmin;

  ForumMessage({
    required this.id,
    required this.author,
    required this.text,
    required this.timestamp,
    this.isAdmin = false,
  });

  factory ForumMessage.fromJson(Map<String, dynamic> json) {
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

    return ForumMessage(
      id: idStr,
      author: json['author']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      timestamp: ts,
      isAdmin: boolAdmin,
    );
  }
}