class Forum {
  final String id;
  String title;
  String description;
  bool closed;
  int messagesCount;
  DateTime lastUpdated;

  Forum({
    required this.id,
    required this.title,
    required this.description,
    this.closed = false,
    this.messagesCount = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
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
}
