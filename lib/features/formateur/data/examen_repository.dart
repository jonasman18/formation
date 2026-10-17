import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

final examenRepositoryProvider = Provider<ExamenRepository>(
  (ref) => ExamenRepository(ref.watch(supabaseClientProvider)),
);

final examenEditionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>(
      (ref, formationId) => ref.watch(examenRepositoryProvider).lire(formationId),
    );

class ExamenRepository {
  ExamenRepository(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>?> lire(String formationId) async {
    final res = await _client.rpc(
      'lire_examen_edition',
      params: {'p_formation': formationId},
    );
    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  Future<void> enregistrer({
    required String formationId,
    required String titre,
    required int noteMin,
    required int dureeMin,
    required int delaiRepriseH,
    required int maxTentatives,
    required bool publie,
    required List<Map<String, dynamic>> questions,
  }) async {
    await _client.rpc(
      'enregistrer_examen',
      params: {
        'p_formation': formationId,
        'p_titre': titre,
        'p_note_min': noteMin,
        'p_duree_min': dureeMin,
        'p_max_tentatives': maxTentatives,
        'p_delai_reprise_h': delaiRepriseH,
        'p_publie': publie,
        'p_questions': questions,
      },
    );
  }

  Future<void> supprimer(String formationId) async {
    await _client.rpc('supprimer_examen', params: {'p_formation': formationId});
  }
}