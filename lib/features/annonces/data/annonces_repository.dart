import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/annonce.dart';

class AnnoncesRepository {
  AnnoncesRepository(this._client);
  final SupabaseClient _client;

  Future<List<Annonce>> fetch(String formationId) async {
    final rows = await _client
        .from('annonces')
        .select(
          'id, titre, contenu, created_at, profiles!auteur_id(prenom, nom)',
        )
        .eq('formation_id', formationId)
        .order('created_at', ascending: false);
    return rows.map(Annonce.fromMap).toList();
  }

  /// Publie l'annonce et renvoie le nombre d'inscrits notifiés.
  Future<int> publier({
    required String formationId,
    required String titre,
    required String corps,
  }) async {
    final r = await _client.rpc(
      'publier_annonce',
      params: {'p_formation': formationId, 'p_titre': titre, 'p_corps': corps},
    );
    return (r as num).toInt();
  }

  Future<void> supprimer(String id) async {
    await _client.from('annonces').delete().eq('id', id);
  }
}
