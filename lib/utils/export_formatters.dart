import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/user_data_export_model.dart';

/// Génère les fichiers PDF (lisible) et CSV (réutilisable) de l'export RGPD
/// (J3.5, CDC §5 · T11) à partir des données collectées par
/// `ExportRepository.exportUserData` (J3.4). Fonctions pures — aucun accès
/// Firestore ici, testables sans backend.
final _dateFmt = DateFormat('dd/MM/yyyy');

String _fmtDate(DateTime? d) => d == null ? '' : _dateFmt.format(d);

/// ── CSV ──────────────────────────────────────────────────────────────────

String buildExportCsv(UserDataExportModel data) {
  final rows = <List<dynamic>>[
    ['Export des données personnelles — GreenAccess'],
    ['Généré le', _dateFmt.format(DateTime.now())],
    [],
    ['=== Profil ==='],
    ['Champ', 'Valeur'],
    ['Nom', data.profil.nom],
    ['Email', data.profil.email],
    ['Téléphone', data.profil.telephone],
    ['Pays', data.profil.pays],
    ['Région', data.profil.region],
    ['Secteur', data.profil.secteur],
    ["Date d'inscription", _fmtDate(data.profil.dateInscription)],
    ['Rôle', data.profil.role.name],
    [],
    ['=== Scores climat ==='],
    [
      'Date de calcul',
      'Score total',
      'Niveau',
      'Score activité',
      'Score UEMOA',
      'Score CO2',
      'Score certifications',
      'Score résilience',
      'Bonus formation',
    ],
    ...data.scores.map((s) => [
          _fmtDate(s.dateCalcul),
          s.scoreTotal,
          s.niveau.name,
          s.criteres.scoreActivite,
          s.criteres.scoreUemoa,
          s.criteres.scoreCo2,
          s.criteres.scoreCertif,
          s.criteres.scoreResilience,
          s.criteres.bonusFormation,
        ]),
    [],
    ['=== Progression formation ==='],
    ['Cours (id)', 'Statut', 'Score quiz', 'Points XP gagnés', 'Date de complétion'],
    ...data.progressions.map((p) => [
          p.courseId,
          p.statut,
          p.scoreQuiz,
          p.pointsXpGagnes,
          _fmtDate(p.dateCompletion),
        ]),
    [],
    ['=== Badges ==='],
    ['Nom', 'Description', 'Type', "Date d'obtention"],
    ...data.badges.map((b) => [b.nom, b.description, b.type, _fmtDate(b.dateObtention)]),
    [],
    ['=== Notifications personnelles ==='],
    ['Date', 'Titre', 'Message', 'Type'],
    ...data.notificationsPersonnelles
        .map((n) => [_fmtDate(n.createdAt), n.titre, n.message, n.type.name]),
    [],
    ['=== Demandes de financement ==='],
    [
      'Date de soumission',
      'Montant',
      'Type de projet',
      'Secteur',
      'Pays',
      'Statut',
      'Score éligibilité',
    ],
    ...data.demandes.map((d) => [
          _fmtDate(d.dateSoumission),
          d.montant,
          d.typeProjet,
          d.secteur,
          d.pays,
          d.statut.name,
          d.scoreEligibilite,
        ]),
    [],
    ['=== Échéances de remboursement ==='],
    ['Demande (id)', 'Échéance n°', 'Date', 'Montant', 'Payé'],
    ...data.remboursementsParDemande.entries.expand(
      (entry) => entry.value.map((r) => [
            entry.key,
            r.numeroEcheance,
            _fmtDate(r.dateEcheance),
            r.montant,
            r.paye ? 'Oui' : 'Non',
          ]),
    ),
    [],
    ['=== Paiements ==='],
    ['Date', 'Montant', 'Opérateur', 'Statut', 'Référence'],
    ...data.paiements.map((p) => [
          _fmtDate(p.dateCreation),
          p.montant,
          p.operateur.name,
          p.statut.name,
          p.reference,
        ]),
    [],
    ["=== Contrats d'assurance ==="],
    ['Date de début', 'Produit (id)', 'Statut', 'Prime mensuelle', 'Zone de risque'],
    ...data.contrats.map((c) => [
          _fmtDate(c.dateDebut),
          c.produitId,
          c.statut.name,
          c.primeMensuelle,
          c.zoneRisque,
        ]),
    [],
    ['=== Sinistres déclarés ==='],
    ['Date', 'Type', 'Description', 'Statut'],
    ...data.sinistres
        .map((s) => [_fmtDate(s.dateSinistre), s.typeSinistre, s.description, s.statut]),
  ];

  return const ListToCsvConverter().convert(rows);
}

/// ── PDF ──────────────────────────────────────────────────────────────────

Future<Uint8List> buildExportPdf(UserDataExportModel data) async {
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
              pw.Text('Export de vos données personnelles',
                  style: pw.TextStyle(fontSize: 13, color: PdfColor.fromInt(0xCCFFFFFF))),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Généré le ${_dateFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 20),

        _pdfSection('Profil', [
          ['Nom', data.profil.nom],
          ['Email', data.profil.email],
          ['Téléphone', data.profil.telephone],
          ['Pays', data.profil.pays],
          ['Région', data.profil.region],
          ['Secteur', data.profil.secteur],
          ["Date d'inscription", _fmtDate(data.profil.dateInscription)],
        ]),

        _pdfTableSection(
          'Scores climat',
          ['Date', 'Score', 'Niveau'],
          data.scores
              .map((s) => [
                    _fmtDate(s.dateCalcul),
                    '${s.scoreTotal.toStringAsFixed(0)}/100',
                    s.niveau.name,
                  ])
              .toList(),
        ),

        _pdfTableSection(
          'Progression formation',
          ['Cours', 'Statut', 'Score quiz', 'XP gagnés'],
          data.progressions
              .map((p) => [p.courseId, p.statut, '${p.scoreQuiz}%', '${p.pointsXpGagnes}'])
              .toList(),
        ),

        _pdfTableSection(
          'Badges',
          ['Nom', 'Type', 'Obtenu le'],
          data.badges.map((b) => [b.nom, b.type, _fmtDate(b.dateObtention)]).toList(),
        ),

        _pdfTableSection(
          'Demandes de financement',
          ['Date', 'Montant', 'Secteur', 'Statut'],
          data.demandes
              .map((d) => [
                    _fmtDate(d.dateSoumission),
                    '${d.montant.toStringAsFixed(0)} FCFA',
                    d.secteur,
                    d.statut.name,
                  ])
              .toList(),
        ),

        _pdfTableSection(
          'Paiements',
          ['Date', 'Montant', 'Opérateur', 'Statut'],
          data.paiements
              .map((p) => [
                    _fmtDate(p.dateCreation),
                    '${p.montant.toStringAsFixed(0)} FCFA',
                    p.operateur.name,
                    p.statut.name,
                  ])
              .toList(),
        ),

        _pdfTableSection(
          "Contrats d'assurance",
          ['Début', 'Statut', 'Prime mensuelle', 'Zone'],
          data.contrats
              .map((c) => [
                    _fmtDate(c.dateDebut),
                    c.statut.name,
                    '${c.primeMensuelle.toStringAsFixed(0)} FCFA',
                    c.zoneRisque,
                  ])
              .toList(),
        ),

        _pdfTableSection(
          'Sinistres déclarés',
          ['Date', 'Type', 'Statut'],
          data.sinistres.map((s) => [_fmtDate(s.dateSinistre), s.typeSinistre, s.statut]).toList(),
        ),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _pdfSection(String title, List<List<String>> rows) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        ...rows.map((r) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(children: [
                pw.SizedBox(width: 140, child: pw.Text(r[0], style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
                pw.Expanded(child: pw.Text(r[1], style: const pw.TextStyle(fontSize: 10))),
              ]),
            )),
      ],
    ),
  );
}

/// Section sous forme de tableau — pour les listes potentiellement vides (le
/// cas normal pour un utilisateur qui n'a pas encore de demande/contrat/etc.),
/// affiche « Aucune donnée » plutôt qu'un tableau sans lignes.
pw.Widget _pdfTableSection(String title, List<String> headers, List<List<String>> rows) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 16),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        if (rows.isEmpty)
          pw.Text('Aucune donnée', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellHeight: 20,
            cellAlignments: {for (var i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft},
          ),
      ],
    ),
  );
}
