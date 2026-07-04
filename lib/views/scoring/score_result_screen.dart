import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../models/score_climat_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class ScoreResultScreen extends ConsumerWidget {
  const ScoreResultScreen({super.key});

  Color _colorForNiveau(NiveauScore niveau) => switch (niveau) {
        NiveauScore.insuffisant => AppColors.scoreInsuffisant,
        NiveauScore.intermediaire => AppColors.scoreIntermediaire,
        NiveauScore.bon => AppColors.scoreBon,
        NiveauScore.excellent => AppColors.scoreExcellent,
      };

  String _labelForNiveau(NiveauScore niveau) => switch (niveau) {
        NiveauScore.insuffisant => 'Insuffisant',
        NiveauScore.intermediaire => 'Intermédiaire',
        NiveauScore.bon => 'Bon',
        NiveauScore.excellent => 'Excellent',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authViewModelProvider).user?.id ?? '';
    final score = ref.watch(scoringViewModelProvider(userId)).currentScore;

    if (score == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Score Climat')),
        body: const Center(child: Text('Aucun score disponible')),
      );
    }

    final color = _colorForNiveau(score.niveau);
    final label = _labelForNiveau(score.niveau);

    return Scaffold(
      appBar: AppBar(title: const Text('Résultat du Score')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircularPercentIndicator(
              radius: 90,
              lineWidth: 12,
              percent: score.scoreTotal / 100,
              animation: true,
              animationDuration: 1500,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    score.scoreTotal.toStringAsFixed(0),
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: color),
                  ),
                  Text('/100', style: TextStyle(color: color)),
                ],
              ),
              progressColor: color,
              backgroundColor: AppColors.divider,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(height: 24),
            if (score.peutDemanderFinancement)
              _InfoBanner(
                icon: Icons.check_circle,
                text: 'Score ≥ 60 : vous pouvez soumettre une demande de financement !',
                color: AppColors.success,
              )
            else
              _InfoBanner(
                icon: Icons.info_outline,
                text: 'Score < 60 : complétez des formations pour améliorer votre score.',
                color: AppColors.warning,
              ),
            const SizedBox(height: 24),
            if (score.suggestions.isNotEmpty) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Suggestions d\'amélioration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 12),
              ...score.suggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.arrow_right, color: AppColors.primary),
                        Expanded(child: Text(s)),
                      ],
                    ),
                  )),
              const SizedBox(height: 24),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.scoreHistory),
                    icon: const Icon(Icons.history),
                    label: const Text('Historique'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: score.peutDemanderFinancement
                        ? () => context.go(AppRoutes.financement)
                        : () => context.push(AppRoutes.courseList),
                    icon: Icon(score.peutDemanderFinancement ? Icons.account_balance : Icons.school),
                    label: Text(score.peutDemanderFinancement ? 'Demander un financement' : 'Améliorer via formation'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoBanner({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
