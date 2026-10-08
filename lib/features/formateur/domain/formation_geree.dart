class FormationGeree {
  const FormationGeree({
    required this.id,
    required this.titre,
    required this.statut,
    this.description,
    this.categorieId,
  });

  final String id;
  final String titre;
  final String statut; // brouillon | publie | archive
  final String? description;
  final String? categorieId;

  factory FormationGeree.fromMap(Map<String, dynamic> m) => FormationGeree(
    id: m['id'] as String,
    titre: m['titre'] as String,
    statut: m['statut'] as String,
    description: m['description'] as String?,
    categorieId: m['categorie_id'] as String?,
  );
}

class CategorieOption {
  const CategorieOption({required this.id, required this.nom});
  final String id;
  final String nom;

  factory CategorieOption.fromMap(Map<String, dynamic> m) =>
      CategorieOption(id: m['id'] as String, nom: m['nom'] as String);
}

String libelleStatut(String statut) => switch (statut) {
  'publie' => 'Publiée',
  'archive' => 'Archivée',
  _ => 'Brouillon',
};
