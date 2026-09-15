# Changelog

Toutes les évolutions notables du projet GreenAccess sont documentées dans ce fichier.

Le format suit les grandes lignes de [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).
Pour le détail tâche par tâche (bugs trouvés, décisions de conception, limites connues),
voir `README.md` §7 (Tests) et §8 (État d'avancement) — ce fichier reste volontairement
condensé, au niveau des phases du plan d'implémentation du CDC.

## [v0.9.0-mvp] — Phases 1 à 6 (J1.1 à J6.10)

Première version distribuée aux testeurs (Firebase App Distribution). Couvre
l'ensemble du parcours utilisateur : inscription, scoring climat, formation,
financement, assurance, messagerie, badges certifiés — plus l'infrastructure
de test et de livraison.

### Ajouté

- **Socle** : architecture MVVM + Riverpod + go_router, 5 modules métier
  (Scoring, Formation, Financement, Assurance, Profil), shell utilisateur à 5
  onglets + shell admin séparé, exécution Web via Codespaces.
- **Design system « Organic Fintech »** (`lib/ui/`) : jetons clair/sombre,
  17 composants `Ga*`, jauge de score animée, transitions de route par flux ;
  9 écrans vitrine refondus bout en bout.
- **Auth & RGPD (Phase 3)** : connexion Google, export RGPD PDF/CSV, journal
  d'audit inviolable branché sur 4 actions critiques.
- **Carte des aléas climatiques (Phase 4)** : `CarteAleaScreen` (16 zones
  UEMOA), ciblage GPS, Score Climat comme facteur de prime d'assurance
  (règle CDC §4.1), écran admin de gestion des zones.
- **Messagerie & badges certifiés (Phase 5)** : messagerie temps réel liée à
  une demande de financement (règles Firestore restreintes aux deux
  parties), notification FCM avec repli WhatsApp mocké, badges OpenBadge v2
  (émission mockée, export JSON/PDF), incitations croisées entre modules
  (badge Assuré Climat → +10 pts d'éligibilité financement, badge Financé
  Vert à l'approbation).
- **E2E, performance & livraison (Phase 6)** : infrastructure Patrol sur
  émulateur Android réel (CI dédiée `e2e.yml`), scénarios T01 (inscription
  OTP < 3 s), T04 (blocage financement par score), T05 (dépôt de demande
  jusqu'à SOUMIS), T07 (cache hors-ligne + synchronisation) ; SDK
  `firebase_performance` avec traces sur les opérations clés ; parallélisation
  des lectures Firestore du tableau de bord.

### Corrigé

En cours de développement, l'écriture des tests (unitaires, widgets,
intégration, E2E) a révélé et corrigé une trentaine de bugs réels avant
qu'ils n'atteignent la production — dont, les plus significatifs :

- Formule de scoring : clés snake_case/camelCase désalignées entre le
  client et la Cloud Function, réponse serveur sans les critères détaillés,
  schéma Firestore incohérent avec le modèle de lecture.
- Bonus de formation (+3 pts/badge) jamais réellement appliqué côté serveur
  depuis sa création (filtre Firestore sur un champ qui n'existe pas).
- Écran d'inscription par OTP totalement inaccessible depuis l'interface, et
  profil Firestore jamais créé pour un nouvel inscrit par ce chemin
  (tableau de bord vide indéfiniment).
- Règle Firestore de la messagerie trop permissive (n'importe quel
  partenaire financeur, pas seulement celui assigné à la demande).
- Verrou de financement CDC §4.1 : validation de formulaire jamais
  déclenchée sur le stepper de demande (7 étapes).

### Infrastructure

- CI/CD GitHub Actions : `ci.yml` (analyze → test → build web/apk debug sur
  chaque push), `build-apk.yml` (APK release à la demande), `e2e.yml`
  (Patrol sur émulateur Android réel, manuel).
- 211 tests `flutter test`, 45 tests Cloud Functions, 34 tests de règles
  Firestore Security Rules — tous exécutés en CI.

[v0.9.0-mvp]: https://github.com/Leandre-oloke/appli-greenaccess/releases/tag/v0.9.0-mvp
