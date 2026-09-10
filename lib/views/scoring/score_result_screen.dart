import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/score_climat_model.dart';
import '../../routes.dart';
import '../../ui/ui.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/scoring_viewmodel.dart';

class ScoreResultScreen extends ConsumerWidget {
  const ScoreResultScreen({super.key});

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
    final user = ref.watch(authViewModelProvider).user;
    final userId = user?.id ?? '';
    final score = ref.watch(scoringViewModelProvider(userId)).currentScore;

    if (score == null) {
      return GaScaffold(
        appBar: const GaAppBar(title: 'Score Climat'),
        body: const GaEmptyState(
          icon: Icons.speed_rounded,
          title: 'Aucun score disponible',
          message: 'Complétez le questionnaire pour obtenir votre Score Climat.',
        ),
      );
    }

    final crit = score.criteres;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Héros ─────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: GaGradients.of(Theme.of(context).brightness).header,
                borderRadius: GaRadii.brHeaderBottom,
              ),
              padding: const EdgeInsets.fromLTRB(
                  GaSpacing.lg, GaSpacing.sm, GaSpacing.lg, GaSpacing.xxl),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(AppRoutes.dashboard),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Exporter en PDF',
                          onPressed: () =>
                              _exportPdf(context, score, user?.nom ?? ''),
                          icon: const Icon(Icons.ios_share_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: GaSpacing.sm),
                    Hero(
                      tag: 'score-gauge',
                      child: Material(
                        color: Colors.transparent,
                        child: GaScoreGauge(
                          score: score.scoreTotal,
                          level: score.niveau,
                          size: 232,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(GaSpacing.screenH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: gaStagger([
                  GaInfoBanner(
                    message: GaScoreScale.eligibiliteMessage(score.scoreTotal),
                    kind: score.peutDemanderFinancement
                        ? GaBannerKind.success
                        : GaBannerKind.warning,
                  ),
                  const SizedBox(height: GaSpacing.xl),
                  const GaSectionHeader('Détail des critères'),
                  GaCard(
                    child: Column(
                      children: [
                        _meter(context, 'Activité verte', crit.scoreActivite),
                        const SizedBox(height: GaSpacing.md),
                        _meter(context, 'Alignement UEMOA', crit.scoreUemoa),
                        const SizedBox(height: GaSpacing.md),
                        _meter(context, 'Réduction CO₂', crit.scoreCo2),
                        const SizedBox(height: GaSpacing.md),
                        _meter(context, 'Certifications', crit.scoreCertif),
                        const SizedBox(height: GaSpacing.md),
                        _meter(context, 'Résilience climatique',
                            crit.scoreResilience),
                        const SizedBox(height: GaSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Bonus formations',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ),
                            GaBadgePill(
                              label:
                                  '+${crit.bonusFormation.toStringAsFixed(0)} pts',
                              color: Theme.of(context).colorScheme.primary,
                              icon: Icons.school_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (score.suggestions.isNotEmpty) ...[
                    const SizedBox(height: GaSpacing.xl),
                    const GaSectionHeader("Comment progresser"),
                    GaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final s in score.suggestions)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: GaSpacing.sm),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.eco_rounded,
                                      size: 18,
                                      color:
                                          Theme.of(context).colorScheme.primary),
                                  const SizedBox(width: GaSpacing.sm),
                                  Expanded(
                                      child: Text(s,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: GaSpacing.xl),
                  Row(
                    children: [
                      GaSecondaryButton.outlined(
                        label: 'Historique',
                        icon: Icons.timeline_rounded,
                        onPressed: () => context.push(AppRoutes.scoreHistory),
                      ),
                      const SizedBox(width: GaSpacing.md),
                      Expanded(
                        child: GaPrimaryButton(
                          label: score.peutDemanderFinancement
                              ? 'Demander un financement'
                              : 'Améliorer via formation',
                          icon: score.peutDemanderFinancement
                              ? Icons.account_balance_rounded
                              : Icons.school_rounded,
                          onPressed: score.peutDemanderFinancement
                              ? () => context.go(AppRoutes.financement)
                              : () => context.push(AppRoutes.courseList),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GaSpacing.md),
                  GaSecondaryButton.ghost(
                    label: 'Exporter le rapport PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    expand: true,
                    onPressed: () => _exportPdf(context, score, user?.nom ?? ''),
                  ),
                  const SizedBox(height: GaSpacing.xl),
                ]),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: GaMotion.base);
  }

  Widget _meter(BuildContext context, String label, double value) => GaMeterRow(
        label: label,
        value: value,
        trailing: '${value.round()}/100',
        color: Theme.of(context).colorScheme.primary,
      );
}
