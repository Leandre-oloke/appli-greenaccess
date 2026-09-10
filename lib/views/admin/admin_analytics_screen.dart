import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminViewModelProvider.notifier).loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);
    final a = state.analytics;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(adminViewModelProvider.notifier).loadAnalytics(),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : a.isEmpty
              ? const Center(child: Text('Aucune donnée disponible'))
              : RefreshIndicator(
                  onRefresh: () => ref.read(adminViewModelProvider.notifier).loadAnalytics(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── KPI Cards ──────────────────────────────────────────
                      _SectionTitle('Indicateurs clés'),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.4,
                        children: [
                          _KpiCard(
                            label: 'Score ESG moyen',
                            value: '${(a['scoreMoyen'] as double? ?? 0).toStringAsFixed(1)}/100',
                            icon: Icons.eco,
                            color: AppColors.scoreBon,
                          ),
                          _KpiCard(
                            label: 'Scores calculés',
                            value: '${a['totalScores'] ?? 0}',
                            icon: Icons.assessment,
                            color: AppColors.primary,
                          ),
                          _KpiCard(
                            label: 'Contrats actifs',
                            value: '${a['contratsActifs'] ?? 0}',
                            icon: Icons.shield,
                            color: const Color(0xFF6A1B9A),
                          ),
                          _KpiCard(
                            label: 'Formations terminées',
                            value: '${a['formationsCompletees'] ?? 0}',
                            icon: Icons.school,
                            color: AppColors.secondary,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── Répartition scores par niveau ──────────────────────
                      _SectionTitle('Répartition des scores ESG'),
                      const SizedBox(height: 12),
                      _ScoresNiveauChart(data: a['scoresParNiveau'] as Map<String, int>? ?? {}),

                      const SizedBox(height: 28),

                      // ── Demandes par statut ────────────────────────────────
                      _SectionTitle('Demandes de financement par statut'),
                      const SizedBox(height: 12),
                      _DemandesChart(data: a['demandesParStatut'] as Map<String, int>? ?? {}),

                      const SizedBox(height: 28),

                      // ── Utilisateurs par rôle ──────────────────────────────
                      _SectionTitle('Utilisateurs par rôle'),
                      const SizedBox(height: 12),
                      _UsersRoleChart(data: a['usersParRole'] as Map<String, int>? ?? {}),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary));
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(label,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoresNiveauChart extends StatelessWidget {
  final Map<String, int> data;
  const _ScoresNiveauChart({required this.data});

  static const _colors = {
    'excellent':    AppColors.scoreExcellent,
    'bon':          AppColors.scoreBon,
    'intermediaire': AppColors.scoreIntermediaire,
    'insuffisant':  AppColors.scoreInsuffisant,
  };
  static const _labels = {
    'excellent':    'Excellent',
    'bon':          'Bon',
    'intermediaire': 'Intermédiaire',
    'insuffisant':  'Insuffisant',
  };

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0, (a, b) => a + b);
    if (total == 0) return const _EmptyChart();

    final sections = data.entries
        .where((e) => e.value > 0)
        .map((e) => PieChartSectionData(
              value: e.value.toDouble(),
              color: _colors[e.key] ?? Colors.grey,
              title: '${((e.value / total) * 100).toStringAsFixed(0)}%',
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              radius: 55,
            ))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(PieChartData(sections: sections, sectionsSpace: 2)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: data.entries.map((e) => _Legend(
                color: _colors[e.key] ?? Colors.grey,
                label: '${_labels[e.key] ?? e.key} (${e.value})',
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemandesChart extends StatelessWidget {
  final Map<String, int> data;
  const _DemandesChart({required this.data});

  static const _colors = {
    'soumis':    AppColors.warning,
    'enExamen':  AppColors.info,
    'approuve':  AppColors.success,
    'rejete':    AppColors.error,
    'finance':   AppColors.primary,
    'brouillon': Colors.grey,
  };
  static const _labels = {
    'soumis':    'Soumis',
    'enExamen':  'En examen',
    'approuve':  'Approuvé',
    'rejete':    'Rejeté',
    'finance':   'Financé',
    'brouillon': 'Brouillon',
  };

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    if (entries.isEmpty) return const _EmptyChart();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: List.generate(entries.length, (i) {
                    final color = _colors[entries[i].key] ?? Colors.grey;
                    return BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: entries[i].value.toDouble(),
                        color: color,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ]);
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < 0 || i >= entries.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _labels[entries[i].key] ?? entries[i].key,
                              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, _) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersRoleChart extends StatelessWidget {
  final Map<String, int> data;
  const _UsersRoleChart({required this.data});

  static const _labels = {
    'user':               'Utilisateurs',
    'admin':              'Administrateurs',
    'partenaireFinanceur': 'Partenaires financiers',
    'partenaireAssureur':  'Partenaires assureurs',
  };
  static const _colors = [
    AppColors.primary,
    AppColors.error,
    AppColors.scoreBon,
    Color(0xFF6A1B9A),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    if (entries.isEmpty) return const _EmptyChart();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: entries.asMap().entries.map((e) {
            final color = _colors[e.key % _colors.length];
            final label = _labels[e.value.key] ?? e.value.key;
            final count = e.value.value;
            final total = data.values.fold(0, (a, b) => a + b);
            final pct = total > 0 ? count / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
                    Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  ]),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.divider,
                    color: color,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ]);
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('Aucune donnée', style: TextStyle(color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}
