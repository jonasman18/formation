import '../../auth/presentation/auth_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/catalogue_repository.dart';
import '../domain/formation.dart';

final catalogueRepositoryProvider = Provider(
  (ref) => CatalogueRepository(ref.watch(supabaseClientProvider)),
);

final formationsPublieesProvider = FutureProvider<List<Formation>>(
  (ref) => ref.watch(catalogueRepositoryProvider).fetchPubliees(),
);

final formationProvider = FutureProvider.family<Formation, String>(
  (ref, id) => ref.watch(catalogueRepositoryProvider).fetchById(id),
);

final inscritProvider = FutureProvider.family<bool, String>((ref, formationId) {
  ref.watch(currentUserIdProvider); // recharge si l'utilisateur change
  return ref.watch(catalogueRepositoryProvider).estInscrit(formationId);
});

/// autoDispose : les données sont rechargées chaque fois qu'on rouvre l'onglet.
final mesFormationsProvider = FutureProvider.autoDispose<List<MaFormation>>((
  ref,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(catalogueRepositoryProvider).fetchMesFormations();
});
