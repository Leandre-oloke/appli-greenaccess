import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/score_climat_model.dart';
import '../../routes.dart';
import '../../ui/ui.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class HistoriqueScoreScreen extends ConsumerStatefulWidget {
  const HistoriqueScoreScreen({super.key});

  @override
  ConsumerState<HistoriqueScoreScreen> createState() =>
      _HistoriqueScoreScreenState();
}

class _HistoriqueScoreScreenState
    extends ConsumerState<HistoriqueScoreScreen> {
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
    final history = state.history;
    final latest = history.isNotEmpty ? history.first : null;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GaGradientHeader(
            title: 'Votre progression',
            subtitle: 'Historique du Score Climat ESG',
            leading: IconButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.dashboard),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            trailing: latest == null
                ? null
                : GaBadgePill(
                    label: '${latest.scoreTotal.round()} pts',
                    color: Colors.white,
                    filled: false,
                  ),
          ),
          Expanded(
            child: state.isCalculating
                ? const Padding(
                    padding: EdgeInsets.all(GaSpacing.screenH),
                    child: GaSkeletonList(itemCount: 6),
                  )
                : history.isEmpty
                    ? GaEmptyState(
                        icon: Icons.show_chart_rounded,
                        title: 'Aucun score calculé',
                        message:
                            'Complétez le questionnaire pour obtenir votre premier score.',
                        action: GaPrimaryButton(
                          label: 'Calculer mon score',
                          icon: Icons.auto_awesome_rounded,
                          expand: false,
                          onPressed: () => context.go(AppRoutes.scoringForm),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(GaSpacing.screenH),
                        children: [
                          _ChartCard(history: history),
                          const SizedBox(height: GaSpacing.xl),
                          const GaSectionHeader('Tous vos calculs'),
                          for (var i = 0; i < history.length; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: GaSpacing.md),
                              child: _ScoreItem(
                                score: history[i],
                                previous: i + 1 < history.length
                                    ? history[i + 1]
                                    : null,
                                number: history.length - i,
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.history});
  final List<ScoreClimatModel> history;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clay = context.gaColors.clay;
    // Historique renvoyé du plus récent au plus ancien → on inverse pour le tracé.
    final chrono = history.reversed.toList();
    final spots = chrono
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.scoreTotal))
        .toList();

    return GaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Évolution', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text('${history.length} derniers calculs',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: GaSpacing.lg),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: cs.outline, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 25,
                      getTitlesWidget: (val, _) => Text('${val.toInt()}',
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: GaScoreScale.seuilFinancement.toDouble(),
                    color: clay,
                    strokeWidth: 1.5,
                    dashArray: [6, 3],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      labelResolver: (_) => '  Seuil financement',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: clay),
                    ),
                  ),
                ]),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: cs.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: cs.primary,
                        strokeColor: cs.surface,
                        strokeWidth: 2,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.primary.withValues(alpha: 0.22),
                          cs.primary.withValues(alpha: 0.0),
                        ],
                      ),
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

class _ScoreItem extends StatelessWidget {
  const _ScoreItem({
    required this.score,
    required this.previous,
    required this.number,
  });
  final ScoreClimatModel score;
  final ScoreClimatModel? previous;
  final int number;

  @override
  Widget build(BuildContext context) {
    final color =
        GaScoreScale.colorFor(score.niveau, Theme.of(context).brightness);
    final delta =
        previous == null ? null : score.scoreTotal - previous!.scoreTotal;

    return GaCard(
      padding: const EdgeInsets.all(GaSpacing.md),
      child: Row(
        children: [
          GaMiniGauge(score: score.scoreTotal, level: score.niveau, size: 52),
          const SizedBox(width: GaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Score #$number',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: GaSpacing.sm),
                    if (delta != null && delta.abs() >= 0.5)
                      GaBadgePill(
                        label:
                            '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(0)}',
                        color: delta > 0
                            ? context.gaColors.success
                            : Theme.of(context).colorScheme.error,
                        icon: delta > 0
                            ? Icons.north_east_rounded
                            : Icons.south_east_rounded,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('dd/MM/yyyy · HH:mm').format(score.dateCalcul),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          GaBadgePill(
            label: GaScoreScale.labelFor(score.niveau),
            color: color,
            dense: true,
          ),
        ],
      ),
    );
  }
}
