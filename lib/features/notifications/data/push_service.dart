import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Enregistre le jeton FCM de cet appareil et écoute les notifications push.
class PushService {
  PushService(this._client);
  final SupabaseClient _client;
  final List<StreamSubscription<dynamic>> _subs = [];

  String? get _plateforme {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  Future<void> demarrer({
    required void Function(RemoteMessage) onMessage,
    required void Function() onOuverture,
  }) async {
    if (Firebase.apps.isEmpty || _plateforme == null) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission();
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push : notifications refusées par l\'utilisateur.');
        return;
      }

      // App ouverte : message reçu / appui sur une notification
      _subs.add(FirebaseMessaging.onMessage.listen(onMessage));
      _subs.add(
        FirebaseMessaging.onMessageOpenedApp.listen((_) => onOuverture()),
      );
      // App lancée en touchant une notification (app fermée)
      final initial = await messaging.getInitialMessage();
      if (initial != null) onOuverture();

      final token = await messaging.getToken();
      if (token != null) await _enregistrer(token);
      _subs.add(messaging.onTokenRefresh.listen(_enregistrer));
    } catch (e) {
      debugPrint('Push : $e');
    }
  }

  Future<void> _enregistrer(String token) async {
    try {
      await _client.rpc(
        'register_device_token',
        params: {'p_token': token, 'p_plateforme': _plateforme},
      );
    } catch (e) {
      debugPrint('Push (enregistrement du jeton) : $e');
    }
  }

  void arreter() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}
