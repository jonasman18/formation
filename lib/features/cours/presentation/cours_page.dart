import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/async_body.dart';
import '../domain/cours.dart';
import 'cours_providers.dart';

class CoursPage extends ConsumerWidget {
  const CoursPage({super.key, required this.formationId});
  final String formationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(modulesProvider(formationId));
    final terminees = ref.watch(leconsTermineesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cours')),
      body: AsyncBody<List<Module>>(
        value: modules,
        onRetry: () => ref.invalidate(modulesProvider(formationId)),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('Le contenu de ce cours sera bientôt disponible.'),
            );
          }

          final faites = terminees.asData?.value ?? <String>{};
          final toutes = [for (final m in items) ...m.lecons];
          final nbFaites = toutes.where((l) => faites.contains(l.id)).length;
          final pct =
              toutes.isEmpty ? 0 : (100 * nbFaites / toutes.length).round();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Progression : $pct %', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: pct / 100),
              const SizedBox(height: 4),
              Text('$nbFaites / ${toutes.length} leçon(s) terminée(s)'),
              const SizedBox(height: 16),
              for (final m in items)
                Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(m.titre),
                    children: [
                      for (final l in m.lecons)
                        ListTile(
                          leading: Icon(
                            faites.contains(l.id)
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            color: faites.contains(l.id) ? Colors.green : null,
                          ),
                          title: Text(l.titre),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(
                                                        '/catalogue/formation/$formationId/cours/lecon/${l.id}',
                          ),
                        ),
                      for (final q in m.quizzes)
                        ListTile(
                          leading: const Icon(Icons.quiz_outlined),
                          title: Text(q.titre),
                          subtitle: const Text('Quiz'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(
                            '/catalogue/formation/$formationId/cours/quiz/${q.id}',
                          ),
                        ),
                        for (final x in m.exercices)
                        ListTile(
                          leading: const Icon(Icons.edit_note),
                          title: Text(x.titre),
                          subtitle: const Text('Exercice'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go(
                            '/catalogue/formation/$formationId/cours/exercice/${x.id}',
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