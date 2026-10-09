import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../../cours/presentation/cours_providers.dart';
import '../../quiz/presentation/quiz_providers.dart';
import '../domain/quiz_edition.dart';
import 'formateur_providers.dart';
import '../../../shared/utils/pick_file.dart';
import '../data/quiz_ia_service.dart';

/// Création (quizId == null) ou modification d'un quiz.
class QuizEditPage extends ConsumerWidget {
  const QuizEditPage({
    super.key,
    required this.formationId,
    required this.moduleId,
    this.quizId,
  });

  final String formationId;
  final String moduleId;
  final String? quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(quizId == null ? 'Nouveau quiz' : 'Modifier le quiz'),
      ),
      body: quizId == null
          ? _QuizForm(formationId: formationId, moduleId: moduleId)
          : AsyncBody<QuizEdition>(
              value: ref.watch(quizEditionProvider(quizId!)),
              onRetry: () => ref.invalidate(quizEditionProvider(quizId!)),
              data: (q) => _QuizForm(
                key: ValueKey(q.id),
                formationId: formationId,
                moduleId: moduleId,
                initial: q,
              ),
            ),
    );
  }
}

class _ChoixCtl {
  _ChoixCtl({String texte = '', this.correct = false})
    : texte = TextEditingController(text: texte);
  final TextEditingController texte;
  bool correct;
  void dispose() => texte.dispose();
}

class _QuestionCtl {
  _QuestionCtl({String enonce = '', List<_ChoixCtl>? choix})
    : enonce = TextEditingController(text: enonce),
      choix = choix ?? [_ChoixCtl(), _ChoixCtl()];
  final TextEditingController enonce;
  final List<_ChoixCtl> choix;

  void dispose() {
    enonce.dispose();
    for (final c in choix) {
      c.dispose();
    }
  }
}

class _QuizForm extends ConsumerStatefulWidget {
  const _QuizForm({
    super.key,
    required this.formationId,
    required this.moduleId,
    this.initial,
  });

  final String formationId;
  final String moduleId;
  final QuizEdition? initial;

  @override
  ConsumerState<_QuizForm> createState() => _QuizFormState();
}

class _QuizFormState extends ConsumerState<_QuizForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titre;
  late final List<_QuestionCtl> _questions;
  late double _noteMin;
  bool _busy = false;
  bool _generation = false;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _titre = TextEditingController(text: q?.titre ?? '');
    _noteMin = (q?.noteMin ?? 50).toDouble();
    _questions = (q == null || q.questions.isEmpty)
        ? [_QuestionCtl()]
        : [
            for (final qu in q.questions)
              _QuestionCtl(
                enonce: qu.enonce,
                choix: [
                  for (final c in qu.choix)
                    _ChoixCtl(texte: c.texte, correct: c.correct),
                ],
              ),
          ];
  }

  @override
  void dispose() {
    _titre.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  String get _retour => '/formateur/formation/${widget.formationId}/contenu';

  void _msg(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  String? _verifier() {
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.choix.length < 2) {
        return 'Question ${i + 1} : au moins 2 choix sont nécessaires.';
      }
      if (!q.choix.any((c) => c.correct)) {
        return 'Question ${i + 1} : cochez au moins une bonne réponse.';
      }
    }
    return null;
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final erreur = _verifier();
    if (erreur != null) {
      _msg(erreur);
      return;
    }

    final router = GoRouter.of(context);
    final repo = ref.read(formateurRepositoryProvider);
    final questions = [
      for (final q in _questions)
        {
          'enonce': q.enonce.text.trim(),
          'choix': [
            for (final c in q.choix)
              {'texte': c.texte.text.trim(), 'correct': c.correct},
          ],
        },
    ];

    setState(() => _busy = true);
    try {
      await repo.enregistrerQuiz(
        moduleId: widget.moduleId,
        quizId: widget.initial?.id,
        titre: _titre.text.trim(),
        noteMin: _noteMin.round(),
        questions: questions,
      );
      ref.invalidate(modulesProvider(widget.formationId));
      ref.invalidate(quizEditionProvider);
      ref.invalidate(quizProvider);
      router.go(_retour);
    } catch (e) {
      _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce quiz ?'),
        content: const Text(
          'Les questions et les résultats des apprenants seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final router = GoRouter.of(context);
    final repo = ref.read(formateurRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repo.supprimerQuiz(widget.initial!.id);
      ref.invalidate(modulesProvider(widget.formationId));
      ref.invalidate(quizEditionProvider);
      ref.invalidate(quizProvider);
      router.go(_retour);
    } catch (e) {
      _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titre,
            decoration: const InputDecoration(
              labelText: 'Titre du quiz',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Le titre est obligatoire'
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            'Note minimale pour réussir : ${_noteMin.round()} %',
            style: theme.textTheme.titleSmall,
          ),
          Slider(
            value: _noteMin,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_noteMin.round()} %',
            onChanged: _busy ? null : (v) => setState(() => _noteMin = v),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: (_busy || _generation) ? null : _genererDepuisPdf,
            icon: _generation
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              _generation
                  ? 'Génération en cours…'
                  : 'Générer des questions depuis un PDF',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Le PDF est envoyé à Google Gemini. Les questions générées sont '
            'des suggestions : relisez-les avant d\'enregistrer.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('Questions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Cochez toutes les bonnes réponses de chaque question.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _questions.length; i++) _carteQuestion(i),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() => _questions.add(_QuestionCtl())),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une question'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _enregistrer,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer le quiz'),
          ),
          if (widget.initial != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _supprimer,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              label: Text(
                'Supprimer le quiz',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<int?> _demanderNombre() {
    var n = 10.0;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nombre de questions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${n.round()} questions',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              Slider(
                value: n,
                min: 1,
                max: 30,
                divisions: 29,
                label: '${n.round()}',
                onChanged: (v) => setLocal(() => n = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, n.round()),
              child: const Text('Générer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _genererDepuisPdf() async {
    final f = await choisirFichier(extensions: ['pdf']);
    if (f == null || !mounted) return;
    if (f.octets.length > 8 * 1024 * 1024) {
      _msg('PDF trop volumineux pour la génération (8 Mo maximum).');
      return;
    }
    final nb = await _demanderNombre();
    if (nb == null || !mounted) return;

    final service = ref.read(quizIaServiceProvider);
    setState(() => _generation = true);
    try {
      final r = await service.generer(f.octets, nbQuestions: nb);
      if (!mounted) return;
      setState(() {
        // on remplace la question vide du départ
        if (_questions.length == 1 &&
            _questions.first.enonce.text.trim().isEmpty) {
          _questions.removeAt(0).dispose();
        }
        if (_titre.text.trim().isEmpty && r.titre.isNotEmpty) {
          _titre.text = r.titre;
        }
        for (final q in r.questions) {
          _questions.add(
            _QuestionCtl(
              enonce: q.enonce,
              choix: [
                for (final c in q.choix)
                  _ChoixCtl(texte: c.texte, correct: c.correct),
              ],
            ),
          );
        }
      });
      _msg(
        '${r.questions.length} questions générées. '
        'Relisez-les avant d\'enregistrer.',
      );
    } catch (e) {
      _msg(e is QuizIaException ? e.message : humanError(e));
    } finally {
      if (mounted) setState(() => _generation = false);
    }
  }

  Widget _carteQuestion(int i) {
    final q = _questions[i];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${i + 1}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (_questions.length > 1)
                  IconButton(
                    tooltip: 'Supprimer la question',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy
                        ? null
                        : () =>
                              setState(() => _questions.removeAt(i).dispose()),
                  ),
              ],
            ),
            TextFormField(
              controller: q.enonce,
              decoration: const InputDecoration(
                labelText: 'Énoncé',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Écrivez l\'énoncé' : null,
            ),
            const SizedBox(height: 8),
            for (var j = 0; j < q.choix.length; j++)
              Row(
                children: [
                  Checkbox(
                    value: q.choix[j].correct,
                    onChanged: _busy
                        ? null
                        : (v) =>
                              setState(() => q.choix[j].correct = v ?? false),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: q.choix[j].texte,
                      decoration: InputDecoration(
                        labelText: 'Choix ${j + 1}',
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Texte obligatoire'
                          : null,
                    ),
                  ),
                  if (q.choix.length > 2)
                    IconButton(
                      tooltip: 'Retirer ce choix',
                      icon: const Icon(Icons.close),
                      onPressed: _busy
                          ? null
                          : () => setState(() => q.choix.removeAt(j).dispose()),
                    ),
                ],
              ),
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () => setState(() => q.choix.add(_ChoixCtl())),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un choix'),
            ),
          ],
        ),
      ),
    );
  }
}
