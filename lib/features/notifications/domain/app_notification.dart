class AppNotification {
  const AppNotification({
    required this.id,
    required this.titre,
    required this.lue,
    required this.createdAt,
    this.corps,
  });

  final String id;
  final String titre;
  final String? corps;
  final bool lue;
  final DateTime createdAt;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as String,
    titre: m['titre'] as String,
    corps: m['corps'] as String?,
    lue: (m['lue'] as bool?) ?? false,
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
  );
}
