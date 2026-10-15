class Annonce {
  const Annonce({
    required this.id,
    required this.titre,
    required this.corps,
    required this.creeLe,
    this.auteur,
  });

  final String id;
  final String titre;
  final String corps;
  final DateTime creeLe;
  final String? auteur;

  factory Annonce.fromMap(Map<String, dynamic> m) {
    final p = m['profiles'] as Map<String, dynamic>?;
    final nom = p == null
        ? null
        : '${p['prenom'] ?? ''} ${p['nom'] ?? ''}'.trim();
    return Annonce(
      id: m['id'] as String,
      titre: m['titre'] as String,
      corps: (m['contenu'] as String?) ?? '',
      creeLe: DateTime.parse(m['created_at'] as String).toLocal(),
      auteur: (nom == null || nom.isEmpty) ? null : nom,
    );
  }
}
