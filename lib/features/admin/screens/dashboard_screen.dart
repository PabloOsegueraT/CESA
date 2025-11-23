// lib/features/admin/screens/dashboard_screen.dart
// lib/features/admin/screens/dashboard_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import '../../../core/constants/env.dart';
import '../../../state/auth_controller.dart';

class DashboardSummary {
  final int total;
  final int pending;
  final int inProgress;
  final int done;
  final int dueSoon48h;
  final int low;
  final int medium;
  final int high;

  DashboardSummary({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.done,
    required this.dueSoon48h,
    required this.low,
    required this.medium,
    required this.high,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map<String, dynamic>? ?? {});
    final prios = (json['priorities'] as Map<String, dynamic>? ?? {});

    int _read(Map<String, dynamic> m, String key) {
      final v = m[key];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return DashboardSummary(
      total: _read(totals, 'total'),
      pending: _read(totals, 'pending'),
      inProgress: _read(totals, 'inProgress'),
      done: _read(totals, 'done'),
      dueSoon48h: json['dueSoon48h'] is num
          ? (json['dueSoon48h'] as num).toInt()
          : int.tryParse('${json['dueSoon48h'] ?? 0}') ?? 0,
      low: _read(prios, 'low'),
      medium: _read(prios, 'medium'),
      high: _read(prios, 'high'),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DashboardSummary? _summary;
  bool _loading = true;
  bool _error = false;
  String? _errorMessage;

  DateTime _selectedMonth =
  DateTime(DateTime.now().year, DateTime.now().month);

  static const _monthNames = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSummary();
    });
  }

  String get _monthLabel {
    final m = _monthNames[_selectedMonth.month - 1];
    final cap = '${m[0].toUpperCase()}${m.substring(1)}';
    return '$cap ${_selectedMonth.year}';
  }

  Future<Map<String, String>> _buildHeaders() async {
    final auth = AuthControllerProvider.of(context);
    final roleCode = auth.isRoot ? 'root' : 'admin';

    return {
      'Content-Type': 'application/json',
      'x-role': roleCode,
    };
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = null;
    });

    try {
      final headers = await _buildHeaders();
      final year = _selectedMonth.year;
      final month = _selectedMonth.month;

      final uri = Uri.parse(
        '${Env.apiBaseUrl}/api/dashboard/summary?year=$year&month=$month',
      );

      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final summary = DashboardSummary.fromJson(data);
        if (!mounted) return;
        setState(() {
          _summary = summary;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = true;
          _errorMessage = 'Error ${resp.statusCode} al cargar dashboard';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _errorMessage = 'Error de red: $e';
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSummary,
          child: CustomScrollView(
            slivers: [
              // ---------- HEADER RESPONSIVO ----------
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmall = constraints.maxWidth < 380;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Resumen general',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 6 : 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: theme.colorScheme.surfaceVariant
                                  .withOpacity(0.3),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: _loading
                                      ? null
                                      : () => _changeMonth(-1),
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints:
                                  const BoxConstraints(maxWidth: 130),
                                  child: Text(
                                    _monthLabel,
                                    style: theme.textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed:
                                  _loading ? null : () => _changeMonth(1),
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // ---------- CONTENIDO ----------
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildContent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error) {
      return Column(
        children: [
          const SizedBox(height: 40),
          Text(
            _errorMessage ?? 'Error al cargar datos',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loadSummary,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    final s = _summary ??
        DashboardSummary(
          total: 0,
          pending: 0,
          inProgress: 0,
          done: 0,
          dueSoon48h: 0,
          low: 0,
          medium: 0,
          high: 0,
        );

    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final cardsPerRow = isSmall ? 1 : 2;
        final spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - (cardsPerRow - 1) * spacing) / cardsPerRow;

        // MÁS ALTAS EN CELULAR PARA QUE NO SE VEA AMONTONADO
        final chartHeight = isSmall ? 380.0 : 320.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -------- TARJETAS DE MÉTRICAS --------
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Tareas totales',
                    value: s.total,
                    color: colorScheme.primary,
                    icon: Icons.view_list_outlined,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Pendientes',
                    value: s.pending,
                    color: Colors.orangeAccent,
                    icon: Icons.pending_actions_outlined,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'En proceso',
                    value: s.inProgress,
                    color: Colors.lightBlueAccent,
                    icon: Icons.autorenew_outlined,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    title: 'Completadas',
                    value: s.done,
                    color: Colors.greenAccent,
                    icon: Icons.check_circle_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (s.dueSoon48h > 0)
              Card(
                color: Colors.amber.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Colors.amber.withOpacity(0.8),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${s.dueSoon48h} tareas vencen en las próximas 48 horas.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (s.dueSoon48h > 0) const SizedBox(height: 16),

            // -------- GRÁFICA ESTADOS --------
            _DashboardChartCard(
              height: chartHeight,
              child: _buildStatusChart(context, s, isSmall),
            ),
            const SizedBox(height: 16),

            // -------- GRÁFICA PRIORIDADES --------
            _DashboardChartCard(
              height: chartHeight,
              child: _buildPriorityChart(context, s, isSmall),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildStatusChart(
      BuildContext context, DashboardSummary s, bool isSmall) {
    final total = s.pending + s.inProgress + s.done;
    if (total == 0) {
      return const Center(
        child: Text('Sin tareas en este mes'),
      );
    }

    final radius = isSmall ? 52.0 : 70.0;
    final fontSize = isSmall ? 11.0 : 14.0;

    final sections = <PieChartSectionData>[];

    if (s.pending > 0) {
      sections.add(
        PieChartSectionData(
          value: s.pending.toDouble(),
          title: '${s.pending}',
          radius: radius,
          color: Colors.orangeAccent,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          titlePositionPercentageOffset: 0.8,
        ),
      );
    }
    if (s.inProgress > 0) {
      sections.add(
        PieChartSectionData(
          value: s.inProgress.toDouble(),
          title: '${s.inProgress}',
          radius: radius,
          color: Colors.lightBlueAccent,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          titlePositionPercentageOffset: 0.8,
        ),
      );
    }
    if (s.done > 0) {
      sections.add(
        PieChartSectionData(
          value: s.done.toDouble(),
          title: '${s.done}',
          radius: radius,
          color: Colors.greenAccent,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          titlePositionPercentageOffset: 0.8,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Distribución por estado',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          'Pendientes, en proceso y completadas para el mes seleccionado',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: isSmall ? 210 : 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 4,
              centerSpaceRadius: isSmall ? 42 : 40,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: const [
            _LegendDot(label: 'Pendientes', color: Colors.orangeAccent),
            _LegendDot(label: 'En proceso', color: Colors.lightBlueAccent),
            _LegendDot(label: 'Completadas', color: Colors.greenAccent),
          ],
        )
      ],
    );
  }

  Widget _buildPriorityChart(
      BuildContext context, DashboardSummary s, bool isSmall) {
    final total = s.low + s.medium + s.high;
    if (total == 0) {
      return const Center(
        child: Text('Sin tareas en este mes'),
      );
    }

    final radius = isSmall ? 52.0 : 70.0;
    final fontSize = isSmall ? 11.0 : 14.0;

    final sections = <PieChartSectionData>[];

    if (s.low > 0) {
      sections.add(
        PieChartSectionData(
          value: s.low.toDouble(),
          title: '${s.low}',
          radius: radius,
          color: Colors.tealAccent,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          titlePositionPercentageOffset: 0.8,
        ),
      );
    }
    if (s.medium > 0) {
      sections.add(
        PieChartSectionData(
          value: s.medium.toDouble(),
          title: '${s.medium}',
          radius: radius,
          color: Colors.deepPurpleAccent,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          titlePositionPercentageOffset: 0.8,
        ),
      );
    }
    if (s.high > 0) {
      sections.add(
        PieChartSectionData(
          value: s.high.toDouble(),
          title: '${s.high}',
          radius: radius,
          color: Colors.redAccent,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          titlePositionPercentageOffset: 0.8,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Distribución por prioridad',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          'Cuántas tareas hay por prioridad (baja, media, alta) este mes',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: isSmall ? 210 : 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 4,
              centerSpaceRadius: isSmall ? 42 : 40,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: const [
            _LegendDot(label: 'Baja', color: Colors.tealAccent),
            _LegendDot(label: 'Media', color: Colors.deepPurpleAccent),
            _LegendDot(label: 'Alta', color: Colors.redAccent),
          ],
        )
      ],
    );
  }
}

class _DashboardChartCard extends StatelessWidget {
  final double height;
  final Widget child;

  const _DashboardChartCard({
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: child,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.18),
              color.withOpacity(0.02),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$value',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
