import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/inscriptions_repository.dart';
import '../domain/demande.dart';

final inscriptionsRepositoryProvider = Provider<InscriptionsRepository>(
  (ref) => InscriptionsRepository(Supabase.instance.client),
);

/// Statut de ma demande pour une formation (null si aucune).
final maDemandeProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, formationId) =>
      ref.watch(inscriptionsRepositoryProvider).statutMaDemande(formationId),
);

/// 'libre' ou 'sur_demande'.
final accesFormationProvider = FutureProvider.autoDispose
    .family<String, String>(
      (ref, formationId) =>
          ref.watch(inscriptionsRepositoryProvider).fetchAcces(formationId),
    );

final demandesProvider = FutureProvider.autoDispose<List<Demande>>(
  (ref) => ref.watch(inscriptionsRepositoryProvider).fetchDemandes(),
);
