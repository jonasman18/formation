/// Une copie d'apprenant à corriger (ou déjà corrigée).
class Copie {
  const Copie({
    required this.id,
    required this.apprenant,
    required this.exercice,
    required this.formation,
    required this.module,
    required this.soumisAt,
    this.consigne,
    this.contenu,
    this.note,
    this.commentaire,
    this.corrigeAt,
  });

  final String id;
  final String apprenant;
  final String exercice;
  final String formation;
  final String module;
  final DateTime soumisAt;
  final String? consigne;
  final String? contenu;
  final double? note;
  final String? commentaire;
  final DateTime? corrigeAt;

  bool get corrigee => corrigeAt != null;

  String? get noteTexte => note == null
      ? null
      : '${note!.toStringAsFixed(note! % 1 == 0 ? 0 : 2)} / 20';

  static Map<String, dynamic>? _map(Object? o) =>
      o is Map ? Map<String, dynamic>.from(o) : null;

  factory Copie.fromMap(Map<String, dynamic> m) {
    final p = _map(m['profiles']);
    final e = _map(m['exercices']);
    final mo = _map(e?['modules']);
    final f = _map(mo?['formations']);
    final nomComplet = '${p?['prenom'] ?? ''} ${p?['nom'] ?? ''}'.trim();

    return Copie(
      id: m['id'] as String,
      apprenant: nomComplet.isEmpty ? 'Apprenant' : nomComplet,
      exercice: (e?['titre'] as String?) ?? 'Exercice',
      consigne: e?['consigne'] as String?,
      module: (mo?['titre'] as String?) ?? '',
      formation: (f?['titre'] as String?) ?? '',
      contenu: m['contenu'] as String?,
      note: (m['note'] as num?)?.toDouble(),
      commentaire: m['commentaire'] as String?,
      soumisAt: DateTime.parse(m['soumis_at'] as String).toLocal(),
      corrigeAt: m['corrige_at'] == null
          ? null
          : DateTime.parse(m['corrige_at'] as String).toLocal(),
    );
  }
}
