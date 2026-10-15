import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/annonces_repository.dart';
import '../domain/annonce.dart';

final annoncesRepositoryProvider = Provider(
  (ref) => AnnoncesRepository(ref.watch(supabaseClientProvider)),
);

final annoncesProvider = FutureProvider.autoDispose
    .family<List<Annonce>, String>(
      (ref, formationId) =>
          ref.watch(annoncesRepositoryProvider).fetch(formationId),
    );
