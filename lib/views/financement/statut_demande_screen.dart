import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../models/demande_financement_model.dart';
import '../../routes.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/financement_viewmodel.dart';

class StatutDemandeScreen extends ConsumerStatefulWidget {
  final String demandeId;
  const StatutDemandeScreen({super.key, required this.demandeId});

  @override
  ConsumerState<StatutDemandeScreen> createState() => _StatutDemandeScreenState();
}

class _StatutDemandeScreenState extends ConsumerState<StatutDemandeScreen> {
  DemandeFinancementModel? _demande;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(authViewModelProvider).user?.id ?? '';
    final d = await ref.read(financementViewModelProvider(uid).notifier).getStatut(widget.demandeId);
    if (mounted) setState(() { _demande = d; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statut de la demande')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _demande == null
              ? const Center(child: Text('Demande introuvable'))
              : _DemandeDetail(demande: _demande!),
    );
  }
}

class _DemandeDetail extends StatelessWidget {
  final DemandeFinancementModel demande;
  const _DemandeDetail({required this.demande});

  static const _steps = [
    StatutDemande.soumis,
    StatutDemande.enExamen,
    StatutDemande.approuve,
    StatutDemande.finance,
  ];

  int get _currentStepIndex {
    if (demande.statut == StatutDemande.rejete) return 1;
    return _steps.indexOf(demande.statut).clamp(0, _steps.length - 1);
  }

  bool get _isApprouve =>
      demande.statut == StatutDemande.approuve || demande.statut == StatutDemande.finance;

  Future<void> _exportContratPdf(BuildContext context) async {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final fmtDate = DateFormat('dd/MM/yyyy');

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // En-tête
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF2E7D32),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('GreenAccess',
                          style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                      pw.Text('Financement climatique',
                          style: pw.TextStyle(color: PdfColor.fromInt(0xCCFFFFFF), fontSize: 12)),
                    ],
                  ),
                  pw.Text('CONTRAT DE FINANCEMENT',
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Référence
            pw.Text('Référence : ${demande.id}',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            pw.Text('Date d\'émission : ${fmtDate.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 12),

            // Montant
            pw.Center(
              child: pw.Column(children: [
                pw.Text('Montant approuvé',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text('${fmt.format(demande.montant)} FCFA',
                    style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF2E7D32))),
              ]),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 16),

            // Détails
            _pdfRow('Statut', 'Approuvé'),
            _pdfRow('Type de projet', demande.typeProjet),
            _pdfRow('Secteur', demande.secteur),
            _pdfRow('Pays', demande.pays),
            _pdfRow('Score d\'éligibilité', '${demande.scoreEligibilite.round()}/100'),
            _pdfRow('Alignement UEMOA', demande.alignementTaxonomie),
            _pdfRow('Date de soumission', fmtDate.format(demande.dateSoumission)),
            pw.SizedBox(height: 24),

            // Description
            if (demande.descriptionProjet.isNotEmpty) ...[
              pw.Text('Description du projet',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.SizedBox(height: 6),
              pw.Text(demande.descriptionProjet,
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
              pw.SizedBox(height: 24),
            ],

            pw.Spacer(),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Document généré par GreenAccess — ${fmtDate.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
              ),
            ),
          ],
        ),
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'contrat_${demande.id}.pdf');
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        children: [
          pw.Expanded(
              flex: 2,
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
          pw.Expanded(
              flex: 3,
              child: pw.Text(value,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRejete = demande.statut == StatutDemande.rejete;
    final isFinance = demande.statut == StatutDemande.finance;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(demande: demande),
          const SizedBox(height: 16),
          if (isRejete) _RejectionCard(motif: demande.commentaireRejet)
          else _TimelineCard(currentIndex: _currentStepIndex),
          const SizedBox(height: 16),
          _DetailsCard(demande: demande),

          // ── Actions disponibles quand approuvé ou financé ─────────────
          if (_isApprouve) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Télécharger le contrat PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _exportContratPdf(context),
            ),
            if (isFinance) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Voir les remboursements'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => context.push(
                  AppRoutes.remboursementsPath(demande.id),
                  extra: demande.montant,
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final DemandeFinancementModel demande;
  const _HeaderCard({required this.demande});

  Color _color() => switch (demande.statut) {
        StatutDemande.soumis => AppColors.info,
        StatutDemande.enExamen => AppColors.warning,
        StatutDemande.approuve => AppColors.success,
        StatutDemande.finance => AppColors.scoreExcellent,
        StatutDemande.rejete => AppColors.error,
        StatutDemande.brouillon => AppColors.textSecondary,
      };

  String _label() => switch (demande.statut) {
        StatutDemande.soumis => 'Soumis',
        StatutDemande.enExamen => 'En examen',
        StatutDemande.approuve => 'Approuvé',
        StatutDemande.finance => 'Financé',
        StatutDemande.rejete => 'Rejeté',
        StatutDemande.brouillon => 'Brouillon',
      };

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(Icons.description_outlined, color: color, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              '${demande.montant.toStringAsFixed(0)} FCFA',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(demande.typeProjet, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_label(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final int currentIndex;
  const _TimelineCard({required this.currentIndex});

  static const _labels = ['Soumis', 'En examen', 'Approuvé', 'Financé'];
  static const _icons = [
    Icons.send_outlined,
    Icons.search_outlined,
    Icons.check_circle_outline,
    Icons.payments_outlined,
  ];
  static const _descriptions = [
    'Votre demande a été reçue',
    'Un analyste étudie votre dossier',
    'Votre demande est approuvée',
    'Les fonds ont été débloqués',
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Avancement du dossier',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 16),
            ...List.generate(_labels.length, (i) {
              final done = i <= currentIndex;
              final active = i == currentIndex;
              return _TimelineStep(
                icon: _icons[i],
                label: _labels[i],
                description: _descriptions[i],
                done: done,
                active: active,
                isLast: i == _labels.length - 1,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String label, description;
  final bool done, active, isLast;
  const _TimelineStep({
    required this.icon, required this.label, required this.description,
    required this.done, required this.active, required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.primary : AppColors.divider;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 18, color: color),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: done ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        color: done ? AppColors.textPrimary : AppColors.textSecondary,
                      )),
                  Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectionCard extends StatelessWidget {
  final String? motif;
  const _RejectionCard({required this.motif});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.error.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cancel_outlined, color: AppColors.error),
                SizedBox(width: 8),
                Text('Demande rejetée', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              ],
            ),
            if (motif != null) ...[
              const SizedBox(height: 8),
              Text('Motif : $motif', style: const TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            const Text(
              'Améliorez votre dossier en complétant davantage de formations et en augmentant votre score Climat avant de soumettre une nouvelle demande.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final DemandeFinancementModel demande;
  const _DetailsCard({required this.demande});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Détails', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(height: 20),
            _Row('Secteur', demande.secteur),
            _Row('Pays', demande.pays),
            _Row('Score d\'éligibilité', '${demande.scoreEligibilite.round()}/100'),
            _Row('Alignement UEMOA', demande.alignementTaxonomie),
            _Row('Soumis le', _fmtDate(demande.dateSoumission)),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
}

class _Row extends StatelessWidget {
  final String k, v;
  const _Row(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(k, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(flex: 3, child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
