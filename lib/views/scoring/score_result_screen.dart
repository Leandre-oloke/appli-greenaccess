import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../routes.dart';
import '../../models/score_climat_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class ScoreResultScreen extends ConsumerWidget {
  const ScoreResultScreen({super.key});

  Color _colorForNiveau(NiveauScore niveau) => switch (niveau) {
        NiveauScore.insuffisant   => AppColors.scoreInsuffisant,
        NiveauScore.intermediaire => AppColors.scoreIntermediaire,
        NiveauScore.bon           => AppColors.scoreBon,
        NiveauScore.excellent     => AppColors.scoreExcellent,
      };

  String _labelForNiveau(NiveauScore niveau) => switch (niveau) {
        NiveauScore.insuffisant   => 'Insuffisant',
        NiveauScore.intermediaire => 'Intermédiaire',
        NiveauScore.bon           => 'Bon',
        NiveauScore.excellent     => 'Excellent',
      };

  Future<void> _exportPdf(
      BuildContext context, ScoreClimatModel score, String userName) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Couleur selon niveau
    final pdfColor = switch (score.niveau) {
      NiveauScore.excellent     => PdfColors.green700,
      NiveauScore.bon           => PdfColors.lightGreen700,
      NiveauScore.intermediaire => PdfColors.orange700,
      NiveauScore.insuffisant   => PdfColors.red700,
    };
    final niveauLabel = switch (score.niveau) {
      NiveauScore.excellent     => 'Excellent',
      NiveauScore.bon           => 'Bon',
      NiveauScore.intermediaire => 'Intermédiaire',
      NiveauScore.insuffisant   => 'Insuffisant',
    };

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── En-tête ──────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green800,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('GreenAccess',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                  pw.SizedBox(height: 4),
                  pw.Text('Rapport de Score Climat ESG',
                      style: pw.TextStyle(fontSize: 14, color: PdfColor.fromInt(0xCCFFFFFF))),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // ── Identité ──────────────────────────────────────────────────
            pw.Text('Bénéficiaire : $userName',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date du rapport : $dateStr',
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),

            // ── Score global ──────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: pdfColor, width: 2),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Score Climat ESG',
                          style: pw.TextStyle(
                              fontSize: 13, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text(niveauLabel,
                          style: pw.TextStyle(
                              fontSize: 11, color: pdfColor, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Text('${score.scoreTotal.toStringAsFixed(0)}/100',
                      style: pw.TextStyle(
                          fontSize: 32, fontWeight: pw.FontWeight.bold, color: pdfColor)),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // ── Détail des critères ───────────────────────────────────────
            pw.Text('Détail des critères',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _pdfCritere('Activité agricole/verte',
                score.criteres.scoreActivite, PdfColors.green700),
            _pdfCritere('Alignement taxonomie UEMOA',
                score.criteres.scoreUemoa, PdfColors.teal700),
            _pdfCritere('Réduction CO₂',
                score.criteres.scoreCo2, PdfColors.lightBlue700),
            _pdfCritere('Certifications',
                score.criteres.scoreCertif, PdfColors.orange700),
            _pdfCritere('Résilience climatique',
                score.criteres.scoreResilience, PdfColors.brown700),
            pw.SizedBox(height: 6),
            pw.Text(
              'Bonus formations : +${score.criteres.bonusFormation.toStringAsFixed(0)} pts',
              style: pw.TextStyle(
                  fontSize: 11, color: PdfColors.green700, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 24),

            // ── Éligibilité financement ───────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: score.peutDemanderFinancement
                    ? PdfColors.green50
                    : PdfColors.orange50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                score.peutDemanderFinancement
                    ? '✓ Score ≥ 60 : éligible au financement vert'
                    : '⚠ Score < 60 : non éligible au financement vert',
                style: pw.TextStyle(
                    fontSize: 11,
                    color: score.peutDemanderFinancement
                        ? PdfColors.green800
                        : PdfColors.orange800,
                    fontWeight: pw.FontWeight.bold),
              ),
            ),

            if (score.suggestions.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text('Suggestions d\'amélioration',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...score.suggestions.map(
                (s) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• ', style: const pw.TextStyle(color: PdfColors.green700)),
                      pw.Expanded(child: pw.Text(s, style: const pw.TextStyle(fontSize: 11))),
                    ],
                  ),
                ),
              ),
            ],

            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Document généré par GreenAccess — plateforme de finance verte UEMOA',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'score_esg_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _pdfCritere(String label, double score, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
              pw.Text('${score.toStringAsFixed(0)}/100',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.LinearProgressIndicator(
            value: score / 100,
            backgroundColor: PdfColors.grey200,
            valueColor: color,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user   = ref.watch(authViewModelProvider).user;
    final userId = user?.id ?? '';
    final score  = ref.watch(scoringViewModelProvider(userId)).currentScore;

    if (score == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Score Climat')),
        body: const Center(child: Text('Aucun score disponible')),
      );
    }

    final color = _colorForNiveau(score.niveau);
    final label = _labelForNiveau(score.niveau);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultat du Score'),
        actions: [
          IconButton(
            tooltip: 'Exporter en PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _exportPdf(context, score, user?.nom ?? ''),
          ),
        ],
      ),
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
                    style: TextStyle(
                        fontSize: 40, fontWeight: FontWeight.bold, color: color),
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
                  color: color, borderRadius: BorderRadius.circular(20)),
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
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
                child: Text('Suggestions d\'amélioration',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    icon: Icon(score.peutDemanderFinancement
                        ? Icons.account_balance
                        : Icons.school),
                    label: Text(score.peutDemanderFinancement
                        ? 'Demander un financement'
                        : 'Améliorer via formation'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Bouton export PDF secondaire visible en bas d'écran
            OutlinedButton.icon(
              onPressed: () => _exportPdf(context, score, user?.nom ?? ''),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Exporter le rapport PDF'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
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
          Expanded(
              child: Text(text,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
