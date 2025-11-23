// lib/models/user_dashboard_summary.dart
// lib/models/user_dashboard_summary.dart
class UserDashboardSummary {
  final int total;
  final int pending;
  final int inProgress;
  final int done;
  final int low;
  final int medium;
  final int high;
  final int dueSoon48h;
  final int year;
  final int month;

  UserDashboardSummary({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.done,
    required this.low,
    required this.medium,
    required this.high,
    required this.dueSoon48h,
    required this.year,
    required this.month,
  });

  /// 👉 Para saber si hay tareas o no
  bool get hasTasks =>
      total > 0 || pending > 0 || inProgress > 0 || done > 0;

  double get donePercent =>
      total == 0 ? 0 : done / total;

  double get pendingPercent =>
      total == 0 ? 0 : pending / total;

  double get inProgressPercent =>
      total == 0 ? 0 : inProgress / total;

  factory UserDashboardSummary.fromJson(Map<String, dynamic> json) {
    // Soporta tanto estructura anidada como plana
    final period = (json['period'] as Map<String, dynamic>?) ?? {};
    final totals = (json['totals'] as Map<String, dynamic>?) ?? {};
    final priorities =
        (json['priorities'] as Map<String, dynamic>?) ?? {};

    int _readInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

    return UserDashboardSummary(
      year: _readInt(period['year'] ?? json['year']),
      month: _readInt(period['month'] ?? json['month']),
      total: _readInt(totals['total'] ?? json['total']),
      pending: _readInt(totals['pending'] ?? json['pending']),
      inProgress:
      _readInt(totals['inProgress'] ?? json['inProgress']),
      done: _readInt(totals['done'] ?? json['done']),
      low: _readInt(priorities['low'] ?? json['low']),
      medium: _readInt(priorities['medium'] ?? json['medium']),
      high: _readInt(priorities['high'] ?? json['high']),
      dueSoon48h:
      _readInt(json['dueSoon48h'] ?? json['due_soon_48h']),
    );
  }
}
