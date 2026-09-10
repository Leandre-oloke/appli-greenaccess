import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../models/demande_financement_model.dart';
import '../../viewmodels/admin_viewmodel.dart';

class AdminDemandesScreen extends ConsumerStatefulWidget {
  const AdminDemandesScreen({super.key});
  @override
  ConsumerState<AdminDemandesScreen> createState() => _AdminDemandesScreenState();
}

class _AdminDemandesScreenState extends ConsumerState<AdminDemandesScreen> {
  StatutDemande? _filtre;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminViewModelProvider.notifier).loadDemandes();
    });
  }

  Future<void> _exportPdf(List<DemandeFinancementModel> demandes) async {
    final fmt = NumberFormat('#,##0', 'fr_FR');
    final fmtDate = DateFormat('dd/MM/yyyy');
    final now = fmtDate.format(DateTime.now());

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('GreenAccess — Export Demandes de financement',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromInt(0xFF2E7D32))),
              pw.Text('Généré le $now', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.8),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1),
            },
            children: [
              // En-tête
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E7D32)),
                children: [
                  _cell('Type de projet', isHeader: true),
                  _cell('Montant (FCFA)', isHeader: true),
                  _cell('Statut', isHeader: true),
                  _cell('Secteur / Pays', isHeader: true),
                  _cell('Score ESG', isHeader: true),
                  _cell('Soumis le', isHeader: true),
                ],
              ),
              // Lignes
              ...demandes.asMap().entries.map((e) {
                final d = e.value;
                final even = e.key.isEven;
                return pw.TableRow(
                  decoration: even ? const pw.BoxDecoration(color: PdfColors.grey50) : null,
                  children: [
                    _cell(d.typeProjet),
                    _cell(fmt.format(d.montant)),
                    _cell(_statutLabel(d.statut)),
                    _cell('${d.secteur} · ${d.pays}'),
                    _cell('${d.scoreEligibilite.round()}/100'),
                    _cell(fmtDate.format(d.dateSoumission)),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Total : ${demandes.length} demande(s)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'demandes_financement_$now.pdf'.replaceAll('/', '-'),
    );
  }

  static pw.Widget _cell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminViewModelProvider);

    ref.listen(adminViewModelProvider, (_, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: AppColors.success),
        );
        ref.read(adminViewModelProvider.notifier).clearMessages();
      }
    });

    final demandes = _filtre == null
        ? state.demandes
        : state.demandes.where((d) => d.statut == _filtre).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Demandes de financement (${state.demandes.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exporter en PDF',
            onPressed: demandes.isEmpty ? null : () => _exportPdf(demandes),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _FilterChip(label: 'Tous', selected: _filtre == null, onTap: () => setState(() => _filtre = null)),
                ...StatutDemande.values.map((s) => _FilterChip(
                  label: _statutLabel(s),
                  selected: _filtre == s,
                  onTap: () => setState(() => _filtre = s),
                  color: _statutColor(s),
                )),
              ],
            ),
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (state.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppColors.error.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.error!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.read(adminViewModelProvider.notifier).loadDemandes(),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: demandes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_outlined, size: 64, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              const Text('Aucune demande', style: TextStyle(color: AppColors.textSecondary)),
                              if (state.error == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Les demandes soumises par les utilisateurs\napparaîtront ici.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: demandes.length,
                          itemBuilder: (context, i) => _DemandeCard(
                            demande: demandes[i],
                            onApprouver: () => ref.read(adminViewModelProvider.notifier).approuverDemande(demandes[i].id),
                            onRejeter: () => _showRejetDialog(context, demandes[i].id),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  void _showRejetDialog(BuildContext context, String id) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motif de rejet'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Expliquez pourquoi cette demande est rejetée…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(adminViewModelProvider.notifier).rejeterDemande(id, ctrl.text.trim());
            },
            child: const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static String _statutLabel(StatutDemande s) => switch (s) {
    StatutDemande.brouillon  => 'Brouillon',
    StatutDemande.soumis     => 'Soumis',
    StatutDemande.enExamen   => 'En examen',
    StatutDemande.approuve   => 'Approuvé',
    StatutDemande.rejete     => 'Rejeté',
    StatutDemande.finance    => 'Financé',
  };

  static Color _statutColor(StatutDemande s) => switch (s) {
    StatutDemande.brouillon  => Colors.grey,
    StatutDemande.soumis     => AppColors.warning,
    StatutDemande.enExamen   => AppColors.info,
    StatutDemande.approuve   => AppColors.success,
    StatutDemande.rejete     => AppColors.error,
    StatutDemande.finance    => AppColors.primary,
  };
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : Colors.white54),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.primary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            )),
      ),
    );
  }
}

class _DemandeCard extends StatelessWidget {
  final DemandeFinancementModel demande;
  final VoidCallback onApprouver;
  final VoidCallback onRejeter;
  const _DemandeCard({required this.demande, required this.onApprouver, required this.onRejeter});

  static const _colors = {
    StatutDemande.brouillon: Colors.grey,
    StatutDemande.soumis:    AppColors.warning,
    StatutDemande.enExamen:  AppColors.info,
    StatutDemande.approuve:  AppColors.success,
    StatutDemande.rejete:    AppColors.error,
    StatutDemande.finance:   AppColors.primary,
  };

  static const _labels = {
    StatutDemande.brouillon: 'Brouillon',
    StatutDemande.soumis:    'Soumis',
    StatutDemande.enExamen:  'En examen',
    StatutDemande.approuve:  'Approuvé',
    StatutDemande.rejete:    'Rejeté',
    StatutDemande.finance:   'Financé',
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[demande.statut] ?? Colors.grey;
    final fmt = NumberFormat('#,##0', 'fr_FR');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(demande.typeProjet, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(_labels[demande.statut] ?? '', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('${demande.secteur} · ${demande.pays}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Text('Montant : ${fmt.format(demande.montant)} FCFA', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Score ESG : ${demande.scoreEligibilite.toStringAsFixed(0)}/100 · ${demande.alignementTaxonomie}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('Soumis le ${DateFormat('dd/MM/yyyy').format(demande.dateSoumission)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            if (demande.commentaireRejet != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Rejet : ${demande.commentaireRejet}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error)),
              ),
            if (demande.statut == StatutDemande.soumis || demande.statut == StatutDemande.enExamen) ...[
              const Divider(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRejeter,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprouver,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approuver'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
