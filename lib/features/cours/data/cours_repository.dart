import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cours.dart';

class CoursRepository {
  CoursRepository(this._client);
  final SupabaseClient _client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Utilisateur non connecté');
    return id;
  }

  /// Modules d'une formation, avec leurs leçons.
  Future<List<Module>> fetchModules(String formationId) async {
    final rows = await _client
        .from('modules')
        .select(
          'id, titre, ordre, lecons(id, titre, type, contenu, url, duree_sec, ordre, ressources(id, type, titre, url, ordre)), quiz(id, titre), exercices(id, titre)',
        )
        .eq('formation_id', formationId)
        .order('ordre');
    return rows.map(Module.fromMap).toList();
  }

  /// Identifiants des leçons terminées par l'utilisateur connecté.
  Future<Set<String>> fetchLeconsTerminees() async {
    final rows = await _client
        .from('progression_lecons')
        .select('lecon_id')
        .eq('apprenant_id', _uid);
    return {for (final r in rows) r['lecon_id'] as String};
  }

  Future<void> marquerTerminee(String leconId) async {
    try {
      await _client.from('progression_lecons').insert({
        'apprenant_id': _uid,
        'lecon_id': leconId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // 23505 = déjà terminée
    }
  }
}
