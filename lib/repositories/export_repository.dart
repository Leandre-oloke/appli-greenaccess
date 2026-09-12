import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/assurance_model.dart';
import '../models/badge_model.dart';
import '../models/course_model.dart';
import '../models/demande_financement_model.dart';
import '../models/notification_model.dart';
import '../models/paiement_model.dart';
import '../models/remboursement_model.dart';
import '../models/score_climat_model.dart';
import '../models/user_data_export_model.dart';
import '../models/user_model.dart';

/// Service d'export RGPD (J3.4, CDC §5 · T11) — réunit toutes les données
/// personnelles d'un compte à travers les collections/sous-collections
/// Firestore de chaque module métier, pour l'exercice du droit à la
/// portabilité des données. Ne touche jamais Firebase Storage : les fichiers
/// déjà uploadés (documents de contrat, photos de sinistre) sont exportés
/// sous forme d'URLs (voir `docsUrl`/`photoUrls` des modèles concernés), pas
/// re-téléchargés dans ce service.
///
/// Requêtes directes sur Firestore plutôt que délégation aux autres
/// repositories — la plupart de leurs méthodes de lecture pertinentes
/// (`fetchProgress`, `getContrats`…) sont déjà de simples `where('userId', …)`
/// sans logique additionnelle, et éviter la délégation évite de construire
/// des repositories complets (ex. `ScoreRepository` exige un `FirebaseFunctions`
/// qu'un export en lecture seule n'utilise pas).
class ExportRepository {
  final FirebaseFirestore _firestore;

  ExportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<UserDataExportModel> exportUserData(String userId) async {
    final profilDoc = await _firestore.collection('users').doc(userId).get();
    if (!profilDoc.exists) {
      throw Exception('Profil utilisateur introuvable pour l\'export.');
    }
    final profil = UserModel.fromFirestore(profilDoc.data()!, profilDoc.id);

    final results = await Future.wait([
      _fetchScores(userId),
      _fetchProgressions(userId),
      _fetchBadges(userId),
      _fetchNotificationsPersonnelles(userId),
      _fetchDemandes(userId),
      _fetchPaiements(userId),
      _fetchContrats(userId),
      _fetchSinistres(userId),
    ]);

    final demandes = results[4] as List<DemandeFinancementModel>;
    final remboursementsParDemande = await _fetchRemboursements(demandes);

    return UserDataExportModel(
      profil: profil,
      scores: results[0] as List<ScoreClimatModel>,
      progressions: results[1] as List<CourseProgress>,
      badges: results[2] as List<BadgeModel>,
      notificationsPersonnelles: results[3] as List<NotificationModel>,
      demandes: demandes,
      remboursementsParDemande: remboursementsParDemande,
      paiements: results[5] as List<PaiementModel>,
      contrats: results[6] as List<ContratAssuranceModel>,
      sinistres: results[7] as List<SinistreModel>,
    );
  }

  Future<List<ScoreClimatModel>> _fetchScores(String userId) async {
    final snapshot =
        await _firestore.collection('scores_climat').where('userId', isEqualTo: userId).get();
    return snapshot.docs.map((d) => ScoreClimatModel.fromFirestore(d.data(), d.id)).toList();
  }

  Future<List<CourseProgress>> _fetchProgressions(String userId) async {
    final snapshot =
        await _firestore.collection('users').doc(userId).collection('progress').get();
    return snapshot.docs.map((d) => CourseProgress.fromFirestore(d.data(), d.id)).toList();
  }

  Future<List<BadgeModel>> _fetchBadges(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).collection('badges').get();
    return snapshot.docs.map((d) => BadgeModel.fromFirestore(d.data(), d.id)).toList();
  }

  Future<List<NotificationModel>> _fetchNotificationsPersonnelles(String userId) async {
    final snapshot =
        await _firestore.collection('users').doc(userId).collection('notifications').get();
    return snapshot.docs.map((d) => NotificationModel.fromFirestore(d.data(), d.id)).toList();
  }

  Future<List<DemandeFinancementModel>> _fetchDemandes(String userId) async {
    final snapshot = await _firestore
        .collection('demandes_financement')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs
        .map((d) => DemandeFinancementModel.fromFirestore(d.data(), d.id))
        .toList();
  }

  /// Une sous-collection par demande — pas de champ `userId` propre à ce
  /// niveau (voir `firestore.rules` : l'appartenance se déduit du document
  /// `demandes_financement` parent), donc récupérée après coup pour chaque
  /// demande déjà identifiée comme appartenant à l'utilisateur.
  Future<Map<String, List<RemboursementModel>>> _fetchRemboursements(
    List<DemandeFinancementModel> demandes,
  ) async {
    final entries = await Future.wait(demandes.map((demande) async {
      final snapshot = await _firestore
          .collection('demandes_financement')
          .doc(demande.id)
          .collection('remboursements')
          .get();
      final remboursements =
          snapshot.docs.map((d) => RemboursementModel.fromFirestore(d.data(), d.id)).toList();
      return MapEntry(demande.id, remboursements);
    }));
    return Map.fromEntries(entries);
  }

  Future<List<PaiementModel>> _fetchPaiements(String userId) async {
    final snapshot =
        await _firestore.collection('paiements').where('userId', isEqualTo: userId).get();
    return snapshot.docs.map((d) => PaiementModel.fromFirestore(d.data(), d.id)).toList();
  }

  Future<List<ContratAssuranceModel>> _fetchContrats(String userId) async {
    final snapshot = await _firestore
        .collection('contrats_assurance')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs.map((d) => ContratAssuranceModel.fromFirestore(d.data(), d.id)).toList();
  }

  Future<List<SinistreModel>> _fetchSinistres(String userId) async {
    final snapshot =
        await _firestore.collection('sinistres').where('userId', isEqualTo: userId).get();
    return snapshot.docs.map((d) => SinistreModel.fromFirestore(d.data(), d.id)).toList();
  }
}
