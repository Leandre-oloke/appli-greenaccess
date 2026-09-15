# GreenAccess

**Plateforme mobile de micro-financement vert, d'éducation climatique et d'assurance inclusive — Afrique francophone.**

Application Flutter (Android / iOS) adossée à Firebase, organisée en architecture **MVVM** avec **Riverpod** pour la gestion d'état et **go_router** pour la navigation.

---

## 1. Vue d'ensemble fonctionnelle

L'app couvre 5 modules métier, plus un back-office admin.

| Module | Rôle | Écrans principaux |
|---|---|---|
| **Auth** | Onboarding, inscription, connexion (email/mot de passe + Google, voir §5), vérification OTP, ré-authentification forcée à chaque ouverture (app financière) | `splash`, `onboarding`, `login`, `register`, `otp` |
| **Scoring climat** | Questionnaire d'évaluation du score climatique de l'utilisateur, calcul côté Cloud Function, résultat + historique | `scoring_form`, `score_result`, `historique_score` |
| **Formation** | Catalogue de cours (vidéo / PDF / quiz / infographie), détail de cours, quiz noté, badges de progression | `course_list`, `course_detail`, `quiz`, `badges` |
| **Financement** | Demande de micro-crédit vert, suivi du statut, échéancier de remboursement, paiement Mobile Money (Wave, Orange Money, MTN MoMo, Moov, Free), annuaire des partenaires financeurs | `financement`, `demande_form`, `statut_demande`, `remboursements`, `paiement`, `partenaires` |
| **Assurance** | Fiches produits, simulateur de prime, souscription, gestion des contrats, déclaration de sinistre | `assurance`, `fiches_produit`, `simulateur_assurance`, `souscription`, `mes_contrats`, `sinistre_form` |
| **Notifications** | Centre de notifications in-app + push FCM (bannière en premier plan, handler background) | `notifications` |
| **Admin** | Tableau de bord, gestion des formations et leçons, utilisateurs, demandes de financement, contrats, partenaires, zones d'aléa climatique, analytics, paramètres | `admin_dashboard`, `admin_formations`, `admin_lecons`, `admin_users`, `admin_demandes`, `admin_contrats`, `admin_partenaires`, `admin_zones_alea`, `admin_analytics`, `admin_settings` |

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
│   └── components/   # 22 composants Ga* (GaCard, GaScoreGauge, GaStepper, GaChoiceGroup…)
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
│   ├── assurance_model.dart         (ProduitAssuranceModel, ContratAssuranceModel, SimulationAssuranceResult, ZoneAleaModel, StatutContrat, SinistreModel)
│   ├── notification_model.dart      (NotificationModel, NotificationType)
│   ├── user_data_export_model.dart  (UserDataExportModel — agrégat pour l'export RGPD, J3.4)
│   ├── audit_log_model.dart         (AuditLogModel — journal d'audit inviolable, J3.7)
│   └── message_model.dart           (MessageModel — messagerie liée à une demande, J5.1)
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
│   ├── export_repository.dart       (J3.4 — collecte cross-collections pour l'export RGPD)
│   ├── audit_repository.dart        (J3.7-J3.8 — logAction(), branché sur 4 actions critiques)
│   ├── messagerie_repository.dart   (J5.2 — envoi + flux temps réel des messages d'une demande)
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
│   ├── export_viewmodel.dart        (J3.4-J3.5 — orchestre collecte + génération + partage)
│   ├── messagerie_viewmodel.dart    (J5.3 — s'abonne au flux temps réel dès sa création)
│   └── admin_viewmodel.dart
│
├── utils/           # fonctions pures, sans accès Firestore
│   └── export_formatters.dart       (J3.5 — génère les fichiers PDF et CSV de l'export RGPD)
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

**En attendant**, une seule façon de développer/tester sans être bloqué : les **émulateurs
Firebase** (`firebase emulators:start`, voir §6bis) — Cloud Functions en local, **sans Blaze
ni carte bancaire**.

⚠️ **Conséquence concrète tant que Blaze n'est pas activé et `calculerScoreClimat` pas
déployée : le calcul de score est indisponible dans l'app installée (APK, `flutter run` sans
émulateur).** `ScoreRepository` a bien un repli de calcul local (mêmes poids que la Cloud
Function), mais il est **désactivé par défaut** depuis la mise en conformité CDC §4.4
(commit `28d92275`, « le calcul n'est jamais effectué côté client ») — il ne s'active qu'en
passant explicitement `--dart-define=ALLOW_LOCAL_SCORE_FALLBACK=true` à la compilation (dev
uniquement, jamais utilisé dans les builds CI/APK release de ce dépôt). Par défaut, un appel à
`calculerScoreClimat` injoignable lève une exception affichée à l'utilisateur (« Le calcul du
score est momentanément indisponible… ») plutôt que de calculer localement. Tout le reste de
l'app (navigation, formulaires, autres modules) fonctionne normalement ; seul le calcul de
score lui-même est bloqué jusqu'au déploiement de la Cloud Function.

### Connexion Google (J3.1-J3.3) — action requise côté console Firebase

Le code (`AuthRepository.signInWithGoogle()`, `AuthViewModel.signInWithGoogle()`, bouton
« Continuer avec Google » sur `LoginScreen`) est en place et testé (voir §7), mais **la
connexion Google ne fonctionnera pas tant que ces étapes manuelles n'ont pas été faites dans
la console Firebase** (aucun contournement possible en code, comme pour le plan Blaze §5) :

1. **Activer le fournisseur** : Firebase Console → `greenaccess-16d25` → Authentication →
   Sign-in method → activer **Google** (choisir un email d'assistance).
2. **Récupérer le Web Client ID** : une fois activé, Firebase affiche sous « Configuration du
   SDK Web » un ID du type `xxxxx.apps.googleusercontent.com`. Le transmettre pour build via :
   ```bash
   flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com
   ```
   (voir la constante `_googleWebClientId` en tête de `lib/repositories/auth_repository.dart`).
   Sans cette valeur, le bouton Google ne fonctionne que sur mobile (Android/iOS), pas sur le
   web (le SDK `google_sign_in` web a besoin d'un client ID explicite).
3. **Android uniquement** : enregistrer l'empreinte SHA-1 (et idéalement SHA-256) du
   certificat de signature sous Project Settings → Apps → l'app Android → *Add fingerprint*.
   Sans ça, le sélecteur de compte Google échoue silencieusement au runtime sur un appareil
   Android réel, même avec le code correctement en place. Obtenir le SHA-1 :
   `cd android && ./gradlew signingReport` (debug **et** release si les deux sont testés).
   ⚠️ Les workflows CI (`ci.yml`, `build-apk.yml`) régénèrent `google-services.json` à la volée
   à partir d'un gabarit statique (voir §6ter) — l'APK qu'ils produisent ne pourra donc pas
   authentifier via Google tant que ce gabarit n'est pas mis à jour avec les infos OAuth
   Android une fois l'étape 3 faite (`oauth_client` y est actuellement vide).

Sans ces 3 étapes, taper sur « Continuer avec Google » affichera une erreur (ou échouera
silencieusement sur Android) — comportement attendu, pas un bug du code.

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

Trois workflows dans `.github/workflows/` (Java 17 ou 21 selon le job, cache pub + cache Gradle) :

| Workflow | Déclencheur | Contenu |
|---|---|---|
| `ci.yml` | push sur toute branche + PR | `flutter analyze` → (`flutter test --coverage` ‖ `backend tests (functions + firestore rules)`, en parallèle après `analyze`) → (`build web` ‖ `build apk --debug`, en parallèle après `test`). Artefacts : `coverage-lcov`, `greenaccess-debug-apk` (7 jours). |
| `build-apk.yml` | manuel (`workflow_dispatch`) ou push sur `feat/design-system-overhaul` | `flutter build apk --release --split-per-abi`. Artefact `greenaccess-apk` (arm64-v8a, armeabi-v7a, x86_64 séparés — l'arm64 tient sous 30 Mo pour une distribution directe). |
| `e2e.yml` | manuel (`workflow_dispatch`) uniquement | E2E Patrol (J6.1-J6.3, CDC §7.1-§7.2) sur un **émulateur Android réel** (hardware-accelerated sur `ubuntu-latest`, `reactivecircus/android-emulator-runner`) contre le Firebase Emulator Suite démarré dans le même job (auth + firestore + storage — jamais le vrai projet). Volontairement non déclenché à chaque push : un run complet (boot d'émulateur Android inclus) prend 10-15 min, largement plus coûteux qu'un `flutter test` classique — voir §7 pour le détail des scénarios et §8 pour ce que leur écriture a révélé. |

Le job `integration` (`ci.yml`) exécute trois suites :
1. `npm --prefix functions test` — tests unitaires purs de `calculerScoreClimat`
   (`functions/test/calculerScoreClimat.test.ts`, `node --test` + `tsx`, sans émulateur) :
   formule pondérée exacte, bornes 0-100, arrondi, contrôle d'accès (unauthenticated /
   permission-denied).
2. `npm --prefix functions run test:emulator` — tests des Cloud Functions qui font de
   vraies lectures/écritures Firestore : `onCourseCompleted` (badge déclenché + idempotence,
   `functions/test/triggers.test.ts`), `onDemandeSubmitted` (ciblage des partenaires
   financeurs à notifier, même fichier), `onMessageSent` (J5.6 — notification au destinataire
   d'un nouveau message : `getDestinataireContact()` détermine « l'autre partie » de la
   conversation — le partenaire assigné si l'auteur est le demandeur, le demandeur sinon — et
   son contact (token FCM + téléphone), `null`/`null` si aucun partenaire n'est encore assigné
   ou si le destinataire n'a ni l'un ni l'autre ; le déclencheur lui-même ne lève aucune erreur
   quand aucun canal n'est disponible ou que la demande associée a disparu, même fichier),
   `MockWhatsAppChannel` et `NotificationService.sendBestEffort()` (J5.7-J5.8, canal de secours
   WhatsApp mocké + sélection automatique FCM→WhatsApp, `sendFcm` injectable pour rester
   testable sans jamais toucher le vrai `admin.messaging()`, même fichier),
   `MockOpenBadgeIssuer` (J5.10-J5.12 — assertion OpenBadge v2 + URL, tracée dans
   `issuedBadges`, branchée sur `onCourseCompleted` qui stocke désormais l'URL réelle dans
   `openbadge_url` au lieu de `null`, même fichier), `getBonusFormation` + scénario T02
   (J5.17, CDC §7.1 · T02 — même fichier) : un badge délivré via `onCourseCompleted`
   (`BadgeIssuer`) est bien compté par `getBonusFormation()`, dont le score total reflète le
   bonus jusqu'à `calculerScoreClimat()` ; a révélé que le filtre
   `.where("dateObtention", ...)` de `getBonusFormation()` ciblait un champ camelCase qu'aucun
   badge n'écrit (tous en snake_case `date_obtention`), excluant silencieusement tous les
   badges du bonus de score côté serveur — corrigé en retirant ce filtre inutile (chaque badge
   a systématiquement une date dès sa création), et `checkAlertesClimatiques` (seuils
   sécheresse/inondation/chaleur + appel Open-Meteo mocké,
   `functions/test/checkAlertesClimatiques.test.ts`).
3. `firebase emulators:exec --only firestore` (Java 21 requis) exécute `firestore-tests/`
   (Node.js, `@firebase/rules-unit-testing`, 34 tests) : isolation des documents
   `users/{uid}`, interdiction de s'auto-promouvoir `role: admin` (à la création comme à la
   mise à jour), cloisonnement par propriétaire de `scores_climat`, `demandes_financement`
   (+ sous-collections `remboursements` et `messages`), `contrats_assurance`, `sinistres` et
   `paiements`, droits d'écriture `partenaireFinanceur`/`partenaireAssureur`, lecture ouverte /
   écriture admin-only pour `produits_assurance`, `zones_alea`, `partenaires` et les
   notifications globales, le journal d'audit `audit_logs` (J3.7) : création réservée à sa
   propre action (`userId == request.auth.uid`), champs requis validés, lecture réservée aux
   admins, modification/suppression **toujours refusées, même pour un admin** (ajout seul), et
   la messagerie `demandes_financement/{id}/messages` (J5.1-J5.2, restreinte en J5.5) :
   lecture/écriture réservées au propriétaire de la demande, à l'admin, et au partenaire
   financeur **spécifiquement assigné** à cette demande précise (`partenaire_id ==
   request.auth.uid`) — pas n'importe quel compte `partenaireFinanceur` comme dans la version
   initiale de J5.1-J5.2 —, création impossible en usurpant l'identité d'un autre auteur
   (`auteur_id == request.auth.uid`), modification/suppression toujours refusées (même logique
   d'ajout seul que `audit_logs`).

Les suites 2 et 3 tournent sous le **même** démarrage d'émulateur Firestore (une seule
commande `firebase emulators:exec`, deux `npm` enchaînés) pour éviter de le lancer deux fois.

Ce sont des tests du **backend** (Cloud Functions + Security Rules), pas de l'app Flutter —
voir §7 pour pourquoi ce choix.

Les deux régénèrent `android/app/google-services.json` à la volée depuis les clés déjà
versionnées dans `lib/firebase_options.dart` (§5) — aucun secret de repo à configurer.

Lancer `build-apk.yml` manuellement : `gh workflow run "Build APK" --ref <branche>`, puis
`gh run download <id> -n greenaccess-apk`.

**Couverture (J2.27)** : le job `test` calcule le pourcentage de couverture (lignes
couvertes/testées, `LH:`/`LF:` de `coverage/lcov.info`) et le publie dans l'onglet *Summary*
du run à chaque build (pas seulement dans l'artefact `coverage-lcov` téléchargeable) — calcul
fait à la main via `awk`, sans action tierce (Codecov ou autre) ni compte/token externe à
configurer. Mesure actuelle : **26 %** (1946/7486 lignes), sous la cible du CDC §7.1 (45-55 %) —
écart noté ici comme référence pour prioriser les prochaines tâches de tests (Phase 2 et
au-delà), pas corrigé dans cette tâche (0,5 h, hors périmètre d'écrire des dizaines de tests
supplémentaires).

---

## 7. Tests

```bash
flutter test
```

Tests présents (`test/`) :

- `repositories/export_repository_test.dart` (J3.4) — première suite de tests ciblant
  directement un repository (`fake_cloud_firestore`, sans passer par un ViewModel) : réunit
  les données d'un utilisateur à travers toutes les collections concernées (profil, scores,
  progression/badges/notifications personnelles, demandes + échéances de remboursement,
  paiements, contrats d'assurance, sinistres), et surtout vérifie l'absence de fuite entre
  comptes (données d'un autre utilisateur semées en décoy, jamais présentes dans l'export).
  Lève une exception explicite si le profil est introuvable.
- `repositories/assurance_repository_test.dart` (Phase 4, carte des aléas climatiques) —
  `getZonesAlea()` se replie sur `assets/data/zones_alea.json` quand Firestore est vide (même
  convention que `CoursRepository.fetchAll()` pour les cours de démo), mais utilise bien
  Firestore quand des zones y sont déjà présentes. Vérifie explicitement la présence des
  villes UEMOA demandées (Dakar, Thiès, Saint-Louis, Cotonou, Parakou) et l'absence de valeur
  par défaut silencieuse sur chaque champ (`typeAlea`/`niveauRisque` dans l'énumération
  attendue, coordonnées non nulles, rayon positif, `pays` — ajouté en J4.10 pour le ciblage GPS
  du simulateur — parmi les 8 pays déjà gérés par l'app). Étendu en J4.15 (import admin) :
  `importDefaultZonesAlea()` écrit les 16 zones bundlées dans Firestore (avec `pays`), un
  second import écrase proprement sans créer de doublons (upsert par `id`, pas d'ajout brut), et
  `deleteZoneAlea()` retire uniquement la zone visée. Étendu en J5.13 : `soumettreDossier()`
  délivre bien le badge Assuré Climat au souscripteur, de façon idempotente (pas de doublon à
  une seconde souscription) — ce branchement, hérité d'un travail antérieur à la Phase 5,
  n'avait encore aucune couverture de test directe.
- `repositories/cours_repository_test.dart` (J5.13, J5.15) — nouveau fichier, jusqu'ici
  `CoursRepository` n'était exercée qu'indirectement via des fakes dans
  `formation_viewmodel_test.dart`. Couvre les deux déclencheurs de badges liés à d'autres
  modules : `triggerFinanceVertBadge()` (Financement) et `triggerAssureClimatBadge()`
  (Assurance), même pattern idempotent que les badges de formation.
- `repositories/audit_repository_test.dart` (J3.7-J3.8) — `AuditRepository.logAction()`/
  `fetchLogs()` (écriture des champs attendus, tri du plus récent au plus ancien), puis
  vérifie le branchement réel sur les 4 actions critiques listées par le CDC §6 :
  `FinancementRepository.submit()`, `AssuranceRepository.soumettreDossier()`,
  `PaiementRepository.initierPaiement()` et `AuthRepository.deleteAccount()` alimentent
  chacune le journal d'audit avec la bonne action et le bon `userId`. Pour `deleteAccount()`,
  vérifie aussi que le log est bien écrit *avant* la suppression du document utilisateur (la
  règle Firestore exige `request.auth.uid`, invalide une fois le compte supprimé).
- `repositories/messagerie_repository_test.dart` (J5.2) — `envoyerMessage()` écrit les champs
  attendus dans la sous-collection `demandes_financement/{id}/messages` ;
  `streamMessages()` émet les messages triés du plus ancien au plus récent, et une nouvelle
  valeur dès qu'un message est ajouté (flux temps réel, pas un simple `get()`).
- `integration/rgpd_export_deletion_scenario_test.dart` (J3.9) — parcours complet portabilité
  → effacement sur un même utilisateur : export avant suppression (données présentes), puis
  `AuthRepository.deleteAccount()`, puis vérifie que le profil a disparu, qu'un nouvel export
  échoue explicitement (plutôt qu'un export vide silencieux), et que le journal d'audit garde
  la trace de la suppression. Comme les 4 fichiers `integration_test/` (voir plus bas), ce
  n'est pas un test Flutter contre de vrais émulateurs (bloqué dans ce Codespace) : le
  scénario T11 est validé avec les vrais repositories enchaînés dans l'ordre du parcours
  utilisateur, contre un `FakeFirebaseFirestore` partagé.
- `utils/badge_export_formatters_test.dart` (J5.16, CDC §5) — `buildBadgesJson()` n'inclut que
  les badges obtenus (avec `openbadge_url` quand disponible), liste vide sans badge obtenu ;
  `buildBadgesPdf()` produit un PDF non vide avec l'en-tête standard `%PDF-`, même sans aucun
  badge obtenu.
- `utils/eligibilite_financement_test.dart` (J5.14, CDC §4.1) — fonction pure
  `scoreEligibiliteFinancement()` : score inchangé sans le badge Assuré Climat, +10 pts avec,
  le bonus peut faire franchir le seuil d'éligibilité (60), plafond à 100 même avec le bonus.
- `utils/export_formatters_test.dart` (J3.5) — fonctions pures (`buildExportCsv`,
  `buildExportPdf`), testées sans Firestore à partir d'un `UserDataExportModel` fixe : contenu
  attendu par section, CSV valide même sans aucune donnée (en-têtes seuls), PDF non vide avec
  l'en-tête standard `%PDF-`. A révélé un avertissement (pas une erreur) : les fontes de base
  du package `pdf` (Helvetica, sans fonte embarquée — voir §7 ci-dessous) impriment "has no
  Unicode support" sur du texte français accentué ; comportement déjà présent (mais jamais
  remarqué, faute de test) dans les 3 autres exports PDF de l'app (`score_result_screen.dart`,
  `statut_demande_screen.dart`, `admin_demandes_screen.dart`) — documenté ici, pas corrigé
  (nécessiterait d'embarquer une fonte TTF, un chantier plus large que J3.4-J3.5).
- `viewmodels/admin_viewmodel_test.dart` — étendu en J5.15 : `approuverDemande()` délivre bien
  le badge Financé Vert au demandeur, en plus de la notification d'approbation déjà couverte.
- `viewmodels/assurance_viewmodel_test.dart` — étendu en J4.11-J4.12 (CDC §4.1) :
  `simulerPrime()` module la prime selon le Score Climat par paliers alignés sur
  `ScoreClimatModel.niveauFromScore` (mêmes bandes que partout ailleurs dans l'app) — aucune
  réduction sans score ou score insuffisant (jamais de majoration, règle purement incitative),
  5 % en intermédiaire, 15 % en bon, 25 % en excellent — avec vérification du montant de prime
  exact à chaque palier et de la mention de la réduction dans `raisonRecommandation`.
- `viewmodels/auth_viewmodel_test.dart` (J2.23) — connexion (succès, détection + nettoyage de
  compte orphelin, table de correspondance des 7 codes `FirebaseAuthException`→message),
  inscription (succès, `email-already-in-use` avec compte actif réel vs. avec orphelin
  confirmé), déconnexion, mise à jour de profil, changement de mot de passe, suppression de
  compte. A établi le bon usage de mockito dans ce dépôt : un `Mock` nu (`class X extends Mock
  implements Y {}`) échoue avec `when(...).thenReturn(...)` sur un getter non-nullable sans
  génération de code (`@GenerateMocks`) — ça lève une erreur de type qui corrompt ensuite l'état
  interne de mockito pour tous les `when()` suivants dans le même run ("Bad state: Cannot call
  `when` within a stub response"). Corrigé en remplaçant `Mock` par la classe `Fake` de mockito
  pour `User`/`UserCredential` (juste des champs surchargés via le constructeur, sans stubbing) ;
  `Mock` reste approprié pour les objets dont les méthodes ne sont jamais réellement invoquées
  (ex. `FirebaseAuth`/`FirebaseFunctions` ici, juste pour satisfaire un typage de constructeur).
  Étendu pour **J3.2** (`signInWithGoogle`) : première connexion (aucun profil Firestore →
  création depuis `displayName`/`email` du compte Google, `profilComplet: false` comme
  l'inscription email), connexion déjà existante (profil réutilisé sans réécriture),
  annulation (sélecteur de compte fermé sans choix → pas d'erreur affichée, comportement
  standard des SDK Google), erreur mappée (`account-exists-with-different-credential`).
  Étendu pour **J6.2** (`verifyOtp`) : profil déjà existant (réutilisé sans réécriture),
  première connexion par OTP (aucun profil Firestore → profil minimal créé, `profilComplet:
  false`, même pattern que la connexion Google), échec de vérification du code (erreur affichée,
  non authentifié). Écrit après coup, en marge du scénario E2E T01 — a justement révélé que ce
  chemin (première connexion par OTP) n'avait jusque-là aucune couverture directe, ce qui avait
  laissé passer le bug documenté en §8 (`user` restant `null` indéfiniment malgré
  `isAuthenticated: true`).
- `viewmodels/financement_viewmodel_test.dart` (J2.24) — simulation d'éligibilité (secteur vert
  vs. non vert, fourchette de montant ±30 %, taux indicatif, organisme « Microfinance locale »
  seulement si montant < 10 M FCFA), soumission de demande (succès/échec), chargement des
  demandes (succès/échec réseau), délégations pures (`getStatut`, `getRemboursements`,
  `genererEcheancier`). Aucun bug de production trouvé ; un comportement réel est documenté
  (pas corrigé, hors périmètre de cette tâche) : `_calculerEligibilite` compare le secteur en
  minuscules à une liste de mots-clés sans accents, donc `'ÉNERGIE'.toLowerCase()` (`'énergie'`)
  n'est jamais reconnu comme secteur vert à cause de l'accent.
- `viewmodels/formation_viewmodel_test.dart`
- `viewmodels/messagerie_viewmodel_test.dart` (J5.3) — s'abonne au flux temps réel dès sa
  création (comme `NotificationViewModel`) : charge les messages déjà présents, démarre vide
  sans erreur si aucun message n'existe encore, `envoyerMessage()` écrit le message et le fil
  se met à jour via le flux (pas un rechargement manuel), un contenu vide/blanc n'envoie rien,
  le contenu est nettoyé (`trim()`) avant l'envoi. Même précaution que pour
  `NotificationViewModel` (J2.26) : un `read()` immédiat après la création du conteneur de
  test force l'abonnement à démarrer avant que le test n'attende un court délai.
- `viewmodels/notification_viewmodel_test.dart` (J2.26) — fusion des flux broadcast (admin →
  tous) et personnel (contrat → un utilisateur) triée par date décroissante et limitée à 50,
  décompte de notifications non lues (`unreadCount`), persistance de `lastReadAt` dans
  `SharedPreferences` entre deux instances du ViewModel (simulant un redémarrage de l'app),
  suppression (y compris l'absorption silencieuse d'une exception du repository, par
  construction du code : `try { } catch (_) {}`). `NotificationViewModel` a un effet de bord
  réel dans son constructeur (`_init()` s'abonne à deux streams Firestore) : utilise donc le
  vrai `NotificationRepository` backé par un `FakeFirebaseFirestore` semé au préalable, comme
  `widgets/dashboard_screen_test.dart`, plutôt qu'un fake à retours contrôlés. A révélé un
  piège de test (pas un bug de production) : `ProviderContainer.overrides` est paresseux — le
  `StateNotifierProvider` (et donc l'abonnement Firestore fait par le constructeur du
  ViewModel) n'est construit qu'au premier `container.read(...)`, donc un test qui sème
  Firestore puis attend un délai sans avoir jamais lu le provider ne voit jamais les données
  arriver. Corrigé en forçant un `read` immédiatement après la création du conteneur.
- `viewmodels/partenaire_viewmodel_test.dart` (J2.25) — chargement de l'annuaire (succès/échec),
  création/modification/suppression/activation-désactivation d'un partenaire, y compris la
  conservation de la liste locale inchangée quand le repository lève une exception. Aucun bug
  de production trouvé.
- `viewmodels/scoring_viewmodel_test.dart`
- `widgets/login_screen_test.dart` (J2.17) — validation de formulaire (email invalide, mot
  de passe < 6 caractères, aucun appel à `signIn` tant que le formulaire n'est pas valide),
  affichage du bandeau d'erreur (`authState.error`), état de chargement (spinner + bouton
  désactivé). `authViewModelProvider` construit un vrai `AuthRepository()` par défaut, dont
  le constructeur évalue `FirebaseAuth.instance` (throw sans Firebase réel) — overridé par un
  `_FakeAuthViewModel extends AuthViewModel` (requis par le typage du provider) dont
  l'`AuthRepository` sous-jacent ne touche jamais Firebase : `firestore` fourni par
  `fake_cloud_firestore`, `authStateChanges` (seul appel fait à la construction) surchargé
  pour renvoyer un flux vide, et un `Mock` (mockito) implémentant `FirebaseAuth` juste pour
  satisfaire le typage du constructeur — jamais réellement invoqué. A révélé deux bugs
  réels en cours d'écriture : `GaSecondaryButton.ghost` (lien "Pas encore de compte ?
  S'inscrire") débordait en `Row(mainAxisSize: min)` sans `Flexible` — corrigé dans
  `lib/ui/components/ga_buttons.dart` — et `pumpAndSettle()` ne doit jamais être utilisé sur
  un état `isLoading` (le `CircularProgressIndicator` indéterminé ne "se stabilise" jamais) ;
  et les timers à durée nulle que `flutter_animate` programme pour la cascade d'entrée
  (`gaStagger`) doivent être vidés avec `pump(Duration.zero)`, pas un `pump()` nu, sous
  peine de `A Timer is still pending` en fin de test.
  Étendu pour **J3.3** : présence du bouton « Continuer avec Google », appel de
  `signInWithGoogle()` au tap, et mise à jour du test de chargement existant — les deux
  boutons de connexion (email + Google) partagent le même `authState.isLoading` et affichent
  donc chacun leur spinner (`findsNWidgets(2)`, pas `findsOneWidget` comme avant l'ajout du
  bouton Google).
  Étendu pour **J6.2** : présence du bouton « Continuer avec un numéro de téléphone » (nouvelle
  entrée vers `OTPScreen`, jusque-là inaccessible depuis l'UI — voir §8). `find.byType(OutlinedButton)`
  devient ambigu (Google **et** ce nouveau bouton partagent le même style
  `GaSecondaryButton.outlined`) : le test de chargement existant est adapté pour cibler le
  bouton Google par position (`.first`) plutôt que par texte, son label étant lui-même
  remplacé par un spinner pendant le chargement.
- `widgets/scoring_form_screen_test.dart` (J2.18) — navigation des 5 étapes du stepper
  (« Suivant »/« Retour »), conservation de la sélection au retour, contenu exact du
  payload soumis à `soumettreCriteres` (clés par défaut + certifications sélectionnées),
  bandeau d'erreur avec action « Voir les cours ». Même stratégie de fake pour
  `AuthRepository` ; `ScoreRepository` (utilisée par `ScoringViewModel`) a le même problème
  d'évaluation eager de Firebase dans son constructeur par défaut — contournée avec
  `firestore: FakeFirebaseFirestore()` et un `Mock` `FirebaseFunctions` jamais invoqué (le
  `_FakeScoringViewModel` surcharge `soumettreCriteres` entièrement).
- `widgets/score_result_screen_test.dart` (J2.19) — état vide sans score, jauge (valeur +
  niveau via le badge "Bon"/"Excellent"…), détail des 5 critères + bonus formation, section
  suggestions affichée seulement si non vide, bandeau et bouton d'action selon
  `peutDemanderFinancement`. Les boutons retour/export PDF/navigation ne sont pas testés
  (hors périmètre "jauge, niveau, suggestions") : ils appellent des APIs indisponibles sans
  routeur/plateforme réels (`context.canPop()`, `Printing.sharePdf`, `go_router`).
- `widgets/demande_form_screen_test.dart` (J2.20) — navigation du stepper 7 étapes,
  validation par étape (nom requis à l'étape 1, description ≥ 20 caractères à l'étape 2),
  bouton de soumission désactivé tant que la case de confirmation n'est pas cochée à
  l'étape 7. `ScoringViewModel`/`FinancementViewModel` n'ont aucun effet de bord dans leur
  constructeur : utilisés directement (pas de sous-classe fake) avec des repositories
  branchés sur `FakeFirebaseFirestore()`. A révélé deux bugs réels :
  1. `_onNext()` n'appelait jamais `_formKey.currentState.validate()` avant d'avancer — les
     validators "Requis"/"Minimum 20 caractères" des étapes 1-2 n'étaient jamais déclenchés,
     "Suivant" avançait toujours. Corrigé dans `demande_form_screen.dart`.
  2. Le nom/la région pré-remplis depuis le profil utilisateur (`initState` →
     `addPostFrameCallback` → `setState`, après le tout premier build) restaient invisibles
     à l'écran : un `TextFormField(initialValue:)` ne resynchronise son texte affiché qu'à
     sa toute première construction, pas sur un rebuild ultérieur avec un `initialValue`
     différent. Corrigé avec `key: ValueKey('nom-$nom')` (et pareil pour la région) sur ces
     deux champs, pour forcer Flutter à recréer le champ quand la valeur préremplie change.
  Étendu en J5.14 : override de `formationViewModelProvider` ajouté (sans badge semé, donc sans
  bonus) — `_submit()` lit désormais ce provider pour la règle 4.1, même raison que les
  overrides Scoring/FinancementViewModel déjà en place.
- `widgets/dashboard_screen_test.dart` (J2.21) — états vide (aucun score) et chargé (jauge +
  niveau + XP de formation) du point d'entrée après connexion, badge de notifications non
  lues, avertissement d'expiration de contrat d'assurance, résilience face à un état `error`
  (le dashboard n'affiche aucun bandeau d'erreur dédié — vérifié en lisant le code plutôt que
  supposé). Trois pièges à noter pour de futurs tests sur cet écran : (1) `DateFormat(...,
  'fr')` exige `initializeDateFormatting('fr', null)` dans `setUpAll` (fait normalement une
  seule fois par `main.dart` au démarrage réel, jamais exécuté dans un test isolé) ; (2)
  `initState()` déclenche `loadCourses()`/`loadLatestScore()` au montage, qui écrasent tout
  état de formation/score injecté à la main — il faut semer directement le
  `FakeFirebaseFirestore` sous-jacent avec les documents attendus plutôt que d'injecter l'état ;
  (3) le corps est un `SliverList` : au viewport par défaut du test (~600 px), le contenu en bas
  n'est jamais construit (virtualisation) — élargir le viewport (`tester.view.physicalSize`)
  avant de chercher ce contenu.
- `widgets/financement_screen_test.dart` (J2.22) — verrou d'accès au financement selon le score
  Climat (seuil 60/100, CDC §4.1) dans les deux sens : score < 60 (message "Score insuffisant",
  bouton "Nouvelle demande" masqué, action "Simuler" désactivée sans effet au tap) et score ≥ 60
  (message "Éligible au financement", bouton présent) ; cas `currentScore == null` traité comme
  0/100 (toujours verrouillé) ; état vide "Aucune demande". Aucun bug de production trouvé.
  Étendu en J5.14 (règle 4.1) : le badge Assuré Climat ajoute +10 pts au score affiché et peut
  faire franchir le seuil d'éligibilité — même piège que `dashboard_screen_test.dart` ci-dessus
  (2) : `initState()` appelle `loadCourses()`, qui écraserait un état de badges injecté
  directement sur `vm.state` — le badge est donc semé sur le `FakeFirebaseFirestore` sous-jacent
  avant `pumpWidget`, pas assigné à la main.
- `widgets/profil_screen_test.dart` (J3.6) — rend la portabilité des données accessible depuis
  l'écran Profil : présence du bouton « Télécharger mes données », ouverture du choix de
  format (PDF/CSV) au tap, appel de `exportAsCsv()`/`exportAsPdf()` avec le bon `userId` selon
  le choix. A révélé un piège de test (pas un bug de production) : le bouton est en bas d'un
  long formulaire défilant (`SingleChildScrollView`) — hors du viewport par défaut du test, un
  `tap()` direct rate silencieusement (offset hors zone visible). Corrigé avec
  `tester.ensureVisible()` avant le tap, plutôt que l'agrandissement de viewport utilisé pour
  le `SliverList` de `dashboard_screen_test.dart` (les deux pièges sont liés à la
  virtualisation/au défilement mais se corrigent différemment selon le type de scroll).
- `widgets/carte_alea_screen_test.dart` (J4.4-J4.13) — carte OpenStreetMap (`flutter_map`),
  marqueur + légende par type d'aléa, bouton de géolocalisation (accordée/refusée), feuille de
  produits d'assurance éligibles au tap sur une zone (J4.9 — produits listés et bouton
  « Simuler », ou état vide + lien « Voir tous les produits » quand aucun produit n'est
  éligible). Sans accès réseau réel aux tuiles (le mock HTTP de `flutter_test` renvoie 400 à
  toute requête — attendu, documenté en tête de fichier, ne fait pas échouer les tests puisque
  `TileLayer` absorbe les échecs de tuile sans lever). Deux pièges de test réels : (1)
  `find.byIcon(...)` est ambigu ici car la légende réutilise les mêmes icônes que les
  marqueurs, et `flutter_map` peut dessiner plusieurs copies d'un même marqueur (répétition
  horizontale de la carte à faible zoom) — corrigé en identifiant chaque marqueur par le
  message unique de son `Tooltip` (`"Ville — Type"`) plutôt que par icône ; (2) assertions GPS
  passées de `findsOneWidget` à `findsWidgets` pour la même raison de duplication.
  `GeolocatorPlatform.instance` substitué par un fake (`geolocator_platform_interface` ajouté
  en `dev_dependencies`) plutôt que d'appeler le vrai canal de plateforme, indisponible en
  test. Les boutons « Simuler »/« Voir tous les produits » ne sont testés que pour leur
  présence, pas leur tap : ils appellent `context.push()` (go_router), indisponible sans
  routeur réel dans ce test (même limite que les autres écrans de ce dossier). A révélé un vrai
  bug de production : la tuile d'action « Carte des aléas » sur `AssuranceScreen` pointait vers
  `AppRoutes.fichesProduit` (probablement un espace réservé le temps que l'écran carte
  existe) — corrigée pour pointer vers la nouvelle route `AppRoutes.carteAlea`. Étendu en J4.13
  (« couvrir le rendu de la carte ») avec des assertions dédiées sur `FlutterMap`/`TileLayer`/
  `CircleLayer`/`MarkerLayer` — le rendu de la carte elle-même était déjà exercé indirectement
  par les tests précédents, mais pas vérifié explicitement en tant que tel.
- `integration/carte_alea_produit_parametrique_scenario_test.dart` (J4.14, CDC §7.1 · T06) —
  parcours complet « zone à risque élevé sur la carte → produit paramétrique recommandé » :
  repère une zone `niveau_risque: eleve` parmi les 16 zones bundlées, simule une prime pour
  cette zone avec un Score Climat excellent, vérifie que le produit recommandé est bien
  paramétrique (`indiceDeclencheur` contient « paramétrique », `type` correspond au type d'aléa
  de la zone, `zonesEligibles` contient le pays de la zone) et que la prime obtenue est
  inférieure à la même simulation sans score (relie explicitement T06 au facteur Score Climat
  de J4.11-J4.12). Même limite que J3.9 : pas un `integration_test/` classique contre de vrais
  émulateurs (bloqué dans ce Codespace, voir plus bas), mais les vraies classes métier
  enchaînées dans l'ordre du parcours réel.
- `widgets/simulateur_assurance_screen_test.dart` (J4.10-J4.12) — ciblage GPS automatique de la
  zone (pré-remplissage vers la zone la plus proche de la position détectée, badge « Détectée
  via votre position », mais **seulement si la permission de localisation est déjà accordée** —
  ne déclenche jamais de demande de permission depuis cet écran, contrairement au bouton dédié
  de `CarteAleaScreen`) ; réduction de prime selon le Score Climat (score excellent → -25 %
  affiché, aucun score calculé → aucune ligne de réduction). Même fake `GeolocatorPlatform` que
  `carte_alea_screen_test.dart`.
- `widgets/messagerie_partenaire_screen_test.dart` (J5.4) — état vide (« Aucun message pour
  l'instant »), affichage d'un fil existant avec bulles alignées selon l'auteur (le nom de
  l'auteur n'apparaît que sur les messages qui ne sont pas les miens), envoi d'un message via le
  champ de texte + bouton d'envoi (écriture Firestore vérifiée, champ vidé après envoi). Même
  stratégie de fake `AuthViewModel`/`fake_cloud_firestore` que les autres tests widgets de ce
  dossier.
- `integration/messagerie_scenario_test.dart` (J5.9, CDC §7.1) — parcours complet de
  conversation entre le demandeur et le partenaire financeur assigné à sa demande : plusieurs
  messages échangés dans l'ordre via les vraies classes `MessagerieRepository`/
  `MessagerieViewModel`, ordre et auteur de chaque message vérifiés via le flux temps réel. Le
  volet « règles » du même scénario (accès réservé aux deux parties) est couvert séparément par
  `firestore-tests/rules.test.mjs` (34 tests, dont les cas assigné/non-assigné de J5.5) —
  `FakeFirebaseFirestore` n'applique aucune Security Rule, voir plus bas pour la même limite sur
  les autres scénarios d'intégration de ce dossier.
- `widgets/badges_screen_test.dart` (J5.16) — bouton d'export désactivé tant qu'aucun badge
  n'est obtenu, ouverture du choix JSON/PDF sinon, chaque choix appelle bien
  `exporterBadgesJson()`/`exporterBadgesPdf()` sur `FormationViewModel`. Même stratégie que
  `profil_screen_test.dart` (J3.6) pour éviter les canaux de plateforme réels de
  `share_plus`/`printing` : les deux méthodes sont surchargées en no-op tracé sur une
  sous-classe fake plutôt qu'appelées pour de vrai.
- `integration/regle_eligibilite_assure_climat_test.dart` (J5.18, CDC §7.1) —
  non-régression de la règle 4.1 (J5.14) : scénario complet où
  `CoursRepository.triggerAssureClimatBadge()` délivre réellement le badge, dont l'effet sur
  `scoreEligibiliteFinancement()` est ensuite vérifié (+10 pts, franchissement du seuil de 60,
  plafond à 100) — vient compléter les tests unitaires purs de la règle déjà écrits en J5.14
  (`test/utils/eligibilite_financement_test.dart`).
- `widget_test.dart` — smoke test du design system (`AppTheme` clair/sombre + composants `Ga*`
  se rendent sans exception). Ne boote **pas** `GreenAccessApp` en entier : dès son premier
  `build()`, l'app touche trois plugins Firebase réels (Auth, Firestore, Messaging) dont le
  mock fiable en test VM est fragile (canaux Pigeon spécifiques à chaque version) — un boot
  complet avec Firebase réel relève d'un test `integration_test` sur device/émulateur.
- `helpers/firebase_test_setup.dart` — mock des canaux `firebase_core`/`cloud_functions` legacy,
  utilisé par les tests de ViewModels (repositories injectés avec `fake_cloud_firestore`)

Exécutés automatiquement par `ci.yml` à chaque push.

**Cloud Functions — formule de scoring** (`functions/test/`, Node.js) :

```bash
cd functions && npm test
# ou, depuis la racine :
npm --prefix functions test
```

`functions/test/calculerScoreClimat.test.ts` — tests unitaires purs (`node --test` + `tsx`,
aucun émulateur requis, les vérifications d'auth rejettent avant tout accès Firestore) :
- `calculerScore` applique exactement les poids du CDC (0.25/0.20/0.20/0.20/0.15 + bonus
  additif), vérifié critère par critère et en combinaison.
- `co2ToScore` respecte les 6 paliers (0/20/40/60/80/100).
- Bornes 0-100 garanties même avec une entrée hors plage : écrire ce test a révélé que
  `calculerScore`/`resilienceToScore`/`certifToScore` ne plafonnaient que le *maximum*
  (`Math.min(100, …)`) sans jamais borner le *minimum* — une `resilience` négative (non
  revalidée côté client) pouvait produire un score total négatif. Corrigé avec
  `Math.max(0, …)` sur les trois fonctions.
- Arrondi à 1 décimale vérifié sur un cas réel tombant pile sur `.x5` (JS arrondit `.5` vers
  le haut).
- Contrôle d'accès : rejet `unauthenticated` (pas de `context.auth`) et `permission-denied`
  (`context.auth.uid` ≠ `data.userId`), via `firebase-functions-test.wrap()`.

`functions/test/triggers.test.ts` — mêmes fonctions exportées, mais wrappe des triggers
Firestore qui font de vraies lectures/écritures (`db = admin.firestore()`) : nécessite
l'émulateur (`npm --prefix functions run test:emulator`, dans `firebase emulators:exec`) :
- `onCourseCompleted` : crée le badge défini par le cours quand `badge_declenche` est vrai ;
  idempotent (un deuxième déclenchement ne recrée pas/n'écrase pas le badge existant) ; ne
  fait rien si le cours n'a pas de `badge_id` ou si le statut n'est pas `TERMINE`.
- `onDemandeSubmitted` : `getPartenaireFinanceurTokens()` (extraite de la fonction pour être
  testable) ne renvoie que les utilisateurs `role: partenaireFinanceur` ayant un
  `fcm_token`. Le trigger lui-même n'est exercé qu'avec zéro token éligible, pour ne
  **jamais** atteindre le vrai appel `admin.messaging()` — il n'existe pas d'émulateur FCM
  dans la Firebase Emulator Suite, un appel réel contacterait un serveur Google avec des
  identifiants de test invalides.

`functions/test/checkAlertesClimatiques.test.ts` :
- `detecterAlerte(precipMm, tempMax)` (extraite, fonction pure) : les 3 seuils du CDC
  (sécheresse `precip<2 && temp>35`, inondation `precip>80`, chaleur `temp>40`), y compris
  pile sur les bornes (strictes, donc non déclenchées) et la priorité en cas de cumul
  (inondation > chaleur > sécheresse).
- `checkAlertesClimatiques` bout en bout avec `axios.get` mocké (`t.mock.method(axios,
  'get', …)`) : lit une vraie zone dans `zones_alea` sur l'émulateur, vérifie que l'URL
  Open-Meteo appelée contient les bonnes coordonnées, et qu'une zone en échec réseau
  n'empêche pas le traitement des zones suivantes (`try/catch` par zone). Comme pour
  `onDemandeSubmitted`, aucun contrat actif n'est seedé dans la zone testée : la boucle de
  notification reste vide, `admin.messaging()` n'est jamais atteint.
- Pourquoi `axios.get` est mockable mais pas `admin.messaging` : un import par défaut
  (`import axios from "axios"`) pointe vers l'objet CJS mutable exporté par le package —
  mockable. Un import namespace (`import * as admin from "firebase-admin"`) produit un
  objet d'espace de noms ES figé par la spécification — `t.mock.method(admin, 'messaging', …)`
  échoue avec `TypeError: must be a method`, vérifié empiriquement avant d'écrire ces tests.

`functions/test/testEnv.ts` initialise `firebase-functions-test` en mode offline et fixe
`GCLOUD_PROJECT`/`FIRESTORE_EMULATOR_HOST` avant que `src/index.ts` ne s'importe, car ce
fichier appelle `admin.initializeApp()`/`admin.firestore()` à son chargement.

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

**Tests d'intégration Flutter** (`integration_test/`, package officiel `integration_test`) :

- `auth_repository_test.dart` — inscription/connexion/déconnexion, changement de mot de
  passe, suppression de compte, contre l'émulateur Auth + Firestore réels.
- `score_repository_test.dart` — calcule un vrai score via `calculerScoreClimat` sur
  l'émulateur Functions, sauvegarde/lecture d'historique sur l'émulateur Firestore.
- `financement_repository_test.dart` — soumission de demande, isolation par propriétaire,
  droits de mise à jour (propriétaire vs. brouillon), échéancier de remboursement.
- `cours_repository_test.dart` — repli sur les cours de démo, progression + déclenchement de
  badges (≥70% au quiz), idempotence du badge "Assuré Climat".

⚠️ **Ces 4 fichiers ne tournent pas encore en CI ni en local.** Cause identifiée avec
certitude, mais pas encore résolue : dans ce Codespace, `Firebase.initializeApp()` reste
indéfiniment en attente — testé et reproduit de deux façons :
1. `flutter test --tags=integration --platform chrome` (le harnais `package:test` générique).
2. `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/<file>.dart
   -d web-server --browser-name=chrome` avec `chromedriver` installé à la version exacte de
   Chrome — le mécanisme officiellement recommandé par l'équipe FlutterFire pour ce cas
   ([firebase/flutterfire#16727](https://github.com/firebase/flutterfire/issues/16727)).

Dans les deux cas, la page se charge correctement (titre "GreenAccess", `$dartMainExecuted` à
`true`), le CPU retombe à 0% (donc pas une compilation lente), et un `await import(...)` du SDK
JS Firebase exécuté **directement dans le même onglet Chrome** via une commande WebDriver
réussit **instantanément** — ce qui innocente le réseau, le CORS et Chrome. Le blocage se situe
donc dans l'interop Dart↔JS de `firebase_core_web` (ou juste après), pas dans le code de ce
dépôt ni dans l'infrastructure réseau/émulateurs. Pistes de reprise non testées faute de temps :
Chrome non-headless + DevTools attaché pour lire la console du navigateur, ou basculer ce test
précis sur un émulateur Android/iOS (ce que fait l'exemple officiel FlutterFire).

Le job CI dédié a été retiré (il échouait/expirait systématiquement) plutôt que laissé rouge en
permanence. `test_driver/integration_test.dart` et la dépendance `integration_test` restent en
place, prêts à resservir dès que ce blocage est levé.

Écrire ces 4 fichiers est resté utile indépendamment de leur exécution : la relecture attentive
du code qu'ils ont demandée a révélé 7 bugs réels, dont 5 de correspondance de schéma entre
`lib/repositories/score_repository.dart` et `functions/src/index.ts` (corrigés dans le même
commit) :
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

**Tests E2E** (`patrol_test/`, package [Patrol](https://patrol.leancode.co/), J6.1-J6.6, CDC
§7.1-§7.2) :

Contrairement à `integration_test/` ci-dessus (bloqué sur Chrome web), Patrol pilote un
**émulateur Android réel** — exactement la piste de reprise notée plus haut
(« basculer ce test précis sur un émulateur Android/iOS »). Non exécutable dans ce Codespace
(aucun `adb`/émulateur Android disponible ici — `flutter devices` n'y liste que `Linux (desktop)`
et `Chrome (web)`), mais exécutable en CI (`e2e.yml`, manuel, §6ter) sur un runner GitHub Actions
`ubuntu-latest` avec virtualisation matérielle, et en local sur un poste avec Android
Studio/un émulateur (`patrol test`).

- `app_test.dart` (J6.1) — test de fumée : prouve que le harnais Patrol est opérationnel
  (l'app démarre réellement — Firebase, émulateurs, routeur — jusqu'à l'écran de connexion),
  indépendamment de la logique d'un scénario métier.
- `t01_inscription_otp_test.dart` (J6.2, CDC §7.2 · T01) — inscription par numéro de téléphone
  jusqu'au tableau de bord, chronométrée (< 3 s entre la saisie du dernier chiffre du code et
  l'affichage du tableau de bord). Le code OTP n'est jamais un vrai SMS : récupéré via l'API
  REST de test de l'Auth Emulator (`emulator/v1/projects/{id}/verificationCodes` — non
  documentée publiquement mais stable, voir le code source de `firebase-tools`,
  `src/emulator/auth/operations.ts`), voir `patrol_test/helpers/e2e_helpers.dart`.
- `t04_score_insuffisant_test.dart` (J6.3, CDC §7.2 · T04) — un Score Climat < 60 bloque
  l'accès au financement (`FinancementScreen` : pas de bouton « Nouvelle demande », message
  « Score insuffisant ») et redirige vers la formation (`ScoreResultScreen`, bouton
  « Améliorer via formation » → `AppRoutes.courseList`). Compte de test et Score Climat semés
  directement via les vraies classes du repo (`AuthRepository.saveUserProfile`,
  `ScoreRepository.saveScore`) plutôt que rejoués à travers le formulaire de scoring en 5
  étapes — seule l'authentification (email/mot de passe) est pilotée depuis l'UI, l'inscription
  et le calcul de score ayant chacun leur propre test dédié ailleurs.
- `t05_demande_soumission_test.dart` (J6.4, CDC §7.2 · T05) — dépôt complet d'une demande de
  financement à travers le vrai formulaire à 7 étapes (même séquence de navigation que
  `test/widgets/demande_form_screen_test.dart`, pilotée ici sur un appareil réel), jusqu'au
  statut `soumis` vérifié directement en base. « + notification partenaire » (CDC) : un
  partenaire financeur est semé en précondition (sans `fcm_token`, aucun envoi FCM réel
  déclenché — il n'existe pas d'émulateur FCM dans la Firebase Emulator Suite, même contrainte
  que `functions/test/triggers.test.ts`) ; le ciblage des partenaires à notifier
  (`getPartenaireFinanceurTokens`) est déjà validé à ce niveau, ce scénario E2E valide ce que lui
  seul peut valider : le dépôt réel à travers l'UI jusqu'au statut persistant en base.
- `t07_hors_ligne_test.dart` (J6.5, CDC §7.2 · T07) — un cours consulté en ligne (semé
  directement dans Firestore, pas un cours de démo bundlé dans `CoursRepository` : ceux-ci ne
  transitent jamais par Firestore et rendraient le test du cache trivial) reste consultable une
  fois hors-ligne (`$.native.enableAirplaneMode()`), un quiz peut y être complété hors-ligne
  (écriture mise en file d'attente localement par le SDK Firestore), puis la progression se
  synchronise réellement au retour du réseau — confirmé par
  `FirebaseFirestore.instance.waitForPendingWrites()`, pas un simple délai arbitraire. Nécessite
  `FORCE_PERSISTENCE=true` (voir plus bas) : sans lui, le contenu ne survivrait jamais au passage
  hors-ligne — le point même de ce scénario.

En écrivant J6.2 (T01), deux bugs réels de production sont apparus et ont été corrigés :

1. **Écran mort.** Aucun bouton de l'app ne menait jamais à `OTPScreen`, alors que sa route
   (`/otp`) était déjà déclarée comme publique dans `routes.dart` — un écran accessible
   uniquement par navigation directe (deep link), jamais depuis l'interface. Corrigé en ajoutant
   un bouton « Continuer avec un numéro de téléphone » sur `LoginScreen`.
2. **Profil jamais créé.** `AuthViewModel.verifyOtp()` ne créait aucun profil Firestore pour un
   nouvel utilisateur inscrit par OTP : `isAuthenticated` passait à `true` mais `user` restait
   `null` indéfiniment, et `DashboardScreen`
   (`if (user == null) return const SizedBox.shrink();`) restait vide pour toujours — un
   nouvel inscrit par OTP n'avait absolument aucun moyen d'utiliser l'app. Corrigé en créant un
   profil minimal à la première connexion (`_createProfileFromPhone`, même pattern que
   `_createProfileFromGoogle` déjà en place pour la connexion Google), couvert par 3 nouveaux
   tests dans `auth_viewmodel_test.dart`.

Infrastructure native ajoutée pour Patrol (J6.1) : `pubspec.yaml` (`patrol`/`patrol_finders` +
bloc `patrol:` — `app_name`, `android.package_name`, `ios.bundle_id`),
`android/app/build.gradle.kts` (`testInstrumentationRunner`, `ANDROIDX_TEST_ORCHESTRATOR`),
`android/app/src/debug/AndroidManifest.xml` (`usesCleartextTraffic` — l'app rejoint le Firebase
Emulator Suite sur l'hôte du runner via `10.0.2.2` en HTTP, debug uniquement, jamais en
release), et `lib/main.dart` (`void main()` → `Future<void> main()` : un `void main() async`
ne peut pas être `await`é depuis l'extérieur — nécessaire pour que les tests attendent la fin
réelle du bootstrap Firebase avant d'interagir avec l'app ; aucun changement de comportement en
production). Bug réel trouvé au premier push de ce manifeste (CI cassée, `ci.yml` job « build apk
(debug) ») : le commentaire XML ajouté contenait littéralement `--dart-define`, un double tiret —
strictement interdit n'importe où dans un commentaire XML (`org.xml.sax.SAXParseException; The
string "--" is not permitted within comments.`), qui faisait échouer le manifest merger de
Gradle. Corrigé en reformulant le commentaire sans double tiret ; diagnostiqué dans ce Codespace
en forçant `JAVA_HOME` sur le JDK 17 installé ici (le JDK 21 par défaut n'expose pas `javac`,
un défaut d'installation propre à ce Codespace, sans rapport avec le bug lui-même) pour obtenir
la trace d'erreur complète, la CI ne montrant que le message générique tronqué
« Error parsing … AndroidManifest.xml » sans la cause exacte.

`FORCE_PERSISTENCE` (J6.5) : la persistance Firestore offline est désactivée par défaut avec les
émulateurs (`lib/main.dart`, `kUseEmulator`) pour éviter un cache local périmé entre deux
redémarrages d'émulateur en développement — un souci sans objet pour un run E2E Patrol isolé
(l'émulateur démarre une seule fois). Nouveau flag dédié `bool.fromEnvironment('FORCE_PERSISTENCE')`
pour activer la persistance spécifiquement pour T07 (`--dart-define=FORCE_PERSISTENCE=true`,
voir `.github/workflows/e2e.yml`) sans changer le comportement par défaut ailleurs.

**Traces de performance** (`lib/utils/perf_trace.dart`, J6.6, CDC §7.1 · T10) : SDK
`firebase_performance` intégré (`FirebasePerformance.instance.setPerformanceCollectionEnabled(true)`
dans `lib/main.dart`) avec des traces personnalisées sur 3 opérations clés —
`dashboard_load` (chargement initial de l'écran d'entrée après connexion),
`score_calculation` (`ScoreRepository.calculate`) et `demande_submission`
(`FinancementRepository.submit`). `tracedOperation()` est délibérément *best-effort* : elle
absorbe toute exception venant de `FirebasePerformance.instance` (qui exige
`Firebase.initializeApp()`, absent des dizaines de tests unitaires/widgets de ce dépôt qui
construisent des repositories directement avec `fake_cloud_firestore`, sans app Firebase réelle)
sans jamais faire échouer l'opération elle-même ni altérer sa valeur de retour — un repository
existant a donc pu être instrumenté sans casser un seul test déjà vert.

---

## 8. État d'avancement

> **Phase 2 — Socle de tests (plan d'implémentation CDC, tâches J2.1 à J2.27) : terminée.**
> Bilan : Security Rules Firestore (22 tests), Cloud Functions (28 tests), 4 suites
> d'intégration Flutter écrites (bloquées en exécution, voir §7), 87 tests unitaires de
> ViewModels, 6 widget tests, résumé de couverture lcov publié en CI (26 % mesurés, cible CDC
> §7.1 : 45-55 %, voir §6ter). 3 bugs réels corrigés côté frontend (aucun nouvel écran/
> fonctionnalité — cette phase visait la fiabilité, pas de nouveauté visible) : débordement de
> mise en page sur l'écran de connexion, validation jamais déclenchée sur le stepper de demande
> de financement, préremplissage de champ invisible à l'écran (détail §7). Prochaine étape :
> tâches de la phase suivante du plan d'implémentation (non encore communiquées).

> **Phase 3 — Sécurité & conformité RGPD (en cours) : J3.1-J3.9 codées et testées.**
> J3.1-J3.3 (connexion Google) : `AuthRepository.signInWithGoogle()`,
> `AuthViewModel.signInWithGoogle()` et le bouton « Continuer avec Google » sur `LoginScreen`
> sont en place. **Non fonctionnelle en pratique tant que J3.1 (action manuelle en console
> Firebase) n'est pas faite par le titulaire du projet** — détail en §5 « Connexion Google ».
> J3.4-J3.6 (export RGPD, droit à la portabilité) : `ExportRepository.exportUserData()` réunit
> les données personnelles à travers 9 collections/sous-collections, `export_formatters.dart`
> les convertit en PDF et CSV, bouton « Télécharger mes données » sur `ProfilScreen` — celle-ci,
> contrairement à Google Sign-In, est **fonctionnelle dès maintenant**, aucune action manuelle
> requise. J3.7-J3.8 (journal d'audit) : collection `audit_logs` en ajout seul et inviolable
> (règle Firestore : `update`/`delete` toujours refusés, même pour un admin), alimentée par
> `AuditRepository.logAction()` sur les 4 actions critiques du CDC §6 — soumission de demande
> (`FinancementRepository.submit()`), souscription (`AssuranceRepository.soumettreDossier()`),
> paiement (`PaiementRepository.initierPaiement()`), suppression de compte
> (`AuthRepository.deleteAccount()`, log écrit avant la suppression effective). J3.9 : scénario
> de bout en bout portabilité → effacement validé (détail §7, pourquoi ce n'est pas un
> `integration_test/` classique). Le tout couvert par les tests existants (§7), analyse
> statique propre.
>
> **Trouvé en marge (pas corrigé, hors périmètre J3.4-J3.9)** : `AuthRepository.deleteAccount()`
> ne supprime que `users/{uid}` et ses sous-collections `progress`/`badges` — les documents
> `scores_climat`, `demandes_financement` (+ `remboursements`), `paiements`,
> `contrats_assurance` et `sinistres` de l'utilisateur restent orphelins en Firestore après
> suppression du compte. Écart potentiel avec le droit à l'effacement (RGPD art. 17) — à
> traiter dans une tâche dédiée du plan d'implémentation, pas ici. Le test J3.9 documente ce
> comportement actuel (vérifie l'export et la suppression du compte lui-même) sans masquer
> cette limite ni prétendre qu'elle est résolue.

> **Phase 4 — Carte des aléas climatiques : moteur de cartographie, données et écran tous en
> place.** `flutter_map`/`latlong2` (déclarés depuis le J1) sont désormais réellement importés
> par `CarteAleaScreen` (`lib/views/assurance/carte_alea_screen.dart`, route
> `/assurance/carte`) : fond OpenStreetMap, un marqueur + un cercle de risque par zone (icône
> selon le type d'aléa — sécheresse/inondation/chaleur —, couleur selon le niveau de risque —
> faible/moyen/élevé), légende toujours visible, position GPS optionnelle de l'utilisateur
> (`geolocator`, permission demandée à la demande via le bouton de localisation, jamais au
> chargement de l'écran). `ZoneAleaModel.fromJson()` + `AssuranceRepository.getZonesAlea()`
> lisent `assets/data/zones_alea.json` — 16 zones réelles couvrant les 8 pays déjà gérés par
> l'app (Sénégal : Dakar, Thiès, Saint-Louis, Kaolack, Matam ; Bénin : Cotonou, Parakou ; Côte
> d'Ivoire, Mali, Burkina Faso, Niger, Togo, Guinée), utilisées en repli quand `zones_alea` est
> vide côté Firestore (même convention que les cours de démo de `CoursRepository`). A révélé un
> vrai bug de production, corrigé au passage : la tuile « Carte des aléas » sur
> `AssuranceScreen` pointait vers le mauvais écran (`fichesProduit`) — détail §7.
>
> **Phase 4 — J4.7-J4.9 : provider dédié, intégration au module et lien vers l'offre
> d'assurance.** J4.7 : `zonesAleaProvider` (`FutureProvider`, sans dépendre d'un `userId` —
> les zones ne sont propres à aucun utilisateur) expose désormais les zones à `CarteAleaScreen`
> indépendamment de `AssuranceViewModel`/`AssuranceState` (qui reste utilisé tel quel par
> `AssuranceScreen`/`FichesProduitScreen`, aucune régression). J4.8 : déjà acquis depuis
> J4.4-J4.6 (route `/assurance/carte` enregistrée sous la branche Assurance du shell, tuile
> « Carte des aléas » corrigée pour y pointer) — l'app n'a pas d'onglet dédié à la carte, elle
> est accessible en un tap depuis l'écran Assurance, ce qui correspond à « route + onglet »
> pour ce module (pas de tab bar interne au module). J4.9 : `produitsParZoneProvider`
> (`FutureProvider.family` par nom de zone) + tap sur un marqueur ouvre une feuille modale
> listant les produits d'assurance éligibles (`AssuranceRepository.getProduitsParZone`, déjà
> existant, jamais branché à une UI avant) avec bouton « Simuler », ou un état vide + lien vers
> le catalogue complet si aucun produit n'est éligible (attendu : `produits_assurance` n'a pas
> encore d'outil d'administration pour être peuplée, voir §8 « Fait »).
>
> **Phase 4 — J4.10-J4.12 : ciblage GPS du simulateur + Score Climat comme
> facteur de prime (CDC §4.1).** J4.10 : `ZoneAleaModel` gagne un champ `pays` (aligné sur les
> 8 pays déjà gérés par l'app) ; `SimulateurAssuranceScreen` détecte au chargement la zone la
> plus proche de la position GPS et pré-remplit le champ « Zone géographique » — **seulement
> si la permission de localisation est déjà accordée** (jamais de demande de permission
> déclenchée depuis cet écran, à la différence du bouton dédié de `CarteAleaScreen` ; un choix
> manuel de zone efface le badge « Détectée via votre position »). J4.11-J4.12 :
> `AssuranceViewModel.simulerPrime()` accepte désormais un `scoreClimat` optionnel et réduit la
> prime par paliers alignés sur `ScoreClimatModel.niveauFromScore` (mêmes bandes que le
> dashboard/l'éligibilité financement) : 0 % en insuffisant, 5 % en intermédiaire, 15 % en bon,
> 25 % en excellent — règle strictement incitative, jamais de majoration pour un score bas ou
> absent. `SimulateurAssuranceScreen` lit le score courant via `scoringViewModelProvider` et
> l'affiche comme une ligne « Réduction Score Climat » dédiée dans le résultat
> (`SimulationAssuranceResult.remiseScorePct`), pas seulement noyé dans le texte libre.

> **Phase 4 — J4.13-J4.15 (dernier lot) : couverture de test du rendu de la carte, scénario T06
> de bout en bout, et gestion admin des zones. Phase 4 terminée.** J4.13 : assertions dédiées
> sur `FlutterMap`/`TileLayer`/`CircleLayer`/`MarkerLayer` dans les tests existants — le rendu
> de la carte elle-même est désormais vérifié explicitement, pas seulement son contenu. J4.14 :
> scénario d'intégration T06 (§7.1) validant qu'une zone à risque élevé mène à un produit
> paramétrique recommandé, prime réduite par le Score Climat — détail §7. J4.15 :
> `AdminZonesAleaScreen` (`/admin/zones-alea`, accessible depuis Réglages admin → « Zones
> d'aléa climatique ») liste les zones actuelles et propose un import en un clic du jeu de
> données bundlé vers Firestore (`AssuranceRepository.importDefaultZonesAlea()`, upsert par
> `id` — un admin peut désormais mettre à jour les zones sans redéploiement de l'app) ainsi que
> la suppression d'une zone individuelle. Pas de formulaire d'édition/création manuelle
> (au-delà du périmètre de cette tâche à 0,75 h) — seuls l'import en masse et la suppression
> sont couverts, cohérent avec la priorité « Basse » et le fait qu'aucun autre écran admin de
> ce dépôt n'est encore couvert par un widget test (la couverture pour cet écran reste donc au
> niveau repository, comme documenté en §7, plutôt que d'introduire un nouveau précédent de
> test isolé).

> **Phase 5 — Messagerie & badges certifiés (J5.1-J5.18 terminées) : messagerie liée à une
> demande de financement, bout en bout, et émission de badges certifiés.** `MessageModel` +
> sous-collection
> `demandes_financement/{id}/messages` (J5.1), `MessagerieRepository` (J5.2 — envoi de message,
> flux temps réel via `streamMessages()`), `MessagerieViewModel` (J5.3 — s'abonne au flux dès
> sa création, comme `NotificationViewModel`), `MessageriePartenaireScreen` (J5.4 — interface de
> chat : bulles alignées par auteur, auto-scroll vers le dernier message, envoi via champ de
> texte, états vide/chargement/erreur ; accessible depuis une icône messagerie dans l'AppBar de
> `StatutDemandeScreen` côté demandeur et dans chaque carte de `AdminDemandesScreen` côté
> admin/partenaire, route `/financement/statut/:demandeId/messages`). Règle Firestore en ajout
> seul (même esprit que `audit_logs`), **restreinte en J5.5** : lecture/écriture réservées au
> propriétaire de la demande, à l'admin, et au partenaire financeur **spécifiquement assigné à
> cette demande précise** (`partenaire_id == request.auth.uid`) — la version initiale de
> J5.1-J5.2 autorisait par erreur n'importe quel compte `partenaireFinanceur`, pas seulement
> celui assigné à la demande ; corrigé avant tout déploiement, couvert par 2 tests dédiés
> (assigné vs. non-assigné) — création impossible en usurpant l'identité d'un autre auteur,
> modification/suppression toujours refusées une fois un message envoyé. Notification FCM au
> destinataire (J5.6) : Cloud Function `onMessageSent`, helper testable
> `getDestinataireContact()` détermine « l'autre partie » de la conversation (le partenaire
> assigné si l'auteur est le demandeur, le demandeur sinon) et son contact (token FCM + numéro
> de téléphone), aucune notification si aucun partenaire n'est encore assigné ou si le
> destinataire n'a ni l'un ni l'autre. Canal de secours WhatsApp (J5.7, CDC §2.3) :
> `WhatsAppChannel` (interface) + `MockWhatsAppChannel` (trace chaque envoi, aucun appel réseau
> réel, en attendant l'approvisionnement d'un compte WhatsApp Business API réel). Sélection
> automatique de canal (J5.8) : `NotificationService.sendBestEffort()` tente FCM en premier,
> se rabat sur WhatsApp si l'envoi échoue ou si aucun token FCM n'est disponible (zone à faible
> signal) — jamais aucune notification levée en erreur, seulement le canal effectivement utilisé
> renvoyé (`"fcm" | "whatsapp" | "none"`) ; câblé dans `onMessageSent`, qui journalise le canal
> retenu. Test d'intégration messagerie (J5.9, CDC §7.1) : le volet « règles » (accès réservé au
> propriétaire, à l'admin, au partenaire assigné) est validé contre le vrai moteur de règles
> Firestore dans `firestore-tests/rules.test.mjs` (34 tests, dont les cas assigné/non-assigné de
> J5.5) ; le volet « flux » est validé côté Flutter par un scénario bout en bout — demandeur et
> partenaire échangent plusieurs messages via les vraies classes `MessagerieRepository`/
> `MessagerieViewModel`, ordre et auteur de chaque message vérifiés.
>
> **Badges certifiés OpenBadge (J5.10-J5.12, CDC §2.3 · §3 M1 · T02).** `BadgeIssuer`
> (interface) + `MockOpenBadgeIssuer` (J5.10) : émet une assertion
> [OpenBadge v2](https://www.imsglobal.org/spec/ob/v2p0) minimale (`@context`, `type`,
> `recipient`, `badge`, `issuedOn`, `verification`) et une URL d'assertion, sans appel réseau
> réel en attendant l'approvisionnement d'un compte OpenBadge Factory/Badgr — chaque émission
> tracée dans `issuedBadges`, même pattern que `MockWhatsAppChannel`. Champ `openbadge_url`
> renseigné dans `users/{id}/badges/{id}` (J5.11) — `BadgeModel` (`lib/models/badge_model.dart`)
> exposait déjà ce champ côté client depuis sa création, il restait codé en dur à `null` côté
> Cloud Function. Branché sur `onCourseCompleted` (J5.12) : un badge est désormais délivré avec
> son assertion réelle (mock) plutôt qu'un simple document vide. En touchant ce déclencheur, un
> deuxième bug de nommage de champ est apparu, de la même famille que `partenaire_id`/
> `partenaireId` (J5.5) : le badge était écrit avec `dateObtention` (camelCase) alors que
> `BadgeModel.fromFirestore` lit exclusivement `date_obtention` (snake_case) — un badge délivré
> par ce déclencheur s'affichait donc avec `isObtenu` toujours faux côté app, en silence.
> Corrigé au passage.
>
> **Incitations croisées entre modules (J5.13-J5.15).** Badge « Assuré Climat » délivré à la
> souscription d'une assurance (J5.13, CDC §3 M4) : déjà câblé dans
> `AssuranceRepository.soumettreDossier()` avant cette tâche (héritage d'un travail antérieur à
> la Phase 5) — comme il n'avait encore jamais de couverture de test directe, un test dédié a été
> ajouté (`test/repositories/assurance_repository_test.dart`) pour le figer. Règle 4.1 (J5.14,
> CDC §4.1) : le badge Assuré Climat bonifie de +10 pts (plafonné à 100) le score d'éligibilité
> au financement — fonction pure `scoreEligibiliteFinancement()`
> (`lib/utils/eligibilite_financement.dart`), même esprit que la règle symétrique côté prime
> d'assurance (`_remiseScoreClimat`, J4.11-J4.12) : le Score Climat influence l'assurance, être
> assuré influence en retour le financement. Appliquée à la fois à l'écran `FinancementScreen`
> (verrou d'accès + mention « +10 pts grâce au badge Assuré Climat ») et au champ
> `scoreEligibilite` stocké sur la demande à sa soumission (`DemandeFormScreen`). Badge
> « Financé Vert » délivré à l'approbation d'une demande (J5.15, CDC §4.3) :
> `CoursRepository.triggerFinanceVertBadge()`, branché dans `AdminViewModel.approuverDemande()`
> juste après l'envoi de la notification d'approbation, même pattern idempotent
> (`existing.exists`) que le badge Assuré Climat.
>
> **Export de badges + tests de non-régression (J5.16-J5.18).** Écran `BadgesScreen` : bouton
> d'export (icône AppBar, désactivé tant qu'aucun badge n'est obtenu) ouvrant un choix
> JSON/PDF, même stratégie de dialogue que l'export RGPD de `profil_screen.dart` (J3.4-J3.5).
> `lib/utils/badge_export_formatters.dart` (J5.16, CDC §5) : `buildBadgesJson()` inclut
> `openbadge_url` — le lien vers l'assertion OpenBadge v2 certifiée (J5.10-J5.12) quand
> disponible, la preuve vérifiable hors de l'app que ce format permet d'emporter ;
> `buildBadgesPdf()` génère un résumé imprimable. Les deux méthodes vivent sur
> `FormationViewModel` (badges déjà chargés en état) plutôt que sur un `ExportViewModel` dédié.
>
> Scénario T02 (J5.17, CDC §7.1 · T02 — « badge délivré via le service + score incrémenté ») :
> en l'écrivant, un vrai bug de production est apparu dans `getBonusFormation()`
> (`functions/src/index.ts`, calcul serveur du bonus de score lié aux formations/badges,
> §4.4) — son filtre `.where("dateObtention", "!=", null)` ciblait un champ en camelCase
> qu'aucun badge n'écrit jamais (tous les déclencheurs, client comme Cloud Function, stockent
> `date_obtention` en snake_case). Ce filtre excluait donc silencieusement TOUS les badges de
> ce calcul depuis toujours : le bonus de +3 pts par badge n'a jamais réellement été appliqué
> côté serveur (le chemin de calcul faisant foi, §4.4), bien que le repli local Dart
> (`ScoreRepository._getBonusFormation()`, sans ce filtre) l'ait toujours appliqué correctement
> — une divergence silencieuse entre le calcul serveur et son propre repli de secours. Corrigé
> en retirant le filtre (chaque badge a de toute façon systématiquement une date d'obtention
> dès sa création, aucun état à filtrer), couvert par un test de régression dédié puis par le
> scénario T02 complet (badge livré par `onCourseCompleted`/`BadgeIssuer` → `getBonusFormation()`
> → `calculerScoreClimat()` bout en bout).
>
> Test de la règle +10 (J5.18, CDC §7.1) : scénario d'intégration dédié
> (`test/integration/regle_eligibilite_assure_climat_test.dart`) enchaînant les vraies classes
> (`CoursRepository.triggerAssureClimatBadge()` → `scoreEligibiliteFinancement()`), au-delà des
> tests unitaires purs déjà écrits en J5.14 — garde-fou contre toute régression de cette
> incitation croisée.

> **Phase 6 — E2E, performance & livraison (démarrée) : J6.1-J6.9, infrastructure Patrol,
> scénarios E2E T01/T04/T05/T07, traces de performance.** Patrol (J6.1, CDC §7.1) configuré et
> exécutable en CI sur un émulateur Android réel (`e2e.yml`, manuel — §6ter) ; non exécutable
> dans ce Codespace (aucun `adb`/émulateur disponible ici, voir §7). Scénario T01 (J6.2, CDC
> §7.2 · T01) : inscription par OTP jusqu'au tableau de bord en moins de 3 s — a révélé et
> corrigé deux bugs réels : un écran `OTPScreen` jusque-là inaccessible depuis l'interface
> (route publique déclarée, mais aucun bouton n'y menait) et `AuthViewModel.verifyOtp()` qui ne
> créait jamais de profil Firestore pour un nouvel inscrit par OTP (tableau de bord vide
> indéfiniment). Scénario T04 (J6.3, CDC §7.2 · T04) : score < 60 → accès au financement bloqué
> + redirection vers la formation. Scénario T05 (J6.4, CDC §7.2 · T05) : dépôt complet d'une
> demande de financement (formulaire à 7 étapes) jusqu'au statut SOUMIS, avec un partenaire
> financeur en précondition de notification. Scénario T07 (J6.5, CDC §7.2 · T07) : un cours
> consulté en ligne reste utilisable hors-ligne (cache Firestore), un quiz peut y être complété
> hors-ligne, la progression se synchronise réellement au retour du réseau — a nécessité un
> nouveau flag `FORCE_PERSISTENCE` pour activer la persistance offline avec les émulateurs
> (désactivée par défaut dans ce cas précis, voir §7). Traces de performance (J6.6, CDC §7.1 ·
> T10) : SDK `firebase_performance` intégré, 3 opérations clés instrumentées de façon
> best-effort (`dashboard_load`, `score_calculation`, `demande_submission`). Un bug réel
> supplémentaire (double tiret interdit dans un commentaire XML, cassant le manifest merger de
> Gradle) a été trouvé et corrigé au premier push de l'infrastructure Patrol — détail complet
> (bugs, infrastructure native Android ajoutée, limite Codespace) en §7.
>
> Pagination du tableau de bord (J6.7, CDC §7.1 · T10) : `FormationViewModel.loadCourses()`
> enchaînait 3 lectures Firestore indépendantes (cours, progression, badges) en séquence au
> lieu de les paralléliser — corrigé via `Future.wait`, réduit d'environ 3x le temps passé en
> aller-retour réseau au premier rendu. Bornes défensives (`.limit(200)`) ajoutées sur les 3
> requêtes, sans effet sur le catalogue actuel (quelques dizaines de cours), pour éviter une
> dégradation si le catalogue grossit significativement — une pagination complète par curseur
> n'était pas nécessaire à l'échelle réelle de l'app et aurait cassé le calcul des agrégats
> (score de progression, XP total) qui dépendent de l'ensemble des documents, pas d'une page.
>
> Nettoyage des lints (J6.8, CDC §9) : `flutter analyze` ne comptait déjà aucun avertissement
> réel (uniquement des infos `deprecated_member_use` pré-existantes) — 10 occurrences de
> `DropdownButtonFormField`/`TextFormField` migrées de `value:` vers `initialValue:` (renommage
> mécanique sûr, même sémantique, explicitement recommandé par le message de dépréciation
> Flutter lui-même), ramenant le compte de 21 à 11 infos. Les infos restantes (migration
> `Switch.activeColor`→`activeThumbColor`, `Radio`/`RadioListTile`→`RadioGroup`,
> `ReorderableListView.onReorder`→`onReorderItem`) changent la forme de l'API (pas un simple
> renommage) et restent hors du périmètre de cette tâche à 0,5 h — délibérément non touchées
> pour éviter un risque de régression de comportement sur des écrans non couverts par un widget
> test.
>
> Documentation (J6.9) : `CHANGELOG.md` créé (nouveau fichier, format condensé par phase plutôt
> que tâche par tâche — le détail complet reste ici, en §7/§8), section 8 de ce README tenue à
> jour au fil de l'eau depuis le début du projet.

> **Refonte frontend premium (mission dédiée, hors plan CDC J1-J6) — Phase 1 (audit) et
> Phase 2 (plan classé CRITIQUE/IMPORTANT/NICE TO HAVE) livrées, Phase 3 démarrée.** L'app
> étant déjà fonctionnellement complète (Phases 1-6 ci-dessus), cette mission vise une passe
> de qualité visuelle/UX sur les 32 écrans encore hors du design system « Organic Fintech »
> (9/41 déjà couverts, voir plus haut), sans toucher la logique métier/Firebase/Riverpod.
> L'audit a chiffré l'écart : 45 littéraux de couleur sur 16 fichiers, 8/10 ViewModels
> affichant une erreur technique brute (`e.toString()`), 28/39 `IconButton` sans tooltip,
> 1/41 écran avec un état de chargement squelette. Le plan retenu (classement détaillé non
> reproduit ici, voir l'échange qui l'a validé) ouvre l'implémentation par le Design System
> lui-même : **étape 1 (ce commit)** ajoute les composants qui manquaient pour retoucher les
> écrans legacy sans dupliquer de nouveaux widgets ad-hoc — `GaListTile` (remplace les
> `ListTile` décorés à la main), `GaStatusTimeline` (frise de statut, financement/sinistre),
> `GaFilterBar` (recherche + chips), `GaFormCard` (section de formulaire titrée), `GaErrorView`
> (bandeau d'erreur traduit) — et surtout `lib/utils/error_mapper.dart`
> (`mapErrorToMessage()`), point d'entrée unique de traduction erreur technique → message
> utilisateur, généralisant le pattern déjà validé dans `AuthViewModel._mapError` /
> `AdminViewModel._msg` (switch sur le `.code` de `FirebaseAuthException`/`FirebaseException`,
> repli générique sinon). Aucun écran existant n'est encore retouché à ce stade — ces
> composants seront consommés au fil des étapes suivantes (navigation, Dashboard, Formation,
> Score Climat, Financement, Assurance, Notifications, Profil), chacune committée séparément.
>
> **Étape 2 — Navigation.** `MainShell` (`lib/views/shell/main_shell.dart`, coquille des 5
> onglets partagée par **tous** les écrans, vitrine et legacy) utilisait un
> `BottomNavigationBar` recoloré à la main via `AppColors`, alors que `AppTheme` définit déjà
> un `navigationBarTheme` (Material 3) complet sur les tokens — jamais consommé. Bascule vers
> `NavigationBar`, sans aucun changement de route (`navigationShell.goBranch(...)` identique) ;
> léger `GaShadows.e1` ajouté au-dessus de la barre pour la détacher du fond crème
> (`background` ≠ `surface`), cohérent avec le vocabulaire d'élévation du reste du design
> system. Aucun test ne référençait `MainShell` (écart déjà connu, non comblé ici — risque jugé
> faible : composant de navigation pur, aucune logique). `flutter analyze` propre, 229 tests
> toujours au vert, `flutter build web --release` vérifié.

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
  22 composants `Ga*` (dont `GaListTile`/`GaStatusTimeline`/`GaFilterBar`/`GaFormCard`/
  `GaErrorView`, ajoutés pour la refonte frontend, étape « Design System »), jauge de score
  animée, transitions de route par flux ; 9 écrans vitrine refondus bout en bout (auth complet,
  dashboard, parcours scoring)
- **CI/CD GitHub Actions** : pipeline `analyze → test → build web / apk debug` sur chaque push
  + workflow de build APK release à la demande (§6ter)
- Chaîne Android mise à niveau pour Flutter 3.47 (Gradle/AGP/Kotlin)
- 229 tests `flutter test` répartis sur 4 catégories (détail complet §7) : ~106 tests unitaires
  de ViewModels (9 fichiers — Admin/Assurance/Auth/Financement/Formation/Messagerie/
  Notification/Partenaire/Scoring, dont le badge Financé Vert à l'approbation J5.15, et la
  création de profil à la première connexion par OTP J6.2), 11 widget tests (Login, ScoringForm,
  ScoreResult, DemandeForm, Dashboard, Financement, Profil, CarteAlea, SimulateurAssurance,
  MessageriePartenaire, Badges — validation, navigation par étapes, verrou de financement CDC
  §4.1 et son bonus du badge Assuré Climat (J5.14), connexion Google, entrée vers OTPScreen
  (J6.2), export RGPD, rendu de carte, ciblage GPS, réduction de prime par score, interface de
  chat (état vide, bulles par auteur, envoi), export de badges JSON/PDF (J5.16), états
  d'erreur/chargement), des
  tests de repositories/fonctions utilitaires purs ciblant directement le code métier sans
  passer par un ViewModel (`ExportRepository`, `AuditRepository`, `AssuranceRepository` — dont
  le badge Assuré Climat à la souscription, J5.13 —, `CoursRepository` — badges Assuré
  Climat/Financé Vert, nouveau fichier de test —, `MessagerieRepository`,
  `export_formatters.dart`, `eligibilite_financement.dart` — règle 4.1, J5.14 —,
  `badge_export_formatters.dart` — export JSON/PDF, J5.16 —, `perf_trace.dart` — traces
  best-effort, J6.6 —, `error_mapper.dart` — mapping d'erreur centralisé, refonte frontend
  étape « Design System »), 9 tests de composants du design system (`GaListTile`,
  `GaStatusTimeline`, `GaFilterBar`, `GaFormCard`, `GaErrorView` — nouveaux composants de la
  même étape), et 4
  scénarios d'intégration (RGPD export+suppression J3.9, carte→produit paramétrique T06 J4.14,
  conversation demandeur/partenaire J5.9, règle +10 d'éligibilité du badge Assuré Climat J5.18)
  + smoke test du design system, exécutés en CI ; ont révélé et corrigé 3 bugs réels de
  frontend (débordement de layout, validation jamais déclenchée sur un stepper 7 étapes,
  pré-remplissage de champ invisible à
  l'écran)
- Couverture de code lcov calculée et publiée en résumé de CI à chaque build (§6ter) — 26 %
  mesurés, sous la cible CDC §7.1 (45-55 %), écart noté pour prioriser les prochaines tâches
  de tests
- Tests des Firestore Security Rules (`firestore-tests/`, 34 tests) contre l'émulateur, en CI
  (isolation utilisateur, anti-élévation de rôle, droits partenaireFinanceur/partenaireAssureur,
  cloisonnement Assurance/paiements/remboursements, accès admin-only, journal d'audit
  `audit_logs` en ajout seul et inviolable, messagerie de demande de financement en ajout
  seul réservée au propriétaire/admin/partenaire financeur spécifiquement assigné à la
  demande — assigné vs. non-assigné, J5.5) — voir §6ter
- Tests des Cloud Functions (`functions/test/`, 45 tests), en CI — formule `calculerScoreClimat`
  (poids CDC exacts, bornes 0-100, arrondi, contrôle d'accès), triggers `onCourseCompleted`
  (badge + idempotence + émission OpenBadge mockée, J5.10-J5.12), `onDemandeSubmitted`
  (ciblage partenaires financeurs), `onMessageSent` (J5.6 — notification au destinataire d'un
  message), canal de secours WhatsApp mocké + sélection automatique de canal FCM→WhatsApp
  (J5.7-J5.8), `getBonusFormation` + scénario T02 (J5.17 — badge délivré via le service, puis
  score incrémenté bout en bout jusqu'à `calculerScoreClimat`) et `checkAlertesClimatiques`
  (seuils sécheresse/inondation/chaleur, Open-Meteo mocké) ; ont révélé et corrigé 2 bugs réels
  côté fonctions : une borne basse manquante (score négatif possible avec une entrée hors
  plage) et, en écrivant le scénario T02 (J5.17), un filtre Firestore ciblant un champ en
  camelCase (`dateObtention`) que plus aucun badge n'écrit depuis longtemps (snake_case
  `date_obtention`) — le bonus de +3 pts/badge du score n'était donc jamais réellement
  appliqué côté serveur, malgré un repli local Dart qui, lui, fonctionnait correctement
  (§4.4)
- Tests d'intégration Flutter écrits (`integration_test/`) pour AuthRepository,
  ScoreRepository, FinancementRepository et CoursRepository contre les émulateurs — leur
  écriture a révélé et corrigé 7 bugs réels de correspondance de schéma/config (client ↔
  Cloud Function, index Firestore, version Node) ; **pas encore exécutables en CI**
  (`Firebase.initializeApp()` bloque indéfiniment sous ce Codespace — voir §7)
- Mécanisme de bascule d'environnement (`APP_ENV=dev/prod`, `lib/firebase_env.dart`) — en
  attente d'un second projet Firebase de dev pour devenir effectif (voir §5)

**À faire / en cours**

- Suite de la refonte visuelle : retrofit des écrans legacy restants, retrait de
  `percent_indicator`, sélecteur de thème dans Profil
- Activer le plan Blaze sur `greenaccess-16d25` puis `firebase deploy` (functions/rules/index)
  — bloquant, aucun contournement (§5) ; développement des functions en attendant via les
  émulateurs Firebase
- Activer le fournisseur Google dans Firebase Authentication + enregistrer le Web Client ID
  et l'empreinte SHA-1 Android (J3.1) — bloquant pour que la connexion Google (J3.2-J3.3,
  code déjà en place) fonctionne réellement ; détail §5 « Connexion Google »
- Créer un projet Firebase de dev distinct et y brancher `firebase_env.dart`
- Retirer le calcul de score de secours côté client (`ScoreRepository`), non conforme au CDC
- Débloquer l'exécution de `integration_test/` (Chrome non-headless + DevTools) — voir le
  diagnostic détaillé en §7 ; la piste « émulateur Android/iOS » qui y était notée est
  désormais couverte séparément par les tests E2E Patrol (`patrol_test/`, J6.1-J6.3, §7),
  mais les 4 fichiers `integration_test/` eux-mêmes (contre Chrome web) restent bloqués tels quels
- Couverture de tests à étendre : widgets (parcours E2E désormais couverts, T01/T04 — §7)
- Intégration réelle des API Mobile Money (actuellement flux applicatif)
- `AuthRepository.deleteAccount()` laisse des données orphelines (`scores_climat`,
  `demandes_financement`, `paiements`, `contrats_assurance`, `sinistres`) — trouvé en marge de
  J3.4, écart potentiel avec le droit à l'effacement RGPD (art. 17), détail §8

> Suivi détaillé tâche par tâche : plan d'implémentation (classeur xlsx partagé séparément,
> non versionné dans ce dépôt).

---

## 9. Conventions

- Code et commentaires en **français**
- Un modèle = une classe immuable + `fromMap` / `toMap` ; enums de statut préfixés par le domaine
- Pas d'appel Firestore direct depuis une `View` — toujours passer par un `Repository` via un `ViewModel`
- Lint : `flutter_lints` (`analysis_options.yaml`)
