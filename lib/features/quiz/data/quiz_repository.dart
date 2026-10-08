import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/quiz.dart';

class QuizRepository {
  QuizRepository(this._client);
  final SupabaseClient _client;

  /// Questions et choix, SANS les bonnes réponses (elles restent côté serveur).
  Future<Quiz> fetchQuiz(String quizId) async {
    final row = await _client
        .from('quiz')
        .select(
          'id, titre, note_min, questions(id, enonce, ordre, choix(id, texte))',
        )
        .eq('id', quizId)
        .single();
    return Quiz.fromMap(row);
  }

  /// [reponses] : identifiant de question -> identifiants des choix cochés.
  /// La correction est faite par la fonction SQL soumettre_quiz.
  Future<QuizResultat> soumettre(
    String quizId,
    Map<String, List<String>> reponses,
  ) async {
    final res = await _client.rpc(
      'soumettre_quiz',
      params: {'p_quiz_id': quizId, 'p_reponses': reponses},
    );
    return QuizResultat.fromMap(Map<String, dynamic>.from(res as Map));
  }
}
