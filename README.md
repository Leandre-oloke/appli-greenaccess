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
├── theme.dart                # AppTheme.light
├── firebase_options.dart     # config Firebase générée par FlutterFire (clés client)
│
├── core/
│   ├── constants/app_colors.dart
│   ├── providers/prefs_provider.dart      # SharedPreferences injecté via override
│   └── widgets/connectivity_banner.dart   # bannière hors-ligne (connectivity_plus)
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

---

## 3. Stack technique

- **Flutter** SDK `^3.8.1` (canal stable)
- **Firebase** : `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_messaging`
- **État** : `flutter_riverpod` `^2.5`
- **Navigation** : `go_router` `^14.2`
- **UI** : `fl_chart`, `percent_indicator`, Material 3
- **Divers** : `shared_preferences`, `intl` (locale `fr`), `url_launcher`, `file_picker`, `image_picker`, `geolocator`, `connectivity_plus`, `pdf` + `printing`, `equatable`
- **Backend** : Cloud Functions (TypeScript) dans `functions/`
  - `calculerScoreClimat` (callable, contrôle d'accès)
  - `onCourseCompleted` (trigger Firestore)
  - `onDemandeSubmitted` (trigger Firestore)
  - `checkAlertesClimatiques` (planifiée / pub-sub)
- **Règles de sécurité** : `firestore.rules`, `storage.rules`, index dans `firestore.indexes.json`

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

> `lib/firebase_options.dart` **est** versionné (il ne contient que des clés client Firebase, protégées par les règles Firestore/Storage). Le dépôt GitLab est **privé** — ne pas le rendre public en l'état.

Régénérer la config si besoin :

```bash
flutterfire configure
```

---

## 6. Installation & lancement

```bash
# 1. Cloner
git clone https://gitlab.com/nev-consulting-group/greenacces.git
cd greenacces

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
- `helpers/firebase_test_setup.dart` — setup Firebase pour les tests (avec `fake_cloud_firestore`)

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
- Premiers tests unitaires de ViewModels

**À faire / en cours**

- Finaliser la configuration Firebase par environnement (dev / prod)
- Couverture de tests à étendre (repositories, widgets, parcours d'intégration)
- Intégration réelle des API Mobile Money (actuellement flux applicatif)
- CI/CD GitLab (lint + `flutter test` + build)

---

## 9. Conventions

- Code et commentaires en **français**
- Un modèle = une classe immuable + `fromMap` / `toMap` ; enums de statut préfixés par le domaine
- Pas d'appel Firestore direct depuis une `View` — toujours passer par un `Repository` via un `ViewModel`
- Lint : `flutter_lints` (`analysis_options.yaml`)
