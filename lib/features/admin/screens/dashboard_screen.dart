import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: const [
            _KpiCard(label: 'Tareas totales', value: '128'),
            _KpiCard(label: 'Pendientes', value: '36'),
            _KpiCard(label: 'En proceso', value: '58'),
            _KpiCard(label: 'Completadas', value: '34'),
          ],
        ),
        const SizedBox(height: 24),
        const _AlertStrip(text: '10 tareas vencen en las próximas 48 horas.'),
        const SizedBox(height: 16),
        const _ChartPlaceholder(title: 'Distribución por estado (demo)'),
        const SizedBox(height: 16),
        const _ChartPlaceholder(title: 'Prioridad (demo)'),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label; final String value;
  const _KpiCard({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

class _AlertStrip extends StatelessWidget {
  final String text; const _AlertStrip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(.5)),
      ),
      child: Row(children: [const Icon(Icons.warning_amber_rounded), const SizedBox(width: 8), Expanded(child: Text(text))]),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String title; const _ChartPlaceholder({required this.title});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(height: 180, child: Center(child: Text(title))),
    );
  }
}
