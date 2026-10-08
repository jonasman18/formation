import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository(this._client);
  final SupabaseClient _client;

  /// Flux en direct de mes notifications (les plus récentes d'abord).
  Stream<List<AppNotification>> observer() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return Stream.value(const []);
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows.map(AppNotification.fromMap).toList());
  }

  Future<void> marquerLue(String id) async {
    await _client.from('notifications').update({'lue': true}).eq('id', id);
  }

  Future<void> toutMarquerLu() async {
    final uid = _client.auth.currentUser!.id;
    await _client
        .from('notifications')
        .update({'lue': true})
        .eq('user_id', uid)
        .eq('lue', false);
  }

  Future<void> supprimer(String id) async {
    await _client.from('notifications').delete().eq('id', id);
  }
}
