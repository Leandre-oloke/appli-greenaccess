/// Identifiant du badge "Assuré Climat" (souscription assurance, J5.13),
/// stocké dans `users/{id}/badges/{id}` — voir CoursRepository.triggerAssureClimatBadge.
const String badgeIdAssureClimat = 'assure_climat';

/// Règle 4.1 (CDC §4.1) — incitation croisée entre modules : un utilisateur
/// titulaire du badge "Assuré Climat" voit son score d'éligibilité au
/// financement bonifié de +10 pts, plafonné à 100. Fonction pure, testable
/// indépendamment de Riverpod/Firestore (même esprit que
/// `assurance_viewmodel.dart._remiseScoreClimat` pour la règle symétrique
/// côté prime d'assurance, J4.11-J4.12).
double scoreEligibiliteFinancement(double scoreClimat, {required bool aBadgeAssureClimat}) {
  final bonus = aBadgeAssureClimat ? 10.0 : 0.0;
  return (scoreClimat + bonus).clamp(0.0, 100.0);
}
