import 'assurance_model.dart';
import 'badge_model.dart';
import 'course_model.dart';
import 'demande_financement_model.dart';
import 'notification_model.dart';
import 'paiement_model.dart';
import 'remboursement_model.dart';
import 'score_climat_model.dart';
import 'user_model.dart';

/// Regroupe toutes les données personnelles d'un utilisateur, collectées par
/// [ExportRepository.exportUserData] (J3.4), pour être converties en PDF et
/// CSV par les fonctions de `lib/utils/export_formatters.dart` (J3.5) — droit
/// à la portabilité des données, CDC §5 · T11.
class UserDataExportModel {
  final UserModel profil;
  final List<ScoreClimatModel> scores;
  final List<CourseProgress> progressions;
  final List<BadgeModel> badges;
  final List<NotificationModel> notificationsPersonnelles;
  final List<DemandeFinancementModel> demandes;

  /// Échéances de remboursement, indexées par id de demande — chaque demande
  /// n'a pas d'échéancier avant d'être approuvée/financée, la liste peut donc
  /// être vide pour certaines entrées de [demandes].
  final Map<String, List<RemboursementModel>> remboursementsParDemande;
  final List<PaiementModel> paiements;
  final List<ContratAssuranceModel> contrats;
  final List<SinistreModel> sinistres;

  const UserDataExportModel({
    required this.profil,
    required this.scores,
    required this.progressions,
    required this.badges,
    required this.notificationsPersonnelles,
    required this.demandes,
    required this.remboursementsParDemande,
    required this.paiements,
    required this.contrats,
    required this.sinistres,
  });
}
