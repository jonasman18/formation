class Choix {
  const Choix({required this.id, required this.texte});
  final String id;
  final String texte;

  factory Choix.fromMap(Map<String, dynamic> m) =>
      Choix(id: m['id'] as String, texte: m['texte'] as String);
}

class Question {
  const Question({
    required this.id,
    required this.enonce,
    required this.ordre,
    required this.choix,
  });

  final String id;
  final String enonce;
  final int ordre;
  final List<Choix> choix;

  factory Question.fromMap(Map<String, dynamic> m) => Question(
        id: m['id'] as String,
        enonce: m['enonce'] as String,
        ordre: (m['ordre'] as num?)?.toInt() ?? 0,
        choix: ((m['choix'] as List?) ?? [])
            .map((e) => Choix.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

class Quiz {
  const Quiz({
    required this.id,
    required this.titre,
    required this.noteMin,
    required this.questions,
  });

  final String id;
  final String titre;
  final int noteMin;
  final List<Question> questions;

  factory Quiz.fromMap(Map<String, dynamic> m) {
    final questions = ((m['questions'] as List?) ?? [])
        .map((e) => Question.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ordre.compareTo(b.ordre));
    return Quiz(
      id: m['id'] as String,
      titre: m['titre'] as String,
      noteMin: (m['note_min'] as num?)?.toInt() ?? 50,
      questions: questions,
    );
  }
}

class QuizResultat {
  const QuizResultat({
    required this.score,
    required this.reussi,
    required this.bonnes,
    required this.total,
  });

  final int score;
  final bool reussi;
  final int bonnes;
  final int total;

  factory QuizResultat.fromMap(Map<String, dynamic> m) => QuizResultat(
        score: (m['score'] as num).toInt(),
        reussi: m['reussi'] as bool,
        bonnes: (m['bonnes'] as num).toInt(),
        total: (m['total'] as num).toInt(),
      );
}