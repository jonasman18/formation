import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

final notificationsRepositoryProvider = Provider(
  (ref) => NotificationsRepository(ref.watch(supabaseClientProvider)),
);

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  ref.watch(currentUserIdProvider); // se recrée si on change de compte
  return ref.watch(notificationsRepositoryProvider).observer();
});

/// Nombre de notifications non lues (pour la pastille).
final nonLuesProvider = Provider<int>((ref) {
  final liste = ref.watch(notificationsProvider).asData?.value ?? const [];
  return liste.where((n) => !n.lue).length;
});
