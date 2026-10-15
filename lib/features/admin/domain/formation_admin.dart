class FormationAdmin {
  const FormationAdmin({
    required this.id,
    required this.titre,
    required this.statut,
    required this.formateurNom,
    required this.nbInscrits,
    this.categorie,
    this.formateurId,
  });

  final String id;
  final String titre;
  final String statut;
  final String? categorie;
  final String? formateurId;
  final String formateurNom;
  final int nbInscrits;

  String get libelleStatut => switch (statut) {
    'publie' => 'Publiée',
    'archive' => 'Archivée',
    _ => 'Brouillon',
  };

  factory FormationAdmin.fromMap(Map<String, dynamic> m) => FormationAdmin(
    id: m['id'] as String,
    titre: m['titre'] as String,
    statut: (m['statut'] as String?) ?? 'brouillon',
    categorie: m['categorie'] as String?,
    formateurId: m['formateur_id'] as String?,
    formateurNom: ((m['formateur_nom'] as String?) ?? '').trim(),
    nbInscrits: (m['nb_inscrits'] as num?)?.toInt() ?? 0,
  );
}
