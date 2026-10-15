import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/catalogue/presentation/catalogue_page.dart';
import '../../features/catalogue/presentation/formation_detail_page.dart';
import '../../features/catalogue/presentation/mes_formations_page.dart';
import '../../features/cours/presentation/cours_page.dart';
import '../../features/cours/presentation/lecon_page.dart';
import '../../features/exercices/presentation/exercice_page.dart';
import '../../features/formateur/presentation/formateur_page.dart';
import '../../features/formateur/presentation/formation_form_page.dart';
import '../../features/profil/presentation/profil_page.dart';
import '../../features/quiz/presentation/quiz_page.dart';
import '../../shared/widgets/learner_shell.dart';
import '../../features/formateur/presentation/contenu_page.dart';
import '../../features/formateur/presentation/lecon_form_page.dart';
import '../../features/formateur/presentation/copies_page.dart';
import '../../features/formateur/presentation/correction_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/formateur/presentation/exercice_edit_page.dart';
import '../../features/formateur/presentation/quiz_edit_page.dart';
import '../../features/admin/presentation/admin_page.dart';
import '../../features/inscriptions/presentation/demandes_page.dart';
import '../../features/annonces/presentation/annonces_page.dart';

/// Relance les redirections quand l'utilisateur se connecte ou se déconnecte.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(currentUserIdProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(currentUserIdProvider) != null;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';

      if (!loggedIn) return isAuthRoute ? null : '/login';

      // Rôle : tant que le profil n'est pas chargé, on ne décide rien.
      final role = ref.read(currentProfileProvider).asData?.value?.role.name;
      if (role == null) return null;

      final accueil = switch (role) {
        'admin' => '/admin',
        'formateur' => '/formateur',
        _ => '/catalogue',
      };
      if (isAuthRoute) return accueil;

      bool sous(String p) => loc == p || loc.startsWith('$p/');

      switch (role) {
        case 'apprenant':
          // Espaces réservés au personnel
          if (sous('/formateur') || sous('/admin')) return '/catalogue';
        case 'formateur':
          // Pas d'espace admin, pas de catalogue ni de « Mes formations »
          if (sous('/admin') || sous('/catalogue') || sous('/mes-formations')) {
            return '/formateur';
          }
        case 'admin':
          // Superviseur : il édite les formations existantes, il n'en crée pas
          if (sous('/catalogue') ||
              sous('/mes-formations') ||
              loc == '/formateur' ||
              sous('/formateur/copies') ||
              sous('/formateur/demandes') ||
              loc == '/formateur/formation/nouvelle') {
            return '/admin';
          }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),

      // Barre de navigation du bas
      ShellRoute(
        builder: (context, state, child) =>
            LearnerShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/catalogue',
            builder: (_, _) => const CataloguePage(),
            routes: [
              GoRoute(
                path: 'formation/:id',
                builder: (_, state) => FormationDetailPage(
                  formationId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'cours',
                    builder: (_, state) =>
                        CoursPage(formationId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'lecon/:leconId',
                        builder: (_, state) => LeconPage(
                          formationId: state.pathParameters['id']!,
                          leconId: state.pathParameters['leconId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'quiz/:quizId',
                        builder: (_, state) => QuizPage(
                          formationId: state.pathParameters['id']!,
                          quizId: state.pathParameters['quizId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'exercice/:exerciceId',
                        builder: (_, state) => ExercicePage(
                          formationId: state.pathParameters['id']!,
                          exerciceId: state.pathParameters['exerciceId']!,
                        ),
                      ),
                      // Annonces du formateur (lecture seule pour l'apprenant)
                      GoRoute(
                        path: 'annonces',
                        builder: (_, state) => AnnoncesPage(
                          formationId: state.pathParameters['id']!,
                          peutPublier: false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/mes-formations',
            builder: (_, _) => const MesFormationsPage(),
          ),
          GoRoute(
            path: '/formateur',
            builder: (_, _) => const FormateurPage(),
            routes: [
              // 'nouvelle' doit rester AVANT ':id'
              GoRoute(
                path: 'formation/nouvelle',
                builder: (_, _) => const FormationFormPage(),
              ),
              GoRoute(
                path: 'copies',
                builder: (_, _) => const CopiesPage(),
                routes: [
                  GoRoute(
                    path: ':soumissionId',
                    builder: (_, state) => CorrectionPage(
                      soumissionId: state.pathParameters['soumissionId']!,
                    ),
                  ),
                ],
              ),
              // Demandes d'inscription : /formateur/demandes
              GoRoute(
                path: 'demandes',
                builder: (_, _) => const DemandesPage(),
              ),
              GoRoute(
                path: 'formation/:id',
                builder: (_, state) =>
                    FormationFormPage(formationId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'annonces',
                    builder: (_, state) => AnnoncesPage(
                      formationId: state.pathParameters['id']!,
                      peutPublier: true,
                    ),
                  ),
                  GoRoute(
                    path: 'contenu',
                    builder: (_, state) =>
                        ContenuPage(formationId: state.pathParameters['id']!),
                    routes: [
                      // 'nouvelle' doit rester AVANT ':leconId'
                      GoRoute(
                        path: 'module/:moduleId/lecon/nouvelle',
                        builder: (_, state) => LeconFormPage(
                          formationId: state.pathParameters['id']!,
                          moduleId: state.pathParameters['moduleId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'module/:moduleId/lecon/:leconId',
                        builder: (_, state) => LeconFormPage(
                          formationId: state.pathParameters['id']!,
                          moduleId: state.pathParameters['moduleId']!,
                          leconId: state.pathParameters['leconId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'module/:moduleId/quiz/nouveau',
                        builder: (_, state) => QuizEditPage(
                          formationId: state.pathParameters['id']!,
                          moduleId: state.pathParameters['moduleId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'module/:moduleId/quiz/:quizId',
                        builder: (_, state) => QuizEditPage(
                          formationId: state.pathParameters['id']!,
                          moduleId: state.pathParameters['moduleId']!,
                          quizId: state.pathParameters['quizId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'module/:moduleId/exercice/nouveau',
                        builder: (_, state) => ExerciceEditPage(
                          formationId: state.pathParameters['id']!,
                          moduleId: state.pathParameters['moduleId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'module/:moduleId/exercice/:exerciceId',
                        builder: (_, state) => ExerciceEditPage(
                          formationId: state.pathParameters['id']!,
                          moduleId: state.pathParameters['moduleId']!,
                          exerciceId: state.pathParameters['exerciceId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          GoRoute(path: '/admin', builder: (_, _) => const AdminPage()),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const NotificationsPage(),
          ),
          GoRoute(path: '/profil', builder: (_, _) => const ProfilPage()),
        ],
      ),
    ],
  );
});
