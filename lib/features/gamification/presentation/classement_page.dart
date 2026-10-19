import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gamification_service.dart';

class ClassementPage extends ConsumerWidget {
  const ClassementPage({super.key});

  String _rang(int r) => switch (r) {
    1 => '🥇',
    2 => '🥈',
    3 => '🥉',
    _ => '$r',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final etat = ref.watch(classementProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Classement')),
      body: etat.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Impossible de charger le classement.'),
              TextButton(
                onPressed: () => ref.invalidate(classementProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (liste) {
          if (liste.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Personne n\'est encore classé. Terminez une leçon pour '
                  'gagner vos premiers points !',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(classementProvider);
              await ref.read(classementProvider.future);
            },
            child: ListView.separated(
              itemCount: liste.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = liste[i];
                final initiale =
                    e.nom.isEmpty ? '?' : e.nom.substring(0, 1).toUpperCase();
                return Container(
                  color: e.moi ? theme.colorScheme.primaryContainer : null,
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            _rang(e.rang),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundImage: e.avatarUrl == null
                              ? null
                              : NetworkImage(e.avatarUrl!),
                          child: e.avatarUrl == null ? Text(initiale) : null,
                        ),
                      ],
                    ),
                    title: Text(e.moi ? '${e.nom} (vous)' : e.nom),
                    subtitle: Text(e.niveau),
                    trailing: Text(
                      '${e.points} pts',
                      style: theme.textTheme.titleSmall,
                    ),
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