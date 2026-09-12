// Tests unitaires de ExportRepository (J3.4) — service d'export RGPD :
// vérifie que exportUserData() réunit bien les données personnelles d'un
// utilisateur à travers toutes les collections/sous-collections concernées,
// et surtout qu'il ne renvoie JAMAIS les données d'un autre utilisateur
// (l'export RGPD est un cas d'usage où une fuite entre comptes serait grave).
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:greenaccess/repositories/export_repository.dart';

const _userId = 'alice';
const _autreUserId = 'bob';

void main() {
  late FakeFirebaseFirestore db;
  late ExportRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = ExportRepository(firestore: db);

    // ── Profil ────────────────────────────────────────────────────────────
    await db.collection('users').doc(_userId).set({
      'nom': 'Alice Dupont',
      'email': 'alice@greenaccess.test',
      'telephone': '+221700000000',
      'pays': 'Sénégal',
      'region': 'Dakar',
      'secteur': 'Agriculture',
      'date_inscription': Timestamp.fromDate(DateTime(2024, 1, 10)),
      'profil_complet': true,
      'role': 'user',
    });
    await db.collection('users').doc(_autreUserId).set({
      'nom': 'Bob Martin',
      'email': 'bob@greenaccess.test',
      'telephone': '',
      'pays': 'Bénin',
      'region': 'Cotonou',
      'secteur': 'Pêche durable',
      'date_inscription': Timestamp.fromDate(DateTime(2024, 2, 1)),
      'profil_complet': true,
      'role': 'user',
    });

    // ── Scores climat ────────────────────────────────────────────────────
    await db.collection('scores_climat').add({
      'userId': _userId,
      'score_total': 72.0,
      'criteres': {'activite': 80, 'uemoa': 70, 'co2': 60, 'certif': 50, 'resilience': 90, 'bonus_formation': 5},
      'suggestions': ['Réduire le CO2'],
      'date_calcul': Timestamp.fromDate(DateTime(2025, 3, 1)),
      'version_algo': 'v1-cloud',
    });
    await db.collection('scores_climat').add({
      'userId': _autreUserId,
      'score_total': 20.0,
      'criteres': {'activite': 10, 'uemoa': 10, 'co2': 10, 'certif': 10, 'resilience': 10, 'bonus_formation': 0},
      'suggestions': [],
      'date_calcul': Timestamp.fromDate(DateTime(2025, 3, 1)),
      'version_algo': 'v1-cloud',
    });

    // ── Progression / badges / notifications (sous users/{uid}) ─────────────
    await db.collection('users').doc(_userId).collection('progress').doc('c1').set({
      'statut': 'TERMINE',
      'score_quiz': 90,
      'points_xp_gagnés': 40,
      'badge_declenche': true,
    });
    await db.collection('users').doc(_userId).collection('badges').doc('b1').set({
      'nom': 'Cours complété',
      'description': 'Quiz réussi à 90%.',
      'image_url': '',
      'type': 'formation',
      'date_obtention': Timestamp.fromDate(DateTime(2025, 3, 2)),
    });
    await db.collection('users').doc(_userId).collection('notifications').doc('n1').set({
      'titre': 'Contrat expirant',
      'message': 'Votre contrat expire bientôt.',
      'type': 'warning',
      'createdAt': Timestamp.fromDate(DateTime(2025, 4, 1)),
    });
    // Décoy sous un autre utilisateur, ne doit jamais apparaître.
    await db.collection('users').doc(_autreUserId).collection('progress').doc('c9').set({
      'statut': 'TERMINE',
      'score_quiz': 100,
      'points_xp_gagnés': 999,
      'badge_declenche': true,
    });

    // ── Demandes de financement + remboursements ────────────────────────────
    final demandeRef = await db.collection('demandes_financement').add({
      'userId': _userId,
      'date_soumission': Timestamp.fromDate(DateTime(2025, 2, 1)),
      'montant': 1000000.0,
      'type_projet': 'Maraîchage solaire',
      'secteur': 'Agriculture',
      'pays': 'Sénégal',
      'description_projet': 'Extension exploitation.',
      'statut': 'approuve',
      'score_eligibilite': 72.0,
      'docs_url': <String>[],
      'alignement_taxonomie': 'Conforme',
    });
    await demandeRef.collection('remboursements').add({
      'demandeId': demandeRef.id,
      'numero_echeance': 1,
      'date_echeance': Timestamp.fromDate(DateTime(2025, 3, 1)),
      'montant': 100000.0,
      'paye': true,
      'date_paiement': Timestamp.fromDate(DateTime(2025, 3, 1)),
    });
    await db.collection('demandes_financement').add({
      'userId': _autreUserId,
      'date_soumission': Timestamp.fromDate(DateTime(2025, 2, 1)),
      'montant': 500000.0,
      'type_projet': 'x',
      'secteur': 'Pêche durable',
      'pays': 'Bénin',
      'description_projet': 'x',
      'statut': 'brouillon',
      'score_eligibilite': 20.0,
      'docs_url': <String>[],
      'alignement_taxonomie': 'NonConforme',
    });

    // ── Paiements ────────────────────────────────────────────────────────
    await db.collection('paiements').add({
      'demandeId': demandeRef.id,
      'echeanceId': 'e1',
      'userId': _userId,
      'montant': 100000.0,
      'operateur': 'wave',
      'statut': 'confirme',
      'reference': 'GA-ABC12345',
      'date_creation': Timestamp.fromDate(DateTime(2025, 3, 1)),
      'date_confirmation': Timestamp.fromDate(DateTime(2025, 3, 1)),
    });

    // ── Contrats d'assurance + sinistres ─────────────────────────────────
    final contratRef = await db.collection('contrats_assurance').add({
      'userId': _userId,
      'produit_id': 'prod1',
      'statut': 'actif',
      'assureur_id': 'ASS_01',
      'date_debut': Timestamp.fromDate(DateTime(2024, 6, 1)),
      'prime_mensuelle': 8000.0,
      'zone_risque': 'Vallée du Fleuve',
      'docs_url': <String>[],
    });
    await db.collection('sinistres').add({
      'userId': _userId,
      'contratId': contratRef.id,
      'typeSinistre': 'secheresse',
      'description': 'Sécheresse sur la parcelle nord.',
      'dateSinistre': Timestamp.fromDate(DateTime(2025, 5, 1)),
      'photoUrls': <String>[],
      'statut': 'en_attente',
      'createdAt': Timestamp.fromDate(DateTime(2025, 5, 1)),
    });
    await db.collection('sinistres').add({
      'userId': _autreUserId,
      'contratId': 'other',
      'typeSinistre': 'inondation',
      'description': 'x',
      'dateSinistre': Timestamp.fromDate(DateTime(2025, 5, 1)),
      'photoUrls': <String>[],
      'statut': 'en_attente',
      'createdAt': Timestamp.fromDate(DateTime(2025, 5, 1)),
    });
  });

  test('réunit toutes les données personnelles d\'un utilisateur', () async {
    final export = await repo.exportUserData(_userId);

    expect(export.profil.nom, 'Alice Dupont');
    expect(export.scores, hasLength(1));
    expect(export.scores.first.scoreTotal, 72.0);
    expect(export.progressions, hasLength(1));
    expect(export.progressions.first.courseId, 'c1');
    expect(export.badges, hasLength(1));
    expect(export.badges.first.nom, 'Cours complété');
    expect(export.notificationsPersonnelles, hasLength(1));
    expect(export.demandes, hasLength(1));
    expect(export.demandes.first.montant, 1000000.0);
    expect(export.remboursementsParDemande[export.demandes.first.id], hasLength(1));
    expect(export.paiements, hasLength(1));
    expect(export.contrats, hasLength(1));
    expect(export.sinistres, hasLength(1));
    expect(export.sinistres.first.typeSinistre, 'secheresse');
  });

  test('n\'inclut jamais les données d\'un autre utilisateur', () async {
    final export = await repo.exportUserData(_userId);

    expect(export.scores.every((s) => s.userId == _userId), isTrue);
    expect(export.demandes.every((d) => d.userId == _userId), isTrue);
    expect(export.paiements.every((p) => p.userId == _userId), isTrue);
    expect(export.contrats.every((c) => c.userId == _userId), isTrue);
    expect(export.sinistres.every((s) => s.userId == _userId), isTrue);
    // Le badge/progression "décoy" de bob (999 XP / score 100) ne doit
    // apparaître nulle part dans l'export d'alice.
    expect(export.progressions.any((p) => p.pointsXpGagnes == 999), isFalse);
  });

  test('lève une exception explicite si le profil utilisateur est introuvable', () async {
    expect(() => repo.exportUserData('inconnu'), throwsA(isA<Exception>()));
  });
}
