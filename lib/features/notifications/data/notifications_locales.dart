import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Affiche une vraie notification système quand un message FCM arrive
/// alors que l'app est ouverte, et crée le canal à haute importance.
class NotificationsLocales {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pret = false;

  static const canal = AndroidNotificationChannel(
    'high_importance',
    'Notifications',
    description: 'Notifications de formations, corrections et demandes.',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (_pret) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(canal);
    _pret = true;
  }

  static Future<void> afficher(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canal.id,
          canal.name,
          channelDescription: canal.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }
}