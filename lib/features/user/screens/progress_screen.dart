// lib/features/user/screens/progress_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/env.dart';
import '../../../models/user_dashboard_summary.dart';
import '../../../state/profile_controller.dart';
import '../../../state/auth_controller.dart';

class UserProgressScreen extends StatefulWidget {
  const UserProgressScreen({super.key});

  @override
  State<UserProgressScreen> createState() => _UserProgressScreenState();
}

class _UserProgressScreenState extends State<UserProgressScreen> {
  bool _loading = true;
  String? _error;
  UserDashboardSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final profile = ProfileControllerProvider.of(context);
      final auth = AuthControllerProvider.of(context);

      final userId = profile.userId;
      if (userId == null || userId <= 0) {
        throw Exception('userId no disponible en ProfileController');
      }

      final roleCode =
      auth.isRoot ? 'root' : (auth.isAdmin ? 'admin' : 'usuario');

      final headers = <String, String>{
        'x-role': roleCode,
        'x-user-id': userId.toString(),
      };

      final uri = Uri.parse('${Env.apiBaseUrl}/api/dashboard/my-summary');
      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final summary = UserDashboardSummary.fromJson(data);

      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 8),
            Text(
              'Error al cargar tu progreso',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadSummary,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final s = _summary!;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Progreso de mis tareas',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Mes: ${s.month.toString().padLeft(2, '0')}/${s.year}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // Totales
          Row(
            children: [
              _MetricCard(
                label: 'Total',
                value: s.total,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _MetricCard(
                      label: 'Pendientes',
                      value: s.pending,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _MetricCard(
                      label: 'En progreso',
                      value: s.inProgress,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    _MetricCard(
                      label: 'Terminadas',
                      value: s.done,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Pie de estado
          Text(
            'Estado de mis tareas',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _StatusPieChart(summary: s),
          ),

          const SizedBox(height: 24),

          // Barras por prioridad
          Text(
            'Prioridad de mis tareas',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _PriorityBarChart(summary: s),
          ),

          const SizedBox(height: 24),

          // Próximas a vencer
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tareas que vencen en las próximas 48 horas',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    s.dueSoon48h.toString(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
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
}

// ----------------- Widgets auxiliares -----------------

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                value.toString(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  final UserDashboardSummary summary;

  const _StatusPieChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final total = summary.pending + summary.inProgress + summary.done;
    if (total == 0) {
      return const Center(child: Text('Sin tareas en este mes'));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          if (summary.pending > 0)
            PieChartSectionData(
              value: summary.pending.toDouble(),
              title: 'Pend.',
              radius: 50,
              color: Colors.orange,
            ),
          if (summary.inProgress > 0)
            PieChartSectionData(
              value: summary.inProgress.toDouble(),
              title: 'Progreso',
              radius: 50,
              color: Colors.blue,
            ),
          if (summary.done > 0)
            PieChartSectionData(
              value: summary.done.toDouble(),
              title: 'Hechas',
              radius: 50,
              color: Colors.green,
            ),
        ],
      ),
    );
  }
}

class _PriorityBarChart extends StatelessWidget {
  final UserDashboardSummary summary;

  const _PriorityBarChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.low + summary.medium + summary.high == 0) {
      return const Center(child: Text('Sin tareas en este mes'));
    }

    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                String text = '';
                if (value == 0) text = 'Baja';
                if (value == 1) text = 'Media';
                if (value == 2) text = 'Alta';
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(text),
                );
              },
            ),
          ),
        ),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(toY: summary.low.toDouble()),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(toY: summary.medium.toDouble()),
            ],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(toY: summary.high.toDouble()),
            ],
          ),
        ],
      ),
    );
  }
}
