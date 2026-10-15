import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/formation_admin.dart';

class AdminFormationsRepository {
  AdminFormationsRepository(this._client);
  final SupabaseClient _client;

  Future<List<FormationAdmin>> fetch() async {
    final rows = await _client.rpc('admin_lister_formations') as List;
    return rows
        .map((r) => FormationAdmin.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> changerResponsable(
    String formationId,
    String formateurId,
  ) async {
    await _client.rpc(
      'admin_changer_responsable',
      params: {'p_formation': formationId, 'p_formateur': formateurId},
    );
  }
}
