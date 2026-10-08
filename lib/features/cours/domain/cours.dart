enum TypeLecon {
  video,
  pdf,
  texte;

  static TypeLecon fromString(String? v) => TypeLecon.values.firstWhere(
    (t) => t.name == v,
    orElse: () => TypeLecon.texte,
  );
}

/// Un fichier (PDF ou vidéo) rattaché à une leçon. Une leçon peut en avoir
/// plusieurs. Table « ressources ».
class Ressource {
  const Ressource({
    required this.id,
    required this.type,
    required this.url,
    required this.ordre,
    this.titre,
  });

  final String id;
  final TypeLecon type; // pdf ou video
  final String url; // chemin dans le bucket « documents »
  final int ordre;
  final String? titre;

  /// Nom lisible : le titre s'il existe, sinon le nom du fichier.
  String get nom {
    final t = titre;
    if (t != null && t.trim().isNotEmpty) return t;
    return url.split('/').last.replaceFirst(RegExp(r'^\d+_'), '');
  }

  factory Ressource.fromMap(Map<String, dynamic> m) => Ressource(
    id: m['id'] as String,
    type: TypeLecon.fromString(m['type'] as String?),
    url: m['url'] as String,
    ordre: (m['ordre'] as num?)?.toInt() ?? 0,
    titre: m['titre'] as String?,
  );
}

class Lecon {
  const Lecon({
    required this.id,
    required this.titre,
    required this.type,
    required this.ordre,
    this.contenu,
    this.url,
    this.dureeSec,
    this.ressources = const [],
  });

  final String id;
  final String titre;
  final TypeLecon type; // ancien champ, conservé pour la transition
  final int ordre;
  final String? contenu;
  final String? url; // ancien champ, conservé pour la transition
  final int? dureeSec;
  final List<Ressource> ressources;

  List<Ressource> get pdfs =>
      ressources.where((r) => r.type == TypeLecon.pdf).toList();

  List<Ressource> get videos =>
      ressources.where((r) => r.type == TypeLecon.video).toList();

  bool get aTexte => contenu != null && contenu!.trim().isNotEmpty;

  factory Lecon.fromMap(Map<String, dynamic> m) {
    final ressources =
        ((m['ressources'] as List?) ?? [])
            .map((e) => Ressource.fromMap(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.ordre.compareTo(b.ordre));
    return Lecon(
      id: m['id'] as String,
      titre: m['titre'] as String,
      type: TypeLecon.fromString(m['type'] as String?),
      ordre: (m['ordre'] as num?)?.toInt() ?? 0,
      contenu: m['contenu'] as String?,
      url: m['url'] as String?,
      dureeSec: (m['duree_sec'] as num?)?.toInt(),
      ressources: ressources,
    );
  }
}

/// Quiz rattaché à un module (juste de quoi l'afficher dans la liste).
class QuizResume {
  const QuizResume({required this.id, required this.titre});
  final String id;
  final String titre;

  factory QuizResume.fromMap(Map<String, dynamic> m) =>
      QuizResume(id: m['id'] as String, titre: m['titre'] as String);
}

class ExerciceResume {
  const ExerciceResume({required this.id, required this.titre});
  final String id;
  final String titre;

  factory ExerciceResume.fromMap(Map<String, dynamic> m) =>
      ExerciceResume(id: m['id'] as String, titre: m['titre'] as String);
}

class Module {
  const Module({
    required this.id,
    required this.titre,
    required this.ordre,
    required this.lecons,
    required this.quizzes,
    required this.exercices,
  });

  final String id;
  final String titre;
  final int ordre;
  final List<Lecon> lecons;
  final List<QuizResume> quizzes;
  final List<ExerciceResume> exercices;

  factory Module.fromMap(Map<String, dynamic> m) {
    final lecons =
        ((m['lecons'] as List?) ?? [])
            .map((e) => Lecon.fromMap(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.ordre.compareTo(b.ordre));
    final quizzes = ((m['quiz'] as List?) ?? [])
        .map((e) => QuizResume.fromMap(e as Map<String, dynamic>))
        .toList();
    final exercices = ((m['exercices'] as List?) ?? [])
        .map((e) => ExerciceResume.fromMap(e as Map<String, dynamic>))
        .toList();
    return Module(
      id: m['id'] as String,
      titre: m['titre'] as String,
      ordre: (m['ordre'] as num?)?.toInt() ?? 0,
      lecons: lecons,
      quizzes: quizzes,
      exercices: exercices,
    );
  }
}
