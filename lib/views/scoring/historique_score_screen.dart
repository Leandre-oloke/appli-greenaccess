import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/score_climat_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class HistoriqueScoreScreen extends ConsumerStatefulWidget {
  const HistoriqueScoreScreen({super.key});

  @override
  ConsumerState<HistoriqueScoreScreen> createState() => _HistoriqueScoreScreenState();
}

class _HistoriqueScoreScreenState extends ConsumerState<HistoriqueScoreScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authViewModelProvider).user?.id ?? '';
      ref.read(scoringViewModelProvider(uid).notifier).loadHistoriqueScores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authViewModelProvider).user?.id ?? '';
    final state = ref.watch(scoringViewModelProvider(uid));

    return Scaffold(
      appBar: AppBar(title: const Text('Historique des scores')),
      body: state.isCalculating
          ? const Center(child: CircularProgressIndicator())
          : state.history.isEmpty
              ? _EmptyHistory()
              : Column(
                  children: [
                    _ChartCard(history: state.history),
                    Expanded(child: _HistoryList(history: state.history)),
                  ],
                ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<ScoreClimatModel> history;
  const _ChartCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.scoreTotal);
    }).toList();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Évolution du Score Climat ESG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('10 derniers calculs',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.divider,
                      strokeWidth: 0.5,
                    ),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (val, _) => Text(
                          '${val.toInt()}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 60,
                        color: AppColors.success.withValues(alpha: 0.5),
                        strokeWidth: 1.5,
                        dashArray: [6, 3],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          labelResolver: (_) => '  Seuil financement',
                          style: const TextStyle(color: AppColors.success, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: 5,
                          color: AppColors.primary,
                          strokeColor: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<ScoreClimatModel> history;
  const _HistoryList({required this.history});

  @override
  Widget build(BuildContext context) {
    final reversed = history.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: reversed.length,
      itemBuilder: (_, i) => _ScoreItem(score: reversed[i], index: reversed.length - i),
    );
  }
}

class _ScoreItem extends StatelessWidget {
  final ScoreClimatModel score;
  final int index;
  const _ScoreItem({required this.score, required this.index});

  Color _niveauColor() => switch (score.niveau) {
        NiveauScore.insuffisant => AppColors.scoreInsuffisant,
        NiveauScore.intermediaire => AppColors.scoreIntermediaire,
        NiveauScore.bon => AppColors.scoreBon,
        NiveauScore.excellent => AppColors.scoreExcellent,
      };

  String _niveauLabel() => switch (score.niveau) {
        NiveauScore.insuffisant => 'Insuffisant',
        NiveauScore.intermediaire => 'Intermédiaire',
        NiveauScore.bon => 'Bon',
        NiveauScore.excellent => 'Excellent',
      };

  @override
  Widget build(BuildContext context) {
    final color = _niveauColor();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            '${score.scoreTotal.round()}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        title: Text(
          'Score #$index  ·  ${_niveauLabel()}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _formatDate(score.dateCalcul),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Icon(
          score.peutDemanderFinancement ? Icons.check_circle : Icons.cancel_outlined,
          color: score.peutDemanderFinancement ? AppColors.success : AppColors.error,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 80, color: AppColors.divider),
          SizedBox(height: 16),
          Text('Aucun score calculé', style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Text('Remplissez le formulaire de scoring pour obtenir votre premier score.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
