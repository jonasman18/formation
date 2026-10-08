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

/// Relance les redirections quand l'utilisateur se connecte ou se déconnecte.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(currentUserIdProvider, (_, _) => notifyListeners());
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
      if (isAuthRoute) return '/catalogue';
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
              GoRoute(
                path: 'formation/:id',
                builder: (_, state) =>
                    FormationFormPage(formationId: state.pathParameters['id']!),
                routes: [
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
