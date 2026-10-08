import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../domain/exercice.dart';
import 'exercices_providers.dart';

class ExercicePage extends ConsumerStatefulWidget {
  const ExercicePage({
    super.key,
    required this.formationId,
    required this.exerciceId,
  });

  final String formationId;
  final String exerciceId;

  @override
  ConsumerState<ExercicePage> createState() => _ExercicePageState();
}

class _ExercicePageState extends ConsumerState<ExercicePage> {
  final _controller = TextEditingController();
  bool _edition = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _note(double n) => '${n.toStringAsFixed(n % 1 == 0 ? 0 : 2)} / 20';

  Future<void> _envoyer() async {
    final texte = _controller.text.trim();
    if (texte.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Écrivez votre réponse avant d\'envoyer.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(exercicesRepositoryProvider)
          .soumettre(widget.exerciceId, texte);
      ref.invalidate(maSoumissionProvider(widget.exerciceId));
      await ref.read(maSoumissionProvider(widget.exerciceId).future);
      if (mounted) {
        setState(() => _edition = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Réponse envoyée ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(humanError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exo = ref.watch(exerciceProvider(widget.exerciceId));
    final soum = ref.watch(maSoumissionProvider(widget.exerciceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Exercice')),
      body: AsyncBody<Exercice>(
        value: exo,
        onRetry: () => ref.invalidate(exerciceProvider(widget.exerciceId)),
        data: (e) => AsyncBody<Soumission?>(
          value: soum,
          onRetry: () =>
              ref.invalidate(maSoumissionProvider(widget.exerciceId)),
          data: (s) => _contenu(e, s),
        ),
      ),
    );
  }

  Widget _contenu(Exercice e, Soumission? s) {
    final theme = Theme.of(context);
    final enRetard =
        e.dateLimite != null && DateTime.now().isAfter(e.dateLimite!);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(e.titre, style: theme.textTheme.headlineSmall),
        if (e.dateLimite != null) ...[
          const SizedBox(height: 4),
          Text(
            'À rendre avant le ${_date(e.dateLimite!)}'
            '${enRetard ? ' (date dépassée)' : ''}',
            style: TextStyle(color: enRetard ? theme.colorScheme.error : null),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          e.consigne ?? 'Aucune consigne.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        if (s == null || _edition) ..._formulaire(s) else ..._lecture(s),
      ],
    );
  }

  List<Widget> _formulaire(Soumission? s) => [
    Text('Votre réponse', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    TextField(
      controller: _controller,
      minLines: 6,
      maxLines: 14,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Écrivez votre réponse ici…',
      ),
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: _busy ? null : _envoyer,
      icon: _busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send),
      label: Text(s == null ? 'Envoyer' : 'Enregistrer les modifications'),
    ),
    if (s != null)
      TextButton(
        onPressed: _busy ? null : () => setState(() => _edition = false),
        child: const Text('Annuler'),
      ),
  ];

  List<Widget> _lecture(Soumission s) {
    final theme = Theme.of(context);
    return [
      Row(
        children: [
          Icon(
            s.corrigee ? Icons.task_alt : Icons.hourglass_top,
            color: s.corrigee ? Colors.green : null,
          ),
          const SizedBox(width: 8),
          Text(
            s.corrigee ? 'Corrigé' : 'Envoyé, en attente de correction',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(width: double.infinity, child: Text(s.contenu ?? '')),
        ),
      ),
      if (s.corrigee) ...[
        const SizedBox(height: 16),
        if (s.note != null)
          Text(
            'Note : ${_note(s.note!)}',
            style: theme.textTheme.headlineSmall,
          ),
        if ((s.commentaire ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Commentaire du formateur', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(s.commentaire!),
        ],
      ] else ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _controller.text = s.contenu ?? '';
            _edition = true;
          }),
          icon: const Icon(Icons.edit),
          label: const Text('Modifier ma réponse'),
        ),
      ],
    ];
  }
}
