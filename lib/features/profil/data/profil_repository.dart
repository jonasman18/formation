import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

final profilRepositoryProvider = Provider<ProfilRepository>(
  (ref) => ProfilRepository(ref.watch(supabaseClientProvider)),
);

class ProfilRepository {
  ProfilRepository(this._client);
  final SupabaseClient _client;

  String get _chemin => '${_client.auth.currentUser!.id}/avatar.jpg';

  Future<void> modifierNomPrenom({
    required String nom,
    required String prenom,
  }) async {
    await _client.rpc(
      'modifier_mon_profil',
      params: {'p_nom': nom, 'p_prenom': prenom},
    );
  }

  Future<void> changerAvatar(Uint8List octets) async {
    final bucket = _client.storage.from('avatars');
    await bucket.uploadBinary(
      _chemin,
      octets,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    // ?v= force l'actualisation du cache image après un changement
    final url =
        '${bucket.getPublicUrl(_chemin)}?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client.rpc('definir_mon_avatar', params: {'p_url': url});
  }

  Future<void> supprimerAvatar() async {
    await _client.storage.from('avatars').remove([_chemin]);
    await _client.rpc('definir_mon_avatar', params: {'p_url': null});
  }
}
