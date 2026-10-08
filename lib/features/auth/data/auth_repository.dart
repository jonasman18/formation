import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Retourne true si une session est ouverte tout de suite
  /// (false si la confirmation par e-mail est activée).
  Future<bool> signUp({
    required String email,
    required String password,
    required String nom,
    required String prenom,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'nom': nom, 'prenom': prenom}, // lu par le trigger SQL
    );
    return res.session != null;
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }
}
