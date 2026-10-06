enum TypeLecon {
  video,
  pdf,
  texte;

  static TypeLecon fromString(String? v) => TypeLecon.values.firstWhere(
        (t) => t.name == v,
        orElse: () => TypeLecon.texte,
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
  });

  final String id;
  final String titre;
  final TypeLecon type;
  final int ordre;
  final String? contenu;
  final String? url;
  final int? dureeSec;

  factory Lecon.fromMap(Map<String, dynamic> m) => Lecon(
        id: m['id'] as String,
        titre: m['titre'] as String,
        type: TypeLecon.fromString(m['type'] as String?),
        ordre: (m['ordre'] as num?)?.toInt() ?? 0,
        contenu: m['contenu'] as String?,
        url: m['url'] as String?,
        dureeSec: (m['duree_sec'] as num?)?.toInt(),
      );
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
    final lecons = ((m['lecons'] as List?) ?? [])
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