import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/formateur_repository.dart';
import '../domain/formation_geree.dart';
import '../domain/copie.dart';
import '../domain/quiz_edition.dart';

final formateurRepositoryProvider = Provider(
  (ref) => FormateurRepository(ref.watch(supabaseClientProvider)),
);

final formationsGereesProvider =
    FutureProvider.autoDispose<List<FormationGeree>>((ref) {
      ref.watch(currentUserIdProvider);
      return ref.watch(formateurRepositoryProvider).fetchMesFormations();
    });

final formationGereeProvider = FutureProvider.autoDispose
    .family<FormationGeree, String>(
      (ref, id) => ref.watch(formateurRepositoryProvider).fetchFormation(id),
    );

final categoriesProvider = FutureProvider.autoDispose<List<CategorieOption>>(
  (ref) => ref.watch(formateurRepositoryProvider).fetchCategories(),
);

final copiesProvider = FutureProvider.autoDispose<List<Copie>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(formateurRepositoryProvider).fetchCopies();
});

final quizEditionProvider = FutureProvider.autoDispose
    .family<QuizEdition, String>(
      (ref, id) => ref.watch(formateurRepositoryProvider).fetchQuizEdition(id),
    );
