import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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

  Future<void> signOut() async {
    await _retirerJetonPush(); // avant la fin de session (il faut être connecté)
    await _client.auth.signOut();
  }

  /// Dissocie ce téléphone du compte : il ne recevra plus ses notifications.
  /// Ne bloque jamais la déconnexion en cas d'échec ou de réseau absent.
  Future<void> _retirerJetonPush() async {
    if (kIsWeb || Firebase.apps.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 2),
      );
      if (token == null) return;
      await _client
          .rpc('unregister_device_token', params: {'p_token': token})
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Push (retrait du jeton) : $e');
    }
  }

  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }
}
