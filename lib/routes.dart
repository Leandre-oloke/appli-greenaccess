import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/user_model.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/assurance/assurance_screen.dart';
import 'views/assurance/fiches_produit_screen.dart';
import 'views/assurance/mes_contrats_screen.dart';
import 'views/assurance/simulateur_assurance_screen.dart';
import 'views/assurance/sinistre_form_screen.dart';
import 'views/assurance/souscription_screen.dart';
import 'views/auth/login_screen.dart';
import 'views/auth/onboarding_screen.dart';
import 'views/auth/otp_screen.dart';
import 'views/auth/register_screen.dart';
import 'views/auth/splash_screen.dart';
import 'views/dashboard/dashboard_screen.dart';
import 'views/financement/demande_form_screen.dart';
import 'views/financement/financement_screen.dart';
import 'views/financement/partenaires_screen.dart';
import 'views/financement/paiement_screen.dart';
import 'views/financement/remboursements_screen.dart';
import 'views/financement/statut_demande_screen.dart';
import 'views/formation/badges_screen.dart';
import 'views/formation/course_detail_screen.dart';
import 'views/formation/course_list_screen.dart';
import 'views/formation/quiz_screen.dart';
import 'views/profil/profil_screen.dart';
import 'views/scoring/historique_score_screen.dart';
import 'views/scoring/score_result_screen.dart';
import 'views/scoring/scoring_form_screen.dart';
import 'views/shell/main_shell.dart';
import 'views/admin/admin_shell.dart';
import 'views/admin/admin_dashboard_screen.dart';
import 'views/admin/admin_formations_screen.dart';
import 'views/admin/admin_course_form_screen.dart';
import 'views/admin/admin_lecons_screen.dart';
import 'views/admin/admin_contrats_screen.dart';
import 'views/admin/admin_users_screen.dart';
import 'views/admin/admin_demandes_screen.dart';
import 'views/admin/admin_analytics_screen.dart';
import 'views/admin/admin_partenaires_screen.dart';
import 'views/admin/admin_settings_screen.dart';
import 'views/notifications/notifications_screen.dart';

// ── Chemins ───────────────────────────────────────────────────────────────────

class AppRoutes {
  static const splash      = '/';
  static const onboarding  = '/onboarding';
  static const login       = '/login';
  static const register    = '/register';
  static const otp         = '/otp';
  static const dashboard   = '/dashboard';
  static const profil      = '/profil';
  static const courseList  = '/formation';
  static const badges      = '/formation/badges';
  static const scoringForm = '/scoring';
  static const scoreResult = '/scoring/result';
  static const scoreHistory = '/scoring/history';
  static const financement  = '/financement';
  static const demandeForm  = '/financement/demande';
  static const partenaires  = '/financement/partenaires';
  static const assurance    = '/assurance';
  static const fichesProduit       = '/assurance/produits';
  static const simulateurAssurance = '/assurance/simulateur';
  static const souscription        = '/assurance/souscrire';
  static const mesContrats         = '/assurance/contrats';
  static String sinistreForm(String contratId) => '/assurance/sinistre/$contratId';
  static const notifications       = '/dashboard/notifications';

  static String courseDetailPath(String id)  => '/formation/$id';
  static String quizPath(String id)          => '/formation/$id/quiz';
  static String statutDemandePath(String id) => '/financement/statut/$id';
  static String remboursementsPath(String id) => '/financement/statut/$id/remboursements';
  static String paiementPath(String demandeId, String echeanceId) =>
      '/financement/statut/$demandeId/remboursements/$echeanceId/payer';

  // ── Admin ──────────────────────────────────────────────────────────────────
  static const adminDashboard  = '/admin';
  static const adminFormations = '/admin/formations';
  static const adminUsers      = '/admin/users';
  static const adminDemandes   = '/admin/demandes';
  static const adminContrats   = '/admin/contrats';
  static const adminPartenaires = '/admin/partenaires';
  static const adminAnalytics  = '/admin/analytics';
  static const adminSettings   = '/admin/settings';
  static const adminCourseNew  = '/admin/formations/new';
  static String adminCourseEdit(String id)              => '/admin/formations/$id';
  static String adminCourseLecons(String courseId)      => '/admin/formations/$courseId/lecons';
  static String adminLeconNew(String courseId)          => '/admin/formations/$courseId/lecons/new';
  static String adminLeconEdit(String courseId, String leconId) => '/admin/formations/$courseId/lecons/$leconId';
}

// ── RouterNotifier ────────────────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authViewModelProvider, (_, __) {
      notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authViewModelProvider);
    final isAuth    = authState.isAuthenticated;
    final isAdmin   = authState.user?.role == UserRole.admin;
    final path      = state.uri.path;

    const publicPaths = [
      AppRoutes.splash,
      AppRoutes.onboarding,
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.otp,
    ];

    if (path == AppRoutes.splash) return null;
    if (!isAuth && !publicPaths.contains(path)) return AppRoutes.login;
    if (isAuth && (path == AppRoutes.login || path == AppRoutes.register)) {
      return isAdmin ? AppRoutes.adminDashboard : AppRoutes.dashboard;
    }
    if (!isAdmin && path.startsWith('/admin')) return AppRoutes.dashboard;
    if (isAdmin && path == AppRoutes.dashboard) return AppRoutes.adminDashboard;

    return null;
  }
}

// ── Transition rapide ─────────────────────────────────────────────────────────

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 100),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

// ── Provider du router ────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ── Écrans publics ─────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.splash,     builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.onboarding, pageBuilder: (_, s) => _fadePage(s, const OnboardingScreen())),
      GoRoute(path: AppRoutes.login,      pageBuilder: (_, s) => _fadePage(s, const LoginScreen())),
      GoRoute(path: AppRoutes.register,   pageBuilder: (_, s) => _fadePage(s, const RegisterScreen())),
      GoRoute(path: AppRoutes.otp,        pageBuilder: (_, s) => _fadePage(s, const OTPScreen())),

      // ── Scoring (hors shell — flow plein écran sans bottom nav) ────────────
      GoRoute(
        path: AppRoutes.scoringForm,
        pageBuilder: (_, s) => _fadePage(s, const ScoringFormScreen()),
        routes: [
          GoRoute(path: 'result',  pageBuilder: (_, s) => _fadePage(s, const ScoreResultScreen())),
          GoRoute(path: 'history', pageBuilder: (_, s) => _fadePage(s, const HistoriqueScoreScreen())),
        ],
      ),

      // ── Shell utilisateur (StatefulShellRoute → keep-alive par onglet) ─────
      //
      // Chaque branche conserve son état et son stack en mémoire.
      // Changer d'onglet est instantané (IndexedStack).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // Branche 0 — Accueil
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (_, __) => const DashboardScreen(),
              routes: [
                GoRoute(
                  path: 'notifications',
                  pageBuilder: (_, s) => _fadePage(s, const NotificationsScreen()),
                ),
              ],
            ),
          ]),

          // Branche 1 — Formation
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.courseList,
              builder: (_, __) => const CourseListScreen(),
              routes: [
                GoRoute(path: 'badges', pageBuilder: (_, s) => _fadePage(s, const BadgesScreen())),
                GoRoute(
                  path: ':courseId',
                  pageBuilder: (_, s) => _fadePage(
                    s,
                    CourseDetailScreen(courseId: s.pathParameters['courseId']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'quiz',
                      pageBuilder: (_, s) => _fadePage(
                        s,
                        QuizScreen(courseId: s.pathParameters['courseId']!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),

          // Branche 2 — Financement
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.financement,
              builder: (_, __) => const FinancementScreen(),
              routes: [
                GoRoute(path: 'demande',     pageBuilder: (_, s) => _fadePage(s, const DemandeFormScreen())),
                GoRoute(path: 'partenaires', pageBuilder: (_, s) => _fadePage(s, const PartenairesScreen())),
                GoRoute(
                  path: 'statut/:demandeId',
                  pageBuilder: (_, s) => _fadePage(
                    s,
                    StatutDemandeScreen(demandeId: s.pathParameters['demandeId']!),
                  ),
                  routes: [
                    GoRoute(
                      path: 'remboursements',
                      pageBuilder: (_, s) => _fadePage(
                        s,
                        RemboursementsScreen(
                          demandeId: s.pathParameters['demandeId']!,
                          montantTotal: (s.extra as double?) ?? 0,
                        ),
                      ),
                      routes: [
                        GoRoute(
                          path: ':echeanceId/payer',
                          pageBuilder: (_, s) {
                            final extra = s.extra as Map<String, dynamic>? ?? {};
                            return _fadePage(
                              s,
                              PaiementScreen(
                                demandeId: s.pathParameters['demandeId']!,
                                echeanceId: s.pathParameters['echeanceId']!,
                                numeroEcheance: extra['numeroEcheance'] as int? ?? 0,
                                montant: (extra['montant'] as num?)?.toDouble() ?? 0,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ]),

          // Branche 3 — Assurance
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.assurance,
              builder: (_, __) => const AssuranceScreen(),
              routes: [
                GoRoute(path: 'produits',   pageBuilder: (_, s) => _fadePage(s, const FichesProduitScreen())),
                GoRoute(path: 'simulateur', pageBuilder: (_, s) => _fadePage(s, const SimulateurAssuranceScreen())),
                GoRoute(path: 'souscrire',  pageBuilder: (_, s) => _fadePage(s, const SouscriptionScreen())),
                GoRoute(path: 'contrats',   pageBuilder: (_, s) => _fadePage(s, const MesContratsScreen())),
                GoRoute(
                  path: 'sinistre/:contratId',
                  pageBuilder: (_, s) => _fadePage(
                    s,
                    SinistreFormScreen(contratId: s.pathParameters['contratId']!),
                  ),
                ),
              ],
            ),
          ]),

          // Branche 4 — Profil
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profil,
              builder: (_, __) => const ProfilScreen(),
            ),
          ]),
        ],
      ),

      // ── Shell Admin (BottomNav admin séparé) ───────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.adminDashboard,
            pageBuilder: (_, s) => _fadePage(s, const AdminDashboardScreen()),
          ),
          GoRoute(
            path: AppRoutes.adminFormations,
            pageBuilder: (_, s) => _fadePage(s, const AdminFormationsScreen()),
            routes: [
              GoRoute(path: 'new', pageBuilder: (_, s) => _fadePage(s, const AdminCourseFormScreen())),
              GoRoute(
                path: ':courseId',
                pageBuilder: (_, s) => _fadePage(
                  s,
                  AdminCourseFormScreen(courseId: s.pathParameters['courseId']),
                ),
                routes: [
                  GoRoute(
                    path: 'lecons',
                    pageBuilder: (_, s) {
                      final extra = s.extra as Map<String, dynamic>? ?? {};
                      return _fadePage(
                        s,
                        AdminLeconsScreen(
                          courseId: s.pathParameters['courseId']!,
                          courseTitre: extra['courseTitre'] as String? ?? '',
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'new',
                        pageBuilder: (_, s) {
                          final extra = s.extra as Map<String, dynamic>? ?? {};
                          return _fadePage(
                            s,
                            AdminLeconFormScreen(
                              courseId: s.pathParameters['courseId']!,
                              courseTitre: extra['courseTitre'] as String? ?? '',
                              nextOrdre: extra['nextOrdre'] as int? ?? 1,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        path: ':leconId',
                        pageBuilder: (_, s) {
                          final extra = s.extra as Map<String, dynamic>? ?? {};
                          return _fadePage(
                            s,
                            AdminLeconFormScreen(
                              courseId: s.pathParameters['courseId']!,
                              leconId: s.pathParameters['leconId'],
                              courseTitre: extra['courseTitre'] as String? ?? '',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(path: AppRoutes.adminUsers,    pageBuilder: (_, s) => _fadePage(s, const AdminUsersScreen())),
          GoRoute(path: AppRoutes.adminDemandes, pageBuilder: (_, s) => _fadePage(s, const AdminDemandesScreen())),
          GoRoute(path: AppRoutes.adminContrats,  pageBuilder: (_, s) => _fadePage(s, const AdminContratsScreen())),
          GoRoute(path: AppRoutes.adminPartenaires, pageBuilder: (_, s) => _fadePage(s, const AdminPartenairesScreen())),
          GoRoute(path: AppRoutes.adminAnalytics,  pageBuilder: (_, s) => _fadePage(s, const AdminAnalyticsScreen())),
          GoRoute(path: AppRoutes.adminSettings,   pageBuilder: (_, s) => _fadePage(s, const AdminSettingsScreen())),
        ],
      ),
    ],
  );
});
