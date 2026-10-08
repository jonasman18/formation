import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/quiz_edition.dart';

class QuizIaException implements Exception {
  const QuizIaException(this.message);
  final String message;
  @override
  String toString() => message;
}

class QuizGenere {
  const QuizGenere({required this.titre, required this.questions});
  final String titre;
  final List<QuestionEdition> questions;
}

class QuizIaService {
  QuizIaService(this._client);
  final SupabaseClient _client;

  Future<QuizGenere> generer(Uint8List pdf, {required int nbQuestions}) async {
    try {
      final res = await _client.functions.invoke(
        'generer-quiz',
        body: {'pdf_base64': base64Encode(pdf), 'nb_questions': nbQuestions},
      );
      final data = res.data;
      if (data is! Map) {
        throw const QuizIaException('Réponse inattendue du serveur.');
      }

      final questions = <QuestionEdition>[];
      var ordre = 0;
      for (final q in (data['questions'] as List? ?? const [])) {
        final qm = q as Map;
        final choix = <ChoixEdition>[];
        for (final c in (qm['choix'] as List? ?? const [])) {
          final cm = c as Map;
          choix.add(
            ChoixEdition(
              texte: cm['texte'] as String,
              correct: cm['correct'] == true,
            ),
          );
        }
        questions.add(
          QuestionEdition(
            enonce: qm['enonce'] as String,
            ordre: ++ordre,
            choix: choix,
          ),
        );
      }
      if (questions.isEmpty) {
        throw const QuizIaException('Aucune question générée.');
      }
      return QuizGenere(
        titre: (data['titre'] as String?) ?? '',
        questions: questions,
      );
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map && d['error'] is String
          ? d['error'] as String
          : 'Le service de génération est indisponible (${e.status}).';
      throw QuizIaException(msg);
    }
  }
}

final quizIaServiceProvider = Provider<QuizIaService>(
  (ref) => QuizIaService(Supabase.instance.client),
);