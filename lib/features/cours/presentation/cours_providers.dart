import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/cours_repository.dart';
import '../domain/cours.dart';

final coursRepositoryProvider = Provider(
  (ref) => CoursRepository(ref.watch(supabaseClientProvider)),
);

final modulesProvider = FutureProvider.family<List<Module>, String>(
  (ref, formationId) =>
      ref.watch(coursRepositoryProvider).fetchModules(formationId),
);

final leconsTermineesProvider = FutureProvider<Set<String>>((ref) {
  ref.watch(currentUserIdProvider); // recharge si l'utilisateur change
  return ref.watch(coursRepositoryProvider).fetchLeconsTerminees();
});
