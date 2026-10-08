class ChoixEdition {
  const ChoixEdition({required this.texte, required this.correct});
  final String texte;
  final bool correct;

  factory ChoixEdition.fromMap(Map<String, dynamic> m) {
    // choix_corrects : objet si la ligne existe, null sinon
    final cc = m['choix_corrects'];
    final correct = cc is Map || (cc is List && cc.isNotEmpty);
    return ChoixEdition(texte: m['texte'] as String, correct: correct);
  }
}

class QuestionEdition {
  const QuestionEdition({
    required this.enonce,
    required this.ordre,
    required this.choix,
  });
  final String enonce;
  final int ordre;
  final List<ChoixEdition> choix;

  factory QuestionEdition.fromMap(Map<String, dynamic> m) => QuestionEdition(
    enonce: m['enonce'] as String,
    ordre: (m['ordre'] as num?)?.toInt() ?? 0,
    choix: ((m['choix'] as List?) ?? [])
        .map((e) => ChoixEdition.fromMap(e as Map<String, dynamic>))
        .toList(),
  );
}

class QuizEdition {
  const QuizEdition({
    required this.id,
    required this.titre,
    required this.noteMin,
    required this.questions,
  });
  final String id;
  final String titre;
  final int noteMin;
  final List<QuestionEdition> questions;

  factory QuizEdition.fromMap(Map<String, dynamic> m) {
    final questions =
        ((m['questions'] as List?) ?? [])
            .map((e) => QuestionEdition.fromMap(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.ordre.compareTo(b.ordre));
    return QuizEdition(
      id: m['id'] as String,
      titre: m['titre'] as String,
      noteMin: (m['note_min'] as num?)?.toInt() ?? 50,
      questions: questions,
    );
  }
}
