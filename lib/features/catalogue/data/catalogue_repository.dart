import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/formation.dart';

class CatalogueRepository {
  CatalogueRepository(this._client);
  final SupabaseClient _client;

  static const _cols = 'id, titre, description, image_url, categories(nom)';

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Utilisateur non connecté');
    return id;
  }

  Future<List<Formation>> fetchPubliees() async {
    final rows = await _client
        .from('formations')
        .select(_cols)
        .eq('statut', 'publie')
        .order('created_at', ascending: false);
    return rows.map(Formation.fromMap).toList();
  }

  Future<Formation> fetchById(String id) async {
    final row =
        await _client.from('formations').select(_cols).eq('id', id).single();
    return Formation.fromMap(row);
  }

  Future<bool> estInscrit(String formationId) async {
    final row = await _client
        .from('inscriptions')
        .select('id')
        .eq('formation_id', formationId)
        .eq('apprenant_id', _uid)
        .maybeSingle();
    return row != null;
  }

  Future<void> sInscrire(String formationId) async {
    await _client
        .from('inscriptions')
        .insert({'formation_id': formationId, 'apprenant_id': _uid});
  }

  Future<List<MaFormation>> fetchMesFormations() async {
    final inscriptions = await _client
        .from('inscriptions')
        .select('formations($_cols)')
        .eq('apprenant_id', _uid)
        .order('created_at', ascending: false);

    // Vue SQL : pourcentage de leçons terminées par formation.
    final progress = await _client
        .from('progression_formation')
        .select('formation_id, pourcentage')
        .eq('apprenant_id', _uid);
    final pctParFormation = {
      for (final p in progress)
        p['formation_id'] as String: (p['pourcentage'] as num).toInt(),
    };

    final result = <MaFormation>[];
    for (final i in inscriptions) {
      final raw = i['formations'];
      if (raw == null) continue;
      final f = Formation.fromMap(raw as Map<String, dynamic>);
      result.add(
        MaFormation(formation: f, pourcentage: pctParFormation[f.id] ?? 0),
      );
    }
    return result;
  }
}