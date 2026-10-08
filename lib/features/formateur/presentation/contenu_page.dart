import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../../cours/domain/cours.dart';
import '../../cours/presentation/cours_providers.dart';
import 'formateur_providers.dart';

/// Modules et leçons d'une formation (côté formateur).
class ContenuPage extends ConsumerWidget {
  const ContenuPage({super.key, required this.formationId});
  final String formationId;

  int _suivant(Iterable<int> ordres) =>
      ordres.fold<int>(0, (a, o) => o > a ? o : a) + 1;

  Future<void> _executer(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(modulesProvider(formationId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(humanError(e))));
      }
    }
  }

  Future<bool> _confirmer(BuildContext context, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(message),
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
    return ok == true;
  }

  Future<void> _ajouterModule(
    BuildContext context,
    WidgetRef ref,
    List<Module> modules,
  ) async {
    final titre = await showDialog<String>(
      context: context,
      builder: (_) => const _TitreDialog(titre: 'Nouveau module'),
    );
    if (titre == null || !context.mounted) return;
    await _executer(
      context,
      ref,
      () => ref
          .read(formateurRepositoryProvider)
          .creerModule(
            formationId,
            titre,
            _suivant(modules.map((m) => m.ordre)),
          ),
    );
  }

  Future<void> _renommer(BuildContext context, WidgetRef ref, Module m) async {
    final titre = await showDialog<String>(
      context: context,
      builder: (_) =>
          _TitreDialog(titre: 'Renommer le module', initial: m.titre),
    );
    if (titre == null || !context.mounted) return;
    await _executer(
      context,
      ref,
      () => ref.read(formateurRepositoryProvider).renommerModule(m.id, titre),
    );
  }

  Future<void> _supprimerModule(
    BuildContext context,
    WidgetRef ref,
    Module m,
  ) async {
    final ok = await _confirmer(
      context,
      'Supprimer le module « ${m.titre} » avec ses leçons, quiz et exercices ?',
    );
    if (!ok || !context.mounted) return;
    await _executer(
      context,
      ref,
      () => ref.read(formateurRepositoryProvider).supprimerModule(m.id),
    );
  }

  IconData _icone(Lecon l) {
    if (l.videos.isNotEmpty) return Icons.play_circle_outline;
    if (l.pdfs.isNotEmpty) return Icons.picture_as_pdf_outlined;
    return Icons.article_outlined;
  }

  String _resume(Lecon l) {
    final p = <String>[
      if (l.aTexte) 'texte',
      if (l.videos.isNotEmpty) '${l.videos.length} vidéo(s)',
      if (l.pdfs.isNotEmpty) '${l.pdfs.length} PDF',
    ];
    return p.isEmpty ? 'vide' : p.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(modulesProvider(formationId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Contenu de la formation')),
      floatingActionButton: modules.asData == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  _ajouterModule(context, ref, modules.asData!.value),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau module'),
            ),
      body: AsyncBody<List<Module>>(
        value: modules,
        onRetry: () => ref.invalidate(modulesProvider(formationId)),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun module. Commencez par en créer un avec le bouton ci-dessous.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              for (final m in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(
                          m.titre,
                          style: theme.textTheme.titleMedium,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'renommer') _renommer(context, ref, m);
                            if (v == 'supprimer') {
                              _supprimerModule(context, ref, m);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'renommer',
                              child: Text('Renommer'),
                            ),
                            PopupMenuItem(
                              value: 'supprimer',
                              child: Text('Supprimer'),
                            ),
                          ],
                        ),
                      ),
                      for (final l in m.lecons)
                        ListTile(
                          dense: true,
                          leading: Icon(_icone(l)),
                          title: Text(l.titre),
                          subtitle: Text(_resume(l)),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: () => context.go(
                            '/formateur/formation/$formationId/contenu'
                            '/module/${m.id}/lecon/${l.id}',
                          ),
                        ),
                      for (final q in m.quizzes)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.quiz_outlined),
                          title: Text(q.titre),
                          subtitle: const Text('Quiz'),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: () => context.go(
                            '/formateur/formation/$formationId/contenu'
                            '/module/${m.id}/quiz/${q.id}',
                          ),
                        ),
                      for (final x in m.exercices)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.edit_note),
                          title: Text(x.titre),
                          subtitle: const Text('Exercice'),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: () => context.go(
                            '/formateur/formation/$formationId/contenu'
                            '/module/${m.id}/exercice/${x.id}',
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Wrap(
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: () => context.go(
                                '/formateur/formation/$formationId/contenu'
                                '/module/${m.id}/lecon/nouvelle',
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Leçon'),
                            ),
                            TextButton.icon(
                              onPressed: () => context.go(
                                '/formateur/formation/$formationId/contenu'
                                '/module/${m.id}/quiz/nouveau',
                              ),
                              icon: const Icon(Icons.quiz_outlined),
                              label: const Text('Quiz'),
                            ),
                            TextButton.icon(
                              onPressed: () => context.go(
                                '/formateur/formation/$formationId/contenu'
                                '/module/${m.id}/exercice/nouveau',
                              ),
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Exercice'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TitreDialog extends StatefulWidget {
  const _TitreDialog({required this.titre, this.initial = ''});
  final String titre;
  final String initial;

  @override
  State<_TitreDialog> createState() => _TitreDialogState();
}

class _TitreDialogState extends State<_TitreDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _valider() {
    final t = _controller.text.trim();
    if (t.isNotEmpty) Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titre),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Titre'),
        onSubmitted: (_) => _valider(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _valider, child: const Text('Valider')),
      ],
    );
  }
}
