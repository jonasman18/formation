class Demande {
  const Demande({
    required this.id,
    required this.formationId,
    required this.formation,
    required this.apprenant,
    required this.createdAt,
    this.message,
  });

  final String id;
  final String formationId;
  final String formation;
  final String apprenant;
  final DateTime createdAt;
  final String? message;

  static Map<String, dynamic>? _map(Object? o) =>
      o is Map ? Map<String, dynamic>.from(o) : null;

  factory Demande.fromMap(Map<String, dynamic> m) {
    final f = _map(m['formations']);
    final p = _map(m['profiles']);
    final nom = '${p?['prenom'] ?? ''} ${p?['nom'] ?? ''}'.trim();
    return Demande(
      id: m['id'] as String,
      formationId: m['formation_id'] as String,
      formation: (f?['titre'] as String?) ?? 'Formation',
      apprenant: nom.isEmpty ? 'Apprenant' : nom,
      message: m['message'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    );
  }
}
