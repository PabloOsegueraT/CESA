// lib/features/admin/screens/user_detail_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/env.dart';
import '../../../models/user_dashboard_summary.dart';
import '../../../state/auth_controller.dart';
import 'users_screen.dart';

/// Datos extra del perfil (foto, descripción, teléfono)
class AdminUserProfileDetail {
  final String? avatarUrl;
  final String? description;
  final String? phone;

  const AdminUserProfileDetail({
    this.avatarUrl,
    this.description,
    this.phone,
  });

  factory AdminUserProfileDetail.fromJson(Map<String, dynamic> json) {
    // El backend puede devolver { user: {...} } o directamente el usuario
    final m = (json['user'] is Map<String, dynamic>)
        ? (json['user'] as Map<String, dynamic>)
        : json;

    // 👇 tu BD usa "about", pero dejamos compatibilidad con "description"
    final rawDesc = m['description'] ?? m['about'];

    return AdminUserProfileDetail(
      avatarUrl: m['avatar_url']?.toString(),
      description: rawDesc?.toString(),
      phone: m['phone']?.toString(),
    );
  }
}

class AdminUserDetailScreen extends StatefulWidget {
  final AdminUserListItem user;

  const AdminUserDetailScreen({
    super.key,
    required this.user,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  bool _loadingProfile = true;
  bool _loadingProgress = true;
  String? _profileError;
  String? _progressError;

  AdminUserProfileDetail? _profileDetail;
  UserDashboardSummary? _summary;

  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
      _loadProgress();
    });
  }

  /// Headers para rutas que solo puede usar root/admin
  Map<String, String> _buildAdminHeaders() {
    final auth = AuthControllerProvider.of(context);
    final roleCode = auth.isRoot ? 'root' : 'admin';

    return {
      'Content-Type': 'application/json',
      'x-role': roleCode,
    };
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });

    try {
      final headers = _buildAdminHeaders();

      // 👇 usamos exactamente la ruta que ya tienes en el server
      final uri = Uri.parse(
        '${Env.apiBaseUrl}/api/users/${widget.user.id}/profile',
      );

      final resp = await http.get(uri, headers: headers);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final detail = AdminUserProfileDetail.fromJson(data);
        setState(() {
          _profileDetail = detail;
          _loadingProfile = false;
        });
      } else if (resp.statusCode == 404) {
        // No tiene info extra de perfil: mostramos "Sin descripción."
        setState(() {
          _profileDetail = null;
          _loadingProfile = false;
        });
      } else {
        setState(() {
          _loadingProfile = false;
          _profileError =
          'Error HTTP ${resp.statusCode} al cargar el perfil.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = 'Error de red al cargar el perfil: $e';
      });
    }
  }

  Future<void> _loadProgress() async {
    setState(() {
      _loadingProgress = true;
      _progressError = null;
    });

    try {
      // Reutilizamos el endpoint de "mi resumen" simulando al usuario
      final uri = Uri.parse(
        '${Env.apiBaseUrl}/api/dashboard/my-summary'
            '?year=$_selectedYear&month=$_selectedMonth',
      );

      final headers = {
        'Content-Type': 'application/json',
        'x-role': 'usuario',
        'x-user-id': widget.user.id.toString(),
      };

      final resp = await http.get(uri, headers: headers);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final s = UserDashboardSummary.fromJson(data);
        setState(() {
          _summary = s;
          _loadingProgress = false;
        });
      } else {
        setState(() {
          _loadingProgress = false;
          _progressError =
          'Error HTTP ${resp.statusCode} al cargar el progreso.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProgress = false;
        _progressError = 'Error de red al cargar el progreso: $e';
      });
    }
  }

  Future<void> _reload() async {
    await Future.wait([
      _loadProfile(),
      _loadProgress(),
    ]);
  }

  void _changeMonth(int delta) {
    var year = _selectedYear;
    var month = _selectedMonth + delta;
    if (month <= 0) {
      month = 12;
      year -= 1;
    } else if (month >= 13) {
      month = 1;
      year += 1;
    }
    setState(() {
      _selectedYear = year;
      _selectedMonth = month;
    });
    _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    final avatarInitial = widget.user.name.isNotEmpty
        ? widget.user.name[0].toUpperCase()
        : '?';
    final monthName = DateFormat.yMMMM('es_MX')
        .format(DateTime(_selectedYear, _selectedMonth, 1));

    final profile = _profileDetail;
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.name),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= PERFIL =================
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: (profile?.avatarUrl != null &&
                            profile!.avatarUrl!.isNotEmpty)
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: (profile?.avatarUrl == null ||
                            profile!.avatarUrl!.isEmpty)
                            ? Text(
                          avatarInitial,
                          style: const TextStyle(fontSize: 24),
                        )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text(_roleLabel(widget.user.role)),
                                  avatar: const Icon(
                                    Icons.badge_outlined,
                                    size: 18,
                                  ),
                                ),
                                if (widget.user.isActive)
                                  Chip(
                                    label: const Text('Activo'),
                                    avatar: const Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                    ),
                                  )
                                else
                                  Chip(
                                    label: const Text('Inactivo'),
                                    avatar: const Icon(
                                      Icons.block,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.email_outlined, size: 18),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.user.email,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (profile?.phone != null &&
                                profile!.phone!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone_outlined, size: 18),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(profile.phone!),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              profile?.description?.isNotEmpty == true
                                  ? profile!.description!
                                  : 'Sin descripción.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                            if (_profileError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _profileError!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ============== PROGRESO ==============
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed:
                    _loadingProgress ? null : () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Mes anterior',
                  ),
                  Column(
                    children: [
                      Text(
                        'Progreso de ${widget.user.name}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        monthName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed:
                    _loadingProgress ? null : () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Mes siguiente',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_loadingProgress)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_progressError != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _progressError!,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onErrorContainer,
                      ),
                    ),
                  ),
                )
              else if (summary == null || !summary.hasTasks)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 40),
                          SizedBox(height: 12),
                          Text(
                            'Este usuario aún no tiene tareas registradas en este periodo.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                    _AdminUserStatsGrid(summary: summary),
                    const SizedBox(height: 24),
                    Text(
                      'Progreso por estado',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _AdminUserProgressChart(
                      points: [
                        summary.pending.toDouble(),
                        summary.inProgress.toDouble(),
                        summary.done.toDouble(),
                      ],
                      labels: const ['Pend.', 'En proc.', 'Hechas'],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Prioridad de tareas',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _AdminUserPriorityRow(summary: summary),
                  ],
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'root':
        return 'Root';
      case 'admin':
        return 'Administrador';
      default:
        return 'Usuario';
    }
  }
}

// ========================= WIDGETS DE PROGRESO =========================
// (todo lo de _AdminUserStatsGrid, _AdminUserStatCard, _AdminUserProgressChart
//  y _AdminUserPriorityRow se queda igual que ya lo tenías)


// ========================= WIDGETS DE PROGRESO =========================

class _AdminUserStatsGrid extends StatelessWidget {
  final UserDashboardSummary summary;

  const _AdminUserStatsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 600;
    final fullWidth =
        MediaQuery.of(context).size.width - 32; // padding aproximado
    final cardWidth = isSmall ? fullWidth : (fullWidth - 16) / 2;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: cardWidth,
          child: _AdminUserStatCard(
            icon: Icons.assignment_outlined,
            iconColor: Theme.of(context).colorScheme.primary,
            title: 'Total tareas',
            value: summary.total.toString(),
            subtitle: 'Asignadas en el mes',
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _AdminUserStatCard(
            icon: Icons.pending_actions_outlined,
            iconColor: Colors.orange,
            title: 'Pendientes',
            value: summary.pending.toString(),
            subtitle:
            '${(summary.pendingPercent * 100).toStringAsFixed(0)}% del total',
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _AdminUserStatCard(
            icon: Icons.play_circle_outline,
            iconColor: Colors.blue,
            title: 'En proceso',
            value: summary.inProgress.toString(),
            subtitle:
            '${(summary.inProgressPercent * 100).toStringAsFixed(0)}% del total',
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _AdminUserStatCard(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
            title: 'Completadas',
            value: summary.done.toString(),
            subtitle:
            '${(summary.donePercent * 100).toStringAsFixed(0)}% del total',
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _AdminUserStatCard(
            icon: Icons.access_time,
            iconColor: Colors.redAccent,
            title: 'Vencen en 48h',
            value: summary.dueSoon48h.toString(),
            subtitle: 'Tareas próximas a vencer',
          ),
        ),
      ],
    );
  }
}

class _AdminUserStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const _AdminUserStatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminUserProgressChart extends StatelessWidget {
  final List<double> points;
  final List<String> labels;

  const _AdminUserProgressChart({
    required this.points,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final maxY =
    (points.fold<double>(0, (m, v) => v > m ? v : m) + 1).clamp(1, 9999);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (points.length - 1).toDouble(),
              minY: 0,
              maxY: maxY.toDouble(),
              gridData: FlGridData(
                show: true,
                horizontalInterval: 1,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          labels[index],
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  spots: [
                    for (int i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i]),
                  ],
                  barWidth: 3,
                  color: color,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminUserPriorityRow extends StatelessWidget {
  final UserDashboardSummary summary;

  const _AdminUserPriorityRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget pill(String label, int count, Color color) {
      return Chip(
        avatar: CircleAvatar(
          backgroundColor: color,
          radius: 8,
        ),
        label: Text('$label: $count'),
        backgroundColor: cs.surfaceVariant.withOpacity(0.6),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        pill('Baja', summary.low, Colors.green),
        pill('Media', summary.medium, Colors.orange),
        pill('Alta', summary.high, Colors.red),
      ],
    );
  }
}
