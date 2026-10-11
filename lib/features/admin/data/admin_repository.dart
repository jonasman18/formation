import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/admin_models.dart';

class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  // ---------- Utilisateurs ----------
  Future<List<Utilisateur>> fetchUtilisateurs() async {
    final rows = await _client.rpc('admin_lister_utilisateurs') as List;
    return rows
        .map((r) => Utilisateur.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> changerRole(String userId, String role) async {
    await _client.rpc(
      'admin_set_role',
      params: {'p_user': userId, 'p_role': role},
    );
  }

  // ---------- Catégories ----------
  Future<List<CategorieAdmin>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select('id, nom, formations(count)')
        .order('nom');
    return rows.map(CategorieAdmin.fromMap).toList();
  }

  Future<void> creerCategorie(String nom) async {
    await _client.from('categories').insert({'nom': nom});
  }

  Future<void> renommerCategorie(String id, String nom) async {
    await _client.from('categories').update({'nom': nom}).eq('id', id);
  }

  Future<void> supprimerCategorie(String id) async {
    await _client.from('categories').delete().eq('id', id);
  }
}
