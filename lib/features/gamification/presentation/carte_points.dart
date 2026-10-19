import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/gamification_service.dart';

IconData _iconeBadge(String code) => switch (code) {
  'premiere_lecon' => Icons.menu_book_outlined,
  'premier_quiz' => Icons.quiz_outlined,
  'examen_reussi' => Icons.workspace_premium_outlined,
  'formation_terminee' => Icons.flag_outlined,
  'certifie' => Icons.verified_outlined,
  _ => Icons.military_tech_outlined,
};

/// Carte de gamification affichée sur le profil de l'apprenant.
class CartePoints extends ConsumerWidget {
  const CartePoints({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final etat = ref.watch(mesPointsProvider);

    return etat.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Impossible de charger vos points'),
          trailing: TextButton(
            onPressed: () => ref.invalidate(mesPointsProvider),
            child: const Text('Réessayer'),
          ),
        ),
      ),
      data: (p) {
        if (!p.apprenant) return const SizedBox.shrink();

        final simples = p.badges
            .where((b) => b.code != 'formation_terminee' && b.code != 'certifie')
            .toList();
        final formations =
            p.badges.where((b) => b.code == 'formation_terminee').toList();
        final certifs = p.badges.where((b) => b.code == 'certifie').toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text('${p.niveau.numero}'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.niveau.nom,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text('${p.points} points'),
                        ],
                      ),
                    ),
                    if (p.rang != null)
                      Chip(
                        avatar: const Icon(Icons.emoji_events_outlined,
                            size: 18),
                        label: Text('#${p.rang}'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: p.progression,
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.restant == null
                      ? 'Niveau maximum atteint 🎉'
                      : 'Encore ${p.restant} pts pour le niveau suivant',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Text('Badges', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (p.badges.isEmpty)
                  Text(
                    'Terminez une leçon pour gagner votre premier badge.',
                    style: theme.textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final b in simples)
                        ActionChip(
                          avatar: Icon(_iconeBadge(b.code), size: 18),
                          label: Text(b.titre),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${b.titre} : ${b.description}'),
                              ),
                            );
                          },
                        ),
                      if (formations.isNotEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.flag_outlined, size: 18),
                          label: Text(
                            'Formations terminées (${formations.length})',
                          ),
                          onPressed: () => _voirListe(
                            context,
                            'Formations terminées',
                            formations,
                          ),
                        ),
                      if (certifs.isNotEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.verified_outlined, size: 18),
                          label: Text('Certifications (${certifs.length})'),
                          onPressed: () =>
                              _voirListe(context, 'Certifications', certifs),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Apparaître dans le classement'),
                  value: p.visible,
                  onChanged: (v) async {
                    await definirClassementVisible(v);
                    ref.invalidate(mesPointsProvider);
                    ref.invalidate(classementProvider);
                  },
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/profil/classement'),
                    icon: const Icon(Icons.leaderboard_outlined),
                    label: const Text('Voir le classement'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _voirListe(BuildContext context, String titre, List<BadgeInfo> items) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final b in items)
              ListTile(
                dense: true,
                leading: Icon(_iconeBadge(b.code)),
                title: Text(b.description),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Fermer'),
        ),
      ],
    ),
  );
}