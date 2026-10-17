import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/utils/pick_file.dart';
import '../../../shared/widgets/async_body.dart';
import '../data/examen_repository.dart';
import '../data/quiz_ia_service.dart';

class ExamenEditPage extends ConsumerWidget {
  const ExamenEditPage({super.key, required this.formationId});

  final String formationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Examen final')),
      body: AsyncBody<Map<String, dynamic>?>(
        value: ref.watch(examenEditionProvider(formationId)),
        onRetry: () => ref.invalidate(examenEditionProvider(formationId)),
        data: (d) => _ExamenForm(
          key: ValueKey(d?['id'] ?? 'nouveau'),
          formationId: formationId,
          initial: d,
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

class _ExamenForm extends ConsumerStatefulWidget {
  const _ExamenForm({super.key, required this.formationId, this.initial});

  final String formationId;
  final Map<String, dynamic>? initial;

  @override
  ConsumerState<_ExamenForm> createState() => _ExamenFormState();
}

class _ExamenFormState extends ConsumerState<_ExamenForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titre;
  late final TextEditingController _duree;
  late final TextEditingController _tentatives;
  late final TextEditingController _delai;
  late final List<_QuestionCtl> _questions;
  late double _noteMin;
  late bool _publie;
  late final bool _verrouille;
  bool _busy = false;
  bool _generation = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _titre = TextEditingController(
      text: (d?['titre'] as String?) ?? 'Examen final',
    );
    _duree = TextEditingController(text: '${d?['duree_min'] ?? 30}');
    _tentatives = TextEditingController(text: '${d?['max_tentatives'] ?? 2}');
    final heures = (d?['delai_reprise_h'] as num?)?.toInt() ?? 24;
    _delai = TextEditingController(text: '${(heures / 24).ceil()}');
    _noteMin = ((d?['note_min'] as num?) ?? 60).toDouble();
    _publie = (d?['publie'] as bool?) ?? false;
    _verrouille = (d?['verrouille'] as bool?) ?? false;
    final qs = (d?['questions'] as List?) ?? const [];
    _questions = qs.isEmpty
        ? [_QuestionCtl()]
        : [
            for (final q in qs)
              _QuestionCtl(
                enonce: q['enonce'] as String,
                choix: [
                  for (final c in q['choix'] as List)
                    _ChoixCtl(
                      texte: c['texte'] as String,
                      correct: c['correct'] as bool,
                    ),
                ],
              ),
          ];
  }

  @override
  void dispose() {
    _titre.dispose();
    _duree.dispose();
    _tentatives.dispose();
    _delai.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

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
    if (_publie && _questions.isEmpty) {
      return 'Ajoutez au moins une question avant de publier.';
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
    final repo = ref.read(examenRepositoryProvider);
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
      await repo.enregistrer(
        formationId: widget.formationId,
        titre: _titre.text.trim(),
        noteMin: _noteMin.round(),
        dureeMin: int.parse(_duree.text.trim()),
        maxTentatives: int.parse(_tentatives.text.trim()),
        delaiRepriseH: int.parse(_delai.text.trim()) * 24,
        publie: _publie,
        questions: questions,
      );
      ref.invalidate(examenEditionProvider(widget.formationId));
      _msg(_publie ? 'Examen enregistré et publié' : 'Examen enregistré');
      if (router.canPop()) router.pop();
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
        title: const Text('Supprimer l\'examen ?'),
        content: const Text('Toutes ses questions seront supprimées.'),
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
    final repo = ref.read(examenRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repo.supprimer(widget.formationId);
      ref.invalidate(examenEditionProvider(widget.formationId));
      if (router.canPop()) router.pop();
    } catch (e) {
      _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        if (_questions.length == 1 &&
            _questions.first.enonce.text.trim().isEmpty) {
          _questions.removeAt(0).dispose();
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

  String? _entierPositif(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return (n == null || n < 1) ? 'Nombre ≥ 1' : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_verrouille)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Des apprenants ont déjà passé cet examen. Vos modifications '
                  's\'appliqueront aux prochaines tentatives ; les notes déjà '
                  'obtenues ne changent pas.',
                ),
              ),
            ),
            IgnorePointer(
            ignoring: false,
            child: Opacity(
              opacity: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titre,
                    decoration: const InputDecoration(
                      labelText: 'Titre de l\'examen',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Le titre est obligatoire'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _duree,
                          decoration: const InputDecoration(
                            labelText: 'Durée (minutes)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _entierPositif,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _tentatives,
                          decoration: const InputDecoration(
                            labelText: 'Tentatives max',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: _entierPositif,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _delai,
                    decoration: const InputDecoration(
                      labelText: 'Délai avant de retenter (jours)',
                      helperText:
                          'Quand les tentatives sont épuisées, l\'apprenant '
                          'peut recommencer après ce délai (7 = une semaine).',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: _entierPositif,
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
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _noteMin = v),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: (_busy || _generation)
                        ? null
                        : _genererDepuisPdf,
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
                    'Le PDF est envoyé à Google Gemini. Les questions générées '
                    'sont des suggestions : relisez-les avant d\'enregistrer.',
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Publier l\'examen'),
            subtitle: const Text(
              'Les apprenants à 100 % de progression pourront le passer. '
              'Le certificat exigera sa réussite.',
            ),
            value: _publie,
            onChanged: _busy ? null : (v) => setState(() => _publie = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _enregistrer,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer l\'examen'),
          ),
          if (widget.initial != null && !_verrouille) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _supprimer,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              label: Text(
                'Supprimer l\'examen',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
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