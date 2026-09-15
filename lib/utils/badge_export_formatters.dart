import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/badge_model.dart';

/// Export des badges de l'utilisateur (J5.16, CDC §5) — fonctions pures,
/// testables sans Firestore, même esprit que `export_formatters.dart` (J3.5)
/// pour l'export RGPD. Seuls les badges obtenus sont exportés (les badges
/// verrouillés n'ont pas de date d'obtention à emporter).
final _dateFmt = DateFormat('dd/MM/yyyy');

/// ── JSON ─────────────────────────────────────────────────────────────────

/// `openbadge_url` (quand renseigné, J5.10-J5.12) donne accès à l'assertion
/// OpenBadge v2 certifiée du badge — c'est la preuve vérifiable hors de
/// l'app que ce format permet d'emporter.
String buildBadgesJson(List<BadgeModel> badges) {
  final obtenus = badges.where((b) => b.isObtenu).toList();
  final data = {
    'export': 'GreenAccess — Badges',
    'genere_le': DateTime.now().toIso8601String(),
    'badges': obtenus
        .map((b) => {
              'id': b.id,
              'nom': b.nom,
              'description': b.description,
              'type': b.type,
              'date_obtention': b.dateObtention?.toIso8601String(),
              'openbadge_url': b.openbadgeUrl,
            })
        .toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}

/// ── PDF ──────────────────────────────────────────────────────────────────

Future<Uint8List> buildBadgesPdf(List<BadgeModel> badges) async {
  final obtenus = badges.where((b) => b.isObtenu).toList();
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
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
                      fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text('Mes badges certifiés',
                  style: pw.TextStyle(fontSize: 13, color: PdfColor.fromInt(0xCCFFFFFF))),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Généré le ${_dateFmt.format(DateTime.now())} — ${obtenus.length} badge(s) obtenu(s)',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        if (obtenus.isEmpty)
          pw.Text('Aucun badge obtenu pour le moment.',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600))
        else
          ...obtenus.map(_pdfBadgeCard),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _pdfBadgeCard(BadgeModel b) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(b.nom, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Text(b.description, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Type : ${b.type}   •   Obtenu le '
          '${b.dateObtention != null ? _dateFmt.format(b.dateObtention!) : '-'}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        if (b.openbadgeUrl != null) ...[
          pw.SizedBox(height: 3),
          pw.Text('Assertion OpenBadge : ${b.openbadgeUrl}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue700)),
        ],
      ],
    ),
  );
}
