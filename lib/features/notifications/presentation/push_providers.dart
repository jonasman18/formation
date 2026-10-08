import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/ui/messenger.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/push_service.dart';

/// Dès qu'un utilisateur est connecté : enregistre le jeton de l'appareil
/// et gère les notifications push reçues.
final pushRegistrationProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return;

  final service = PushService(ref.read(supabaseClientProvider));
  service.demarrer(
    onMessage: (m) {
      final n = m.notification;
      if (n == null) return;
      messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((n.title ?? '').isNotEmpty)
                  Text(
                    n.title!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                if ((n.body ?? '').isNotEmpty) Text(n.body!),
              ],
            ),
            action: SnackBarAction(
              label: 'Voir',
              onPressed: () => ref.read(routerProvider).go('/notifications'),
            ),
          ),
        );
    },
    onOuverture: () => ref.read(routerProvider).go('/notifications'),
  );
  ref.onDispose(service.arreter);
});
