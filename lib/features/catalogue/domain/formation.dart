class Formation {
  const Formation({
    required this.id,
    required this.titre,
    this.description,
    this.imageUrl,
    this.categorie,
  });

  final String id;
  final String titre;
  final String? description;
  final String? imageUrl;
  final String? categorie;

  factory Formation.fromMap(Map<String, dynamic> m) => Formation(
        id: m['id'] as String,
        titre: m['titre'] as String,
        description: m['description'] as String?,
        imageUrl: m['image_url'] as String?,
        categorie:
            (m['categories'] as Map<String, dynamic>?)?['nom'] as String?,
      );
}

/// Formation suivie par l'apprenant, avec son pourcentage de progression.
class MaFormation {
  const MaFormation({required this.formation, required this.pourcentage});
  final Formation formation;
  final int pourcentage;
}