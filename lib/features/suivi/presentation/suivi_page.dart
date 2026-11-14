import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/async_body.dart';
import '../data/suivi_service.dart';

class SuiviPage extends ConsumerWidget {
  const SuiviPage({super.key, required this.formationId});

  final String formationId;

  String _quiz(SuiviApprenant e) {
    if (e.quizTotal == 0) return 'Quiz : aucun';
    final moy = e.quizMoyenne == null ? '' : ' · moyenne ${e.quizMoyenne} %';
    return 'Quiz : ${e.quizReussis}/${e.quizTotal} réussis$moy';
  }

  String? _examen(SuiviApprenant e) {
    if (!e.examenExiste) return null;
    if (e.examenTentatives == 0) return 'Examen : pas encore passé';
    final s = e.examenScore == null ? '' : ' (meilleur : ${e.examenScore} %)';
    return e.examenReussi ? 'Examen : réussi$s' : 'Examen : non réussi$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Suivi des apprenants')),
      body: AsyncBody<List<SuiviApprenant>>(
        value: ref.watch(suiviApprenantsProvider(formationId)),
        onRetry: () => ref.invalidate(suiviApprenantsProvider(formationId)),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun apprenant n\'est inscrit à cette formation.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(suiviApprenantsProvider(formationId));
              await ref.read(suiviApprenantsProvider(formationId).future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      '${items.length} apprenant(s) inscrit(s)',
                      style: theme.textTheme.titleSmall,
                    ),
                  );
                }
                final e = items[i - 1];
                final examen = _examen(e);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => context.push(
                      '/formateur/formation/$formationId/suivi/${e.id}',
                    ),
                    leading: CircleAvatar(
                      backgroundImage: e.avatarUrl == null
                          ? null
                          : NetworkImage(e.avatarUrl!),
                      child: e.avatarUrl == null
                          ? Text(e.nom.substring(0, 1).toUpperCase())
                          : null,
                    ),
                    title: Text(e.nom),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: (e.pourcentage / 100).clamp(0.0, 1.0),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Progression : ${e.pourcentage} % '
                          '(${e.leconsTerminees}/${e.totalLecons} leçons)',
                        ),
                        Text(_quiz(e)),
                        if (examen != null) Text(examen),
                        Text('Rendus : ${e.rendus}/${e.exercicesTotal}'),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: e.certifie
                        ? const Icon(Icons.verified_outlined)
                        : const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}