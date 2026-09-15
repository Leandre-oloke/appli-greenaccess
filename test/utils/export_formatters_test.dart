// Tests unitaires des formateurs d'export RGPD (J3.5) — fonctions pures
// (aucun accès Firestore), vérifient le contenu produit à partir d'un
// UserDataExportModel fixe.
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/models/assurance_model.dart';
import 'package:greenaccess/models/badge_model.dart';
import 'package:greenaccess/models/course_model.dart';
import 'package:greenaccess/models/demande_financement_model.dart';
import 'package:greenaccess/models/notification_model.dart';
import 'package:greenaccess/models/paiement_model.dart';
import 'package:greenaccess/models/remboursement_model.dart';
import 'package:greenaccess/models/score_climat_model.dart';
import 'package:greenaccess/models/user_data_export_model.dart';
import 'package:greenaccess/models/user_model.dart';
import 'package:greenaccess/utils/export_formatters.dart';

UserModel _profil() => UserModel(
      id: 'alice',
      nom: 'Alice Dupont',
      email: 'alice@greenaccess.test',
      telephone: '+221700000000',
      pays: 'Sénégal',
      region: 'Dakar',
      secteur: 'Agriculture',
      dateInscription: DateTime(2024, 1, 10),
      profilComplet: true,
      role: UserRole.user,
    );

UserDataExportModel _fixture({bool avecDonnees = true}) {
  if (!avecDonnees) {
    return UserDataExportModel(
      profil: _profil(),
      scores: const [],
      progressions: const [],
      badges: const [],
      notificationsPersonnelles: const [],
      demandes: const [],
      remboursementsParDemande: const {},
      paiements: const [],
      contrats: const [],
      sinistres: const [],
    );
  }

  final demande = DemandeFinancementModel(
    id: 'd1',
    userId: 'alice',
    dateSoumission: DateTime(2025, 2, 1),
    montant: 1000000,
    typeProjet: 'Maraîchage solaire',
    secteur: 'Agriculture',
    pays: 'Sénégal',
    descriptionProjet: 'Extension exploitation.',
    statut: StatutDemande.approuve,
    scoreEligibilite: 72,
    docsUrl: const [],
    alignementTaxonomie: 'Conforme',
  );

  return UserDataExportModel(
    profil: _profil(),
    scores: [
      ScoreClimatModel(
        id: 's1',
        userId: 'alice',
        scoreTotal: 72,
        criteres: const ScoreCriteres(
          scoreActivite: 80,
          scoreUemoa: 70,
          scoreCo2: 60,
          scoreCertif: 50,
          scoreResilience: 90,
          bonusFormation: 5,
        ),
        niveau: NiveauScore.bon,
        suggestions: const ['Réduire le CO2'],
        dateCalcul: DateTime(2025, 3, 1),
        versionAlgo: 'v1-cloud',
      ),
    ],
    progressions: const [
      CourseProgress(
        courseId: 'c1',
        statut: 'TERMINE',
        scoreQuiz: 90,
        pointsXpGagnes: 40,
        badgeDeclenche: true,
      ),
    ],
    badges: [
      BadgeModel(
        id: 'b1',
        nom: 'Cours complété',
        description: 'Quiz réussi à 90%.',
        imageUrl: '',
        type: 'formation',
        dateObtention: DateTime(2025, 3, 2),
      ),
    ],
    notificationsPersonnelles: [
      NotificationModel(
        id: 'n1',
        titre: 'Contrat expirant',
        message: 'Votre contrat expire bientôt.',
        type: NotificationType.warning,
        createdAt: DateTime(2025, 4, 1),
      ),
    ],
    demandes: [demande],
    remboursementsParDemande: {
      'd1': [
        RemboursementModel(
          id: 'e1',
          demandeId: 'd1',
          numeroEcheance: 1,
          dateEcheance: DateTime(2025, 3, 1),
          montant: 100000,
          paye: true,
        ),
      ],
    },
    paiements: [
      PaiementModel(
        id: 'p1',
        demandeId: 'd1',
        echeanceId: 'e1',
        userId: 'alice',
        montant: 100000,
        operateur: OperateurMobileMoney.wave,
        statut: StatutPaiement.confirme,
        reference: 'GA-ABC12345',
        dateCreation: DateTime(2025, 3, 1),
      ),
    ],
    contrats: [
      ContratAssuranceModel(
        id: 'c1',
        userId: 'alice',
        produitId: 'prod1',
        statut: StatutContrat.actif,
        assureurId: 'ASS_01',
        dateDebut: DateTime(2024, 6, 1),
        primeMensuelle: 8000,
        zoneRisque: 'Vallée du Fleuve',
      ),
    ],
    sinistres: [
      SinistreModel(
        id: 'sin1',
        userId: 'alice',
        contratId: 'c1',
        typeSinistre: 'secheresse',
        description: 'Sécheresse sur la parcelle nord.',
        dateSinistre: DateTime(2025, 5, 1),
        statut: 'en_attente',
      ),
    ],
  );
}

void main() {
  group('buildExportCsv', () {
    test('contient une section par catégorie avec les valeurs attendues', () {
      final csv = buildExportCsv(_fixture());
      final rows = const CsvToListConverter().convert(csv); // eol par défaut : \r\n, comme ListToCsvConverter

      List<dynamic>? findRow(String firstCell) =>
          rows.firstWhere((r) => r.isNotEmpty && r.first == firstCell, orElse: () => []);

      expect(findRow('Nom'), ['Nom', 'Alice Dupont']);
      expect(findRow('Email'), ['Email', 'alice@greenaccess.test']);
      expect(csv, contains('=== Scores climat ==='));
      expect(csv, contains('=== Demandes de financement ==='));
      expect(csv, contains('Maraîchage solaire'));
      expect(csv, contains('=== Échéances de remboursement ==='));
      expect(csv, contains('GA-ABC12345'));
      expect(csv, contains("=== Contrats d'assurance ==="));
      expect(csv, contains('Vallée du Fleuve'));
      expect(csv, contains('=== Sinistres déclarés ==='));
      expect(csv, contains('secheresse'));
    });

    test('reste un CSV valide (en-têtes seuls) quand l\'utilisateur n\'a aucune donnée',
        () {
      final csv = buildExportCsv(_fixture(avecDonnees: false));
      final rows = const CsvToListConverter().convert(csv);

      expect(csv, contains('=== Scores climat ==='));
      expect(csv, isNot(contains('null')));
      expect(rows, isNotEmpty);
    });
  });

  group('buildExportPdf', () {
    test('produit un document PDF non vide', () async {
      final bytes = await buildExportPdf(_fixture());

      expect(bytes, isNotEmpty);
      // En-tête standard d'un fichier PDF valide : "%PDF-".
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('ne plante pas quand l\'utilisateur n\'a aucune donnée (sections vides)', () async {
      final bytes = await buildExportPdf(_fixture(avecDonnees: false));

      expect(bytes, isNotEmpty);
    });
  });
}
