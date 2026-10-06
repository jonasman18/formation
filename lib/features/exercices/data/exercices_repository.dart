import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/exercice.dart';

class ExercicesRepository {
  ExercicesRepository(this._client);
  final SupabaseClient _client;

  Future<Exercice> fetchExercice(String id) async {
    final row = await _client
        .from('exercices')
        .select('id, titre, consigne, date_limite')
        .eq('id', id)
        .single();
    return Exercice.fromMap(row);
  }

  /// Ma copie (le filtre apprenant_id est nécessaire : un formateur voit toutes les copies).
  Future<Soumission?> fetchMaSoumission(String exerciceId) async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('soumissions')
        .select('id, contenu, note, commentaire, corrige_at')
        .eq('exercice_id', exerciceId)
        .eq('apprenant_id', uid)
        .maybeSingle();
    return row == null ? null : Soumission.fromMap(row);
  }

  /// Dépose ou remplace ma copie (possible tant qu'elle n'est pas corrigée : RLS).
  Future<void> soumettre(String exerciceId, String contenu) async {
    await _client.from('soumissions').upsert(
      {
        'exercice_id': exerciceId,
        'apprenant_id': _client.auth.currentUser!.id,
        'contenu': contenu,
        'soumis_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'exercice_id,apprenant_id',
    );
  }
}