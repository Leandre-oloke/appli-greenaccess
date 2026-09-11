# GreenAccess

**Plateforme mobile de micro-financement vert, d'éducation climatique et d'assurance inclusive — Afrique francophone.**

Application Flutter (Android / iOS) adossée à Firebase, organisée en architecture **MVVM** avec **Riverpod** pour la gestion d'état et **go_router** pour la navigation.

---

## 1. Vue d'ensemble fonctionnelle

L'app couvre 5 modules métier, plus un back-office admin.

| Module | Rôle | Écrans principaux |
|---|---|---|
| **Auth** | Onboarding, inscription, connexion, vérification OTP, ré-authentification forcée à chaque ouverture (app financière) | `splash`, `onboarding`, `login`, `register`, `otp` |
| **Scoring climat** | Questionnaire d'évaluation du score climatique de l'utilisateur, calcul côté Cloud Function, résultat + historique | `scoring_form`, `score_result`, `historique_score` |
| **Formation** | Catalogue de cours (vidéo / PDF / quiz / infographie), détail de cours, quiz noté, badges de progression | `course_list`, `course_detail`, `quiz`, `badges` |
| **Financement** | Demande de micro-crédit vert, suivi du statut, échéancier de remboursement, paiement Mobile Money (Wave, Orange Money, MTN MoMo, Moov, Free), annuaire des partenaires financeurs | `financement`, `demande_form`, `statut_demande`, `remboursements`, `paiement`, `partenaires` |
| **Assurance** | Fiches produits, simulateur de prime, souscription, gestion des contrats, déclaration de sinistre | `assurance`, `fiches_produit`, `simulateur_assurance`, `souscription`, `mes_contrats`, `sinistre_form` |
| **Notifications** | Centre de notifications in-app + push FCM (bannière en premier plan, handler background) | `notifications` |
| **Admin** | Tableau de bord, gestion des formations et leçons, utilisateurs, demandes de financement, contrats, partenaires, analytics, paramètres | `admin_dashboard`, `admin_formations`, `admin_lecons`, `admin_users`, `admin_demandes`, `admin_contrats`, `admin_partenaires`, `admin_analytics`, `admin_settings` |

**Rôles utilisateur** (`UserRole`) : `user`, `partenaireAssureur`, `partenaireFinanceur`, `admin`.
Le routage applique une redirection selon l'état d'authentification et le rôle (les routes `/admin/**` sont réservées aux admins).

---

## 2. Architecture

```
lib/
├── main.dart                 # bootstrap : Firebase, FCM, cache Firestore offline, ProviderScope
├── routes.dart               # AppRoutes + GoRouter (shell utilisateur + shell admin, redirections par rôle)
├── theme.dart                # shim de compat. : ré-exporte AppTheme (lib/ui/theme/) + AppColors
├── firebase_options.dart     # config Firebase générée par FlutterFire (clés client)
├── firebase_env.dart         # sélectionne les options Firebase selon AppEnvironment (dev/prod)
│
├── core/
│   ├── env/app_env.dart                   # AppEnv dev/prod, --dart-define=APP_ENV
│   ├── constants/app_colors.dart          # ré-exporte AppColors (voir ui/theme)
│   ├── providers/prefs_provider.dart      # SharedPreferences injecté via override
│   ├── providers/theme_mode_provider.dart # clair / sombre / système, persistant
│   └── widgets/connectivity_banner.dart   # bannière hors-ligne (connectivity_plus)
│
├── ui/               # design system « Organic Fintech » (voir package:greenaccess/ui/ui.dart)
│   ├── tokens/       # couleurs (clair+sombre), spacing, radii, typo, motion, score-scale
│   ├── theme/        # AppTheme.light/.dark + ThemeExtensions (GaShadows, GaGradients…)
│   ├── motion/       # transitions de route (GaPageTransitions) + presets d'entrée
│   └── components/   # 17 composants Ga* (GaCard, GaScoreGauge, GaStepper, GaChoiceGroup…)
│
├── models/          # modèles de données immuables (+ enums de statut)
│   ├── user_model.dart              (UserModel, UserRole)
│   ├── score_climat_model.dart      (ScoreClimatModel, ScoreCriteres, NiveauScore)
│   ├── course_model.dart            (CourseModel, CourseProgress, QuizQuestion, CourseType)
│   ├── lecon_model.dart / badge_model.dart
│   ├── demande_financement_model.dart (DemandeFinancementModel, StatutDemande)
│   ├── remboursement_model.dart
│   ├── paiement_model.dart          (PaiementModel, OperateurMobileMoney, StatutPaiement)
│   ├── partenaire_model.dart
│   ├── assurance_model.dart         (ProduitAssuranceModel, ContratAssuranceModel, SimulationAssuranceResult, ZoneAleaModel, StatutContrat)
│   └── notification_model.dart      (NotificationModel, NotificationType)
│
├── repositories/    # accès données Firestore / Storage / Cloud Functions
│   ├── auth_repository.dart
│   ├── score_repository.dart
│   ├── cours_repository.dart
│   ├── financement_repository.dart
│   ├── paiement_repository.dart
│   ├── partenaire_repository.dart
│   ├── assurance_repository.dart
│   ├── notification_repository.dart
│   └── admin_repository.dart
│
├── viewmodels/      # logique de présentation (StateNotifier / Notifier Riverpod)
│   ├── auth_viewmodel.dart
│   ├── scoring_viewmodel.dart
│   ├── formation_viewmodel.dart
│   ├── financement_viewmodel.dart
│   ├── partenaire_viewmodel.dart
│   ├── assurance_viewmodel.dart
│   ├── notification_viewmodel.dart
│   └── admin_viewmodel.dart
│
└── views/           # UI par module (auth, scoring, formation, financement, assurance,
                     #   notifications, dashboard, profil, shell, admin)
```

**Flux** : `View` → observe un `ViewModel` (provider Riverpod) → appelle un `Repository` → Firestore / Storage / Cloud Functions.

Navigation : `StatefulShellRoute.indexedStack` pour le shell utilisateur (5 onglets keep-alive : Accueil, Formation, Financement, Assurance, Profil) et un `ShellRoute` distinct pour le back-office admin.

**Design system** : `lib/theme.dart` est un shim de compatibilité — il ré-exporte `AppTheme`
(construit depuis `lib/ui/theme/`) et garde `AppColors` avec les mêmes noms mais des valeurs
repointées sur les jetons du design system, pour que les écrans non encore refondus héritent
de la palette. 9 écrans vitrine sont refondus de bout en bout (splash, onboarding, login,
register, otp, dashboard, scoring, résultat de score, historique) ; les autres héritent du
thème sans refonte de layout — détail dans `lib/ui/ui.dart`.

---

## 3. Stack technique

- **Flutter** SDK `^3.8.1` (canal stable ; CI/Codespace sur Flutter 3.47)
- **Firebase** : `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_messaging`
- **État** : `flutter_riverpod` `^2.5`
- **Navigation** : `go_router` `^14.2`
- **UI** : `fl_chart`, `percent_indicator`, Material 3
- **Design system** (`lib/ui/`) : `flutter_animate` (cascades, shimmer), `animations` (transitions
  shared-axis / fade-through), `lottie`, `flutter_svg`, `easy_stepper` — polices **Sora** (display)
  et **Inter** (corps) bundlées dans `assets/fonts/` (pas `google_fonts`, pour rester déterministe
  hors-ligne). Jauge de score signature en `CustomPainter` maison (`GaScoreGauge`).
- **Cartographie** : `flutter_map` + `latlong2` déclarés (Module Assurance, pas encore importés)
- **Divers** : `shared_preferences`, `intl` (locale `fr`), `url_launcher`, `file_picker`, `image_picker`, `geolocator`, `connectivity_plus`, `pdf` + `printing`, `equatable`
- **Backend** : Cloud Functions (TypeScript) dans `functions/`
  - `calculerScoreClimat` (callable, contrôle d'accès)
  - `onCourseCompleted` (trigger Firestore)
  - `onDemandeSubmitted` (trigger Firestore)
  - `checkAlertesClimatiques` (planifiée / pub-sub)
- **Règles de sécurité** : `firestore.rules`, `storage.rules`, index dans `firestore.indexes.json`
- **Chaîne Android** : Gradle `8.14.3` · AGP `8.11.1` · Kotlin `2.2.20` (minimums requis par
  Flutter 3.47 — voir `android/gradle/wrapper/gradle-wrapper.properties` et `android/settings.gradle.kts`)

Package Android : `com.greenaccess.greenaccess`

---

## 4. Prérequis

- Flutter SDK `>= 3.8` (`flutter --version`)
- SDK Android / Xcode selon la plateforme cible
- Node.js `>= 20` (pour les Cloud Functions)
- Firebase CLI (`npm i -g firebase-tools`) et `flutterfire_cli` si tu régénères la config

---

## 5. Configuration (fichiers non versionnés)

Pour des raisons de sécurité, ces fichiers **ne sont pas dans le dépôt** et doivent être récupérés / générés :

| Fichier | Où | Comment l'obtenir |
|---|---|---|
| `android/app/google-services.json` | racine du module Android | Console Firebase → Paramètres du projet → app Android |
| `ios/Runner/GoogleService-Info.plist` | projet iOS | Console Firebase → app iOS |
| `.env` / `*.env` | selon besoin | secrets locaux |

> `lib/firebase_options.dart` **est** versionné (il ne contient que des clés client Firebase, protégées par les règles Firestore/Storage). Le dépôt GitHub est **public** — les workflows CI (`.github/workflows/`) régénèrent `android/app/google-services.json` à la volée à partir de ces mêmes clés, sans secret à configurer.

Régénérer la config si besoin :

```bash
flutterfire configure
```

### Plan Blaze — requis pour déployer les Cloud Functions

`greenaccess-16d25` est aujourd'hui sur le plan gratuit **Spark**. Google exige le passage
au plan **Blaze** (paiement à l'usage) pour déployer la moindre Cloud Function — pas de
contournement possible, c'est une contrainte de la plateforme, pas du projet. En pratique
Blaze garde un niveau gratuit généreux (2M invocations/mois...) : le coût reste à 0 € tant
que l'usage ne dépasse pas ces quotas.

Activer : https://console.firebase.google.com/project/greenaccess-16d25/usage/details → *Modifier le plan* → *Blaze*.

**En attendant**, deux façons de ne pas être bloqué :
- **Émulateurs Firebase** (`firebase emulators:start`, voir §6bis) : développer et tester les
  Cloud Functions en local, **sans Blaze ni carte bancaire**.
- `ScoreRepository` a un **repli de calcul local** si `calculerScoreClimat` est injoignable
  (fonction non déployée) — l'app reste utilisable de bout en bout sans déploiement. Ce repli
  est temporaire : le CDC interdit tout calcul de score côté client, il sera retiré une fois
  Blaze actif et les functions déployées (voir §8).

### Environnements (dev / prod)

`lib/core/env/app_env.dart` + `lib/firebase_env.dart` définissent le mécanisme de bascule :

```bash
flutter run --dart-define=APP_ENV=dev     # ou APP_ENV=prod (défaut si omis)
```

Un seul projet Firebase existe pour l'instant (`greenaccess-16d25`) — les deux valeurs
pointent donc dessus, `APP_ENV=dev` ne change rien au backend pour le moment. Le mécanisme
est prêt : créer un second projet Firebase de dev, régénérer ses clés avec `flutterfire
configure --project=<projet-dev> --out=lib/firebase_options_dev.dart`, puis brancher ce
fichier dans `firebase_env.dart` (instructions en commentaire dans ce fichier).

---

## 6. Installation & lancement

```bash
# 1. Cloner
git clone https://github.com/Leandre-oloke/appli-greenaccess.git
cd appli-greenaccess

# 2. Déposer google-services.json / GoogleService-Info.plist (voir §5)

# 3. Dépendances Flutter
flutter pub get

# 4. Lancer
flutter run

# (optionnel) Cloud Functions
cd functions
npm install
npm run build
firebase emulators:start        # ou : firebase deploy --only functions
```

---

## 6bis. Exécution dans un GitHub Codespace (Flutter Web)

Le dépôt contient un `.devcontainer/` : le Codespace installe automatiquement Flutter,
Node 20 et la Firebase CLI, puis lance `flutter pub get` et `npm install` sur `functions/`.

Cible : **l'app en Web** (Android/iOS impossibles sans écran ni Mac). Les notifications
push FCM sont désactivées sur le Web.

**Étape manuelle unique — enregistrer une app Web Firebase :**
Console Firebase → projet `greenaccess-16d25` → Paramètres du projet → *Vos applications*
→ Ajouter une application → Web. Reporter `apiKey` et `appId` dans le bloc `web` de
`lib/firebase_options.dart` (l'app lève une erreur explicite tant que ce n'est pas fait).

```bash
# 1. Backend — au choix :
#    a) rien à faire : l'app tape sur le vrai projet greenaccess-16d25
#    b) émulateurs locaux :
firebase emulators:start          # UI sur le port 4000

# 2. App Web
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
#    ... ou contre les émulateurs :
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=USE_EMULATOR=true
```

Codespaces forwarde le port **8080** (app) et **4000** (UI émulateurs) — les ouvrir depuis
l'onglet *Ports*.

Le dossier `web/` est minimal ; pour le régénérer complètement : `rm -rf web && flutter create --platforms=web .`

Build d'un APK depuis le Codespace : `bash .devcontainer/build-apk.sh` (installe Java 17 + SDK
Android si besoin, mémoire Gradle plafonnée pour la RAM du Codespace, repli automatique en
`--debug` si `--release` échoue). Voir aussi §6ter pour un build via GitHub Actions.

---

## 6ter. CI/CD (GitHub Actions)

Deux workflows dans `.github/workflows/` (Java 17, cache pub + cache Gradle) :

| Workflow | Déclencheur | Contenu |
|---|---|---|
| `ci.yml` | push sur toute branche + PR | `flutter analyze` → (`flutter test --coverage` ‖ `firestore rules (emulator)` ‖ `flutter integration tests (emulator)`, en parallèle après `analyze`) → (`build web` ‖ `build apk --debug`, en parallèle après `test`). Artefacts : `coverage-lcov`, `greenaccess-debug-apk` (7 jours). |
| `build-apk.yml` | manuel (`workflow_dispatch`) ou push sur `feat/design-system-overhaul` | `flutter build apk --release --split-per-abi`. Artefact `greenaccess-apk` (arm64-v8a, armeabi-v7a, x86_64 séparés — l'arm64 tient sous 30 Mo pour une distribution directe). |

Le job `integration` (`ci.yml`) démarre l'émulateur Firestore (`firebase emulators:exec
--only firestore`, Java 17 requis) et y exécute `firestore-tests/` (Node.js,
`@firebase/rules-unit-testing`) : isolation des documents `users/{uid}`, interdiction de
s'auto-promouvoir `role: admin`, cloisonnement des `scores_climat` et `demandes_financement`
par propriétaire, droits d'écriture `partenaireFinanceur`. C'est un test des **Security
Rules**, pas de l'app Flutter — voir §7 pour pourquoi ce choix.

Les deux régénèrent `android/app/google-services.json` à la volée depuis les clés déjà
versionnées dans `lib/firebase_options.dart` (§5) — aucun secret de repo à configurer.

Lancer `build-apk.yml` manuellement : `gh workflow run "Build APK" --ref <branche>`, puis
`gh run download <id> -n greenaccess-apk`.

---

## 7. Tests

```bash
flutter test
```

Tests présents (`test/`) :

- `viewmodels/admin_viewmodel_test.dart`
- `viewmodels/assurance_viewmodel_test.dart`
- `viewmodels/formation_viewmodel_test.dart`
- `viewmodels/scoring_viewmodel_test.dart`
- `widget_test.dart` — smoke test du design system (`AppTheme` clair/sombre + composants `Ga*`
  se rendent sans exception). Ne boote **pas** `GreenAccessApp` en entier : dès son premier
  `build()`, l'app touche trois plugins Firebase réels (Auth, Firestore, Messaging) dont le
  mock fiable en test VM est fragile (canaux Pigeon spécifiques à chaque version) — un boot
  complet avec Firebase réel relève d'un test `integration_test` sur device/émulateur.
- `helpers/firebase_test_setup.dart` — mock des canaux `firebase_core`/`cloud_functions` legacy,
  utilisé par les tests de ViewModels (repositories injectés avec `fake_cloud_firestore`)

Exécutés automatiquement par `ci.yml` à chaque push.

**Firestore Security Rules** (`firestore-tests/`, Node.js) :

```bash
bash .devcontainer/run-emulators.sh          # émulateurs en continu (dev/QA manuelle)
# ou, comme en CI :
firebase emulators:exec --only firestore "npm --prefix firestore-tests test"
```

Pourquoi un projet Node séparé plutôt qu'un test Flutter : un `flutter test` classique tourne
dans la VM Dart, sans platform channels — les plugins `firebase_auth`/`cloud_firestore` ne
peuvent donc pas parler à un émulateur réel (c'est ce qui a cassé `widget_test.dart` avant sa
réécriture, voir ci-dessus). `@firebase/rules-unit-testing` est la lib officielle pour ce cas :
elle synthétise des contextes d'auth côté Node directement contre l'émulateur Firestore, sans
même avoir besoin de l'émulateur Auth.

**Tests d'intégration Flutter** (`test/integration/`, tag `integration`) :

```bash
firebase emulators:exec --only auth,firestore,functions \
  "flutter test --tags=integration --platform chrome"
```

- `auth_repository_test.dart` — inscription/connexion/déconnexion, changement de mot de
  passe, suppression de compte, contre l'émulateur Auth + Firestore réels.
- `score_repository_test.dart` — calcule un vrai score via `calculerScoreClimat` sur
  l'émulateur Functions, sauvegarde/lecture d'historique sur l'émulateur Firestore.
- `financement_repository_test.dart` — soumission de demande, isolation par propriétaire,
  droits de mise à jour (propriétaire vs. brouillon), échéancier de remboursement.
- `cours_repository_test.dart` — repli sur les cours de démo, progression + déclenchement de
  badges (≥70% au quiz), idempotence du badge "Assuré Climat".

Ces fichiers utilisent `flutter test --platform chrome` (et non la VM Dart par défaut) : c'est
un vrai navigateur headless, avec les implémentations web des plugins `firebase_*`, donc de
vrais platform channels — contrairement à un `flutter test` classique (VM, sans channels, voir
ci-dessus). Exclus du job `test` normal via `--exclude-tags=integration` côté CI (ils ont
besoin des émulateurs démarrés, pas juste de `flutter test`).

En écrivant `score_repository_test.dart`, ces tests ont immédiatement révélé 5 bugs réels de
correspondance de schéma entre `lib/repositories/score_repository.dart` et
`functions/src/index.ts` (corrigés dans le même commit) :
1. Le client envoyait des clés snake_case (`type_activite`…) à la Cloud Function, qui attend
   du camelCase (`typeActivite`…) — les 3 premiers critères retombaient silencieusement sur
   leurs valeurs par défaut.
2. Les libellés de certification affichés par le formulaire (`Bio`, `Équitable`) ne
   correspondaient à aucune clé de la table de score côté Cloud Function.
3. La réponse de la Cloud Function n'incluait pas du tout `criteres` — chaque critère
   s'affichait à 0 juste après un calcul serveur.
4. Le document Firestore persisté par la Cloud Function utilisait des clés différentes
   (`score_total`, `score_activite`…) de celles que `ScoreClimatModel.fromFirestore` /
   `ScoreCriteres.fromMap` attendent (`score_total`→ok mais `criteres.activite` etc.) —
   l'historique aurait aussi affiché des critères à 0.
5. `ScoreRepository()` était construit sans région Cloud Functions explicite
   (`lib/viewmodels/scoring_viewmodel.dart`), donc ciblait `us-central1` par défaut alors que
   `calculerScoreClimat` est déployée sur `europe-west1` — chaque appel aurait échoué en
   "not-found" une fois le plan Blaze activé.

Deux bugs supplémentaires trouvés en stabilisant ces tests en CI (job GitHub Actions, pas
seulement en local) :

6. `firestore.indexes.json` déclarait l'index composite de `scores_climat` sur le champ
   `dateCalcul`, qui n'existe dans aucun document réel — les requêtes utilisent bien
   `date_calcul` (voir `ScoreRepository.getLatestScore`/`getHistory`). Une fois déployé, tout
   appel à ces méthodes aurait échoué en `FAILED_PRECONDITION` (index manquant).
7. `functions/package.json` déclarait `"engines": {"node": ">=20"}` — un intervalle, que
   l'émulateur Functions refuse (il exige une version exacte parmi 20/22/24). Corrigé en
   `"20"`.

Un troisième point, plus subtil, a nécessité `TestWidgetsFlutterBinding.ensureInitialized()`
en tête de chaque `setUpAll()` : contrairement à `testWidgets()`, un simple `test()` n'active
pas automatiquement le binding Flutter, donc les platform channels (et donc les plugins
`firebase_*`) ne sont pas encore utilisables au moment de `Firebase.initializeApp()`.

---

## 8. État d'avancement

**Fait**

- Architecture MVVM + Riverpod + go_router en place, 5 modules métier câblés bout en bout
- Shell utilisateur (5 onglets keep-alive) + shell admin séparé avec redirection par rôle
- Auth Firebase avec OTP et ré-authentification à chaque ouverture
- Scoring climat via Cloud Function `calculerScoreClimat`
- Formation : catalogue, détail, quiz noté, badges ; CRUD admin des formations et leçons
- Financement : demande, suivi de statut, échéancier, paiement Mobile Money, partenaires
- Assurance : produits, simulateur, souscription, contrats, déclaration de sinistre
- Notifications push FCM (foreground + background) + centre in-app
- Cache Firestore hors-ligne + bannière de connectivité
- Règles de sécurité Firestore & Storage, index Firestore
- Cloud Functions : scoring, triggers cours/demande, alertes climatiques planifiées
- Exécution Web via Codespaces (`.devcontainer/`) — cible sans Android/iOS
- **Design system « Organic Fintech »** (`lib/ui/`) : jetons clair/sombre, thème Material 3,
  17 composants `Ga*`, jauge de score animée, transitions de route par flux ; 9 écrans vitrine
  refondus bout en bout (auth complet, dashboard, parcours scoring)
- **CI/CD GitHub Actions** : pipeline `analyze → test → build web / apk debug` sur chaque push
  + workflow de build APK release à la demande (§6ter)
- Chaîne Android mise à niveau pour Flutter 3.47 (Gradle/AGP/Kotlin)
- Tests unitaires de ViewModels (46) + smoke test du design system, exécutés en CI
- Tests des Firestore Security Rules (`firestore-tests/`) contre l'émulateur, en CI
  (isolation utilisateur, anti-élévation de rôle, droits partenaireFinanceur)
- Tests d'intégration Flutter (`test/integration/`, `--platform chrome`) pour
  AuthRepository, ScoreRepository, FinancementRepository et CoursRepository contre les
  émulateurs — ont révélé et corrigé 7 bugs réels de correspondance de schéma/config
  (client ↔ Cloud Function, index Firestore, version Node) — voir §7
- Mécanisme de bascule d'environnement (`APP_ENV=dev/prod`, `lib/firebase_env.dart`) — en
  attente d'un second projet Firebase de dev pour devenir effectif (voir §5)

**À faire / en cours**

- ⚠️ **Sécurité à trancher** : `firestore.rules` autorise `allow create: if isOwner(userId)`
  sur `users/{userId}` sans restreindre le champ `role` — l'app envoie toujours `role: 'user'`
  à l'inscription (aucun écran ne permet de choisir), mais un client qui écrirait directement
  dans Firestore (hors app) pourrait en théorie se créer un compte `role: 'admin'` dès la
  création. Non exploité aujourd'hui, non corrigé ici (changerait le contrat des Security
  Rules, testé par `firestore-tests/` — mérite une décision explicite plutôt qu'une correction
  silencieuse). Fix probable : `allow create: if isOwner(userId) && request.resource.data.role == 'user';`
- Suite de la refonte visuelle : retrofit des écrans legacy restants, retrait de
  `percent_indicator`, sélecteur de thème dans Profil
- Activer le plan Blaze sur `greenaccess-16d25` puis `firebase deploy` (functions/rules/index)
  — bloquant, aucun contournement (§5) ; développement des functions en attendant via les
  émulateurs Firebase
- Créer un projet Firebase de dev distinct et y brancher `firebase_env.dart`
- Retirer le calcul de score de secours côté client (`ScoreRepository`), non conforme au CDC
- Couverture de tests à étendre : `FinancementRepository`/`CoursRepository` contre les
  émulateurs (même principe que `test/integration/`), widgets, parcours E2E
- Intégration réelle des API Mobile Money (actuellement flux applicatif)
- Carte des aléas climatiques (Module Assurance, `flutter_map` déjà déclaré)

> Suivi détaillé tâche par tâche : plan d'implémentation (classeur xlsx partagé séparément,
> non versionné dans ce dépôt).

---

## 9. Conventions

- Code et commentaires en **français**
- Un modèle = une classe immuable + `fromMap` / `toMap` ; enums de statut préfixés par le domaine
- Pas d'appel Firestore direct depuis une `View` — toujours passer par un `Repository` via un `ViewModel`
- Lint : `flutter_lints` (`analysis_options.yaml`)
