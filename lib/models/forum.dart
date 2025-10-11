class Forum {
  final String id;
  String title;
  String description;
  bool closed;
  int messagesCount;
  DateTime lastUpdated;

  /// Si es para todos los usuarios (true) o sólo para un subconjunto (false)
  bool forAll;

  /// Nombres de usuarios participantes (se usa si forAll == false)
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
