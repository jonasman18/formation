class Exercice {
  const Exercice({
    required this.id,
    required this.titre,
    this.consigne,
    this.dateLimite,
  });

  final String id;
  final String titre;
  final String? consigne;
  final DateTime? dateLimite;

  factory Exercice.fromMap(Map<String, dynamic> m) => Exercice(
    id: m['id'] as String,
    titre: m['titre'] as String,
    consigne: m['consigne'] as String?,
    dateLimite: m['date_limite'] == null
        ? null
        : DateTime.parse(m['date_limite'] as String).toLocal(),
  );
}

class Soumission {
  const Soumission({
    required this.id,
    this.contenu,
    this.fichierPath,
    this.note,
    this.commentaire,
    this.corrigeAt,
  });

  final String id;
  final String? contenu;
  final String? fichierPath;
  final double? note;
  final String? commentaire;
  final DateTime? corrigeAt;

  bool get corrigee => corrigeAt != null;

  factory Soumission.fromMap(Map<String, dynamic> m) => Soumission(
    id: m['id'] as String,
    contenu: m['contenu'] as String?,
    fichierPath: m['fichier_path'] as String?,
    note: (m['note'] as num?)?.toDouble(),
    commentaire: m['commentaire'] as String?,
    corrigeAt: m['corrige_at'] == null
        ? null
        : DateTime.parse(m['corrige_at'] as String).toLocal(),
  );
}
