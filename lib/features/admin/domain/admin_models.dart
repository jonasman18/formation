class Utilisateur {
  const Utilisateur({
    required this.id,
    required this.email,
    required this.role,
    this.nom,
    this.prenom,
  });

  final String id;
  final String email;
  final String role; // apprenant | formateur | admin
  final String? nom;
  final String? prenom;

  String get nomComplet => '${prenom ?? ''} ${nom ?? ''}'.trim();

  String get initiales {
    final base = nomComplet.isEmpty ? email : nomComplet;
    return base.isEmpty ? '?' : base.substring(0, 1).toUpperCase();
  }

  factory Utilisateur.fromMap(Map<String, dynamic> m) => Utilisateur(
    id: m['id'] as String,
    email: (m['email'] as String?) ?? '',
    role: (m['role'] as String?) ?? 'apprenant',
    nom: m['nom'] as String?,
    prenom: m['prenom'] as String?,
  );
}

const rolesDisponibles = ['apprenant', 'formateur', 'admin'];

String libelleRole(String role) => switch (role) {
  'admin' => 'Administrateur',
  'formateur' => 'Formateur',
  _ => 'Apprenant',
};

class CategorieAdmin {
  const CategorieAdmin({
    required this.id,
    required this.nom,
    required this.nbFormations,
  });

  final String id;
  final String nom;
  final int nbFormations;

  factory CategorieAdmin.fromMap(Map<String, dynamic> m) {
    final agg = m['formations'];
    var n = 0;
    if (agg is List && agg.isNotEmpty && agg.first is Map) {
      n = ((agg.first as Map)['count'] as num?)?.toInt() ?? 0;
    }
    return CategorieAdmin(
      id: m['id'] as String,
      nom: m['nom'] as String,
      nbFormations: n,
    );
  }
}
