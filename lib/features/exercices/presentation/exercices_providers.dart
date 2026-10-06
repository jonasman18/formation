import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/exercices_repository.dart';
import '../domain/exercice.dart';

final exercicesRepositoryProvider = Provider(
  (ref) => ExercicesRepository(ref.watch(supabaseClientProvider)),
);

final exerciceProvider = FutureProvider.autoDispose.family<Exercice, String>(
  (ref, id) => ref.watch(exercicesRepositoryProvider).fetchExercice(id),
);

final maSoumissionProvider =
    FutureProvider.autoDispose.family<Soumission?, String>((ref, id) {
  ref.watch(currentUserIdProvider); // se recharge si on change de compte
  return ref.watch(exercicesRepositoryProvider).fetchMaSoumission(id);
});