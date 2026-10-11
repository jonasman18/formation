import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/demande.dart';

class InscriptionsRepository {
  InscriptionsRepository(this._client);
  final SupabaseClient _client;

  // ---------- Côté apprenant ----------
  /// null = aucune demande ; sinon en_attente | acceptee | refusee
  Future<String?> statutMaDemande(String formationId) async {
    final row = await _client
        .from('demandes_inscription')
        .select('statut')
        .eq('formation_id', formationId)
        .eq('apprenant_id', _client.auth.currentUser!.id)
        .maybeSingle();
    return row?['statut'] as String?;
  }

  Future<void> demander(String formationId, {String? message}) async {
    await _client.rpc(
      'demander_inscription',
      params: {'p_formation': formationId, 'p_message': message},
    );
  }

  Future<void> annuler(String formationId) async {
    await _client
        .from('demandes_inscription')
        .delete()
        .eq('formation_id', formationId)
        .eq('apprenant_id', _client.auth.currentUser!.id)
        .eq('statut', 'en_attente');
  }

  // ---------- Côté formateur ----------
  Future<String> fetchAcces(String formationId) async {
    final row = await _client
        .from('formations')
        .select('acces')
        .eq('id', formationId)
        .single();
    return (row['acces'] as String?) ?? 'libre';
  }

  Future<void> definirAcces(String formationId, String acces) async {
    await _client
        .from('formations')
        .update({'acces': acces})
        .eq('id', formationId);
  }

  Future<List<Demande>> fetchDemandes() async {
    final rows = await _client
        .from('demandes_inscription')
        .select(
          'id, message, created_at, formation_id, '
          'formations(titre), profiles!apprenant_id(prenom, nom)',
        )
        .eq('statut', 'en_attente')
        .order('created_at');
    return rows.map(Demande.fromMap).toList();
  }

  Future<void> traiter(String demandeId, {required bool accepter}) async {
    await _client.rpc(
      'traiter_demande',
      params: {'p_demande': demandeId, 'p_accepter': accepter},
    );
  }
}
