import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../domain/quiz.dart';
import 'quiz_providers.dart';

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key, required this.formationId, required this.quizId});

  final String formationId;
  final String quizId;

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  // question -> choix cochés
  final Map<String, Set<String>> _reponses = {};
  bool _busy = false;
  QuizResultat? _resultat;

  int _sansReponse(Quiz quiz) =>
      quiz.questions.where((q) => (_reponses[q.id] ?? {}).isEmpty).length;

  Future<void> _envoyer(Quiz quiz) async {
    final vides = _sansReponse(quiz);
    if (vides > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Questions sans réponse'),
          content: Text(
            vides == 1
                ? 'Vous n\'avez pas répondu à 1 question. '
                      'Elle comptera comme fausse. Envoyer quand même ?'
                : 'Vous n\'avez pas répondu à $vides questions. '
                      'Elles compteront comme fausses. Envoyer quand même ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Revenir au quiz'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final payload = {
        for (final e in _reponses.entries) e.key: e.value.toList(),
      };
      final res = await ref
          .read(quizRepositoryProvider)
          .soumettre(widget.quizId, payload);
      if (mounted) setState(() => _resultat = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(humanError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _recommencer() {
    setState(() {
      _reponses.clear();
      _resultat = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final quiz = ref.watch(quizProvider(widget.quizId));

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: AsyncBody<Quiz>(
        value: quiz,
        onRetry: () => ref.invalidate(quizProvider(widget.quizId)),
        data: (q) =>
            _resultat == null ? _formulaire(q) : _resultatView(q, _resultat!),
      ),
    );
  }

  Widget _formulaire(Quiz quiz) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(quiz.titre, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Note minimale pour réussir : ${quiz.noteMin} %. '
          'Plusieurs réponses peuvent être justes.',
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < quiz.questions.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${i + 1}. ${quiz.questions[i].enonce}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  for (final c in quiz.questions[i].choix)
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(c.texte),
                      value: (_reponses[quiz.questions[i].id] ?? {}).contains(
                        c.id,
                      ),
                      onChanged: (v) => setState(() {
                        final set = _reponses.putIfAbsent(
                          quiz.questions[i].id,
                          () => <String>{},
                        );
                        if (v == true) {
                          set.add(c.id);
                        } else {
                          set.remove(c.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : () => _envoyer(quiz),
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Valider mes réponses'),
        ),
      ],
    );
  }

  Widget _resultatView(Quiz quiz, QuizResultat r) {
    final theme = Theme.of(context);
    final couleur = r.reussi ? Colors.green : theme.colorScheme.error;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          r.reussi ? Icons.emoji_events : Icons.sentiment_dissatisfied,
          size: 72,
          color: couleur,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${r.score} %',
            style: theme.textTheme.displayMedium?.copyWith(color: couleur),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            r.reussi ? 'Bravo, quiz réussi !' : 'Quiz non réussi',
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '${r.bonnes} bonne(s) réponse(s) sur ${r.total} '
            '(minimum requis : ${quiz.noteMin} %)',
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(onPressed: _recommencer, child: const Text('Recommencer')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () =>
              context.go('/catalogue/formation/${widget.formationId}/cours'),
          child: const Text('Retour au cours'),
        ),
      ],
    );
  }
}
