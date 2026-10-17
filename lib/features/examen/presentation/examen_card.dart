import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/examen_service.dart';

class ExamenCard extends ConsumerWidget {
  const ExamenCard({super.key, required this.formationId});

  final String formationId;

  Future<void> _commencer(BuildContext context, ExamenInfos i) async {
    if (!i.enCours) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Commencer l\'examen ?'),
          content: Text(
            'Le chronomètre démarre tout de suite (${i.dureeMin} min) et ne '
            's\'arrête pas, même si vous quittez l\'application. '
            'Cette tentative sera comptée.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Pas maintenant'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Commencer'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    final container = ProviderScope.containerOf(context);
    await context.push('/catalogue/formation/$formationId/cours/examen');
    container.invalidate(examenInfosProvider(formationId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final infos = ref.watch(examenInfosProvider(formationId));

    return infos.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (i) {
        if (i == null) return const SizedBox.shrink();

        IconData icone = Icons.assignment_outlined;
        String texte;
        Widget? action;

        if (i.reussi) {
          icone = Icons.emoji_events;
          texte =
              'Examen réussi. Meilleure note : ${i.meilleure ?? 0} %. '
              'Vous pouvez demander votre certificat.';
        } else if (!i.progressionOk) {
          icone = Icons.lock_outline;
          texte =
              'Terminez toutes les leçons pour débloquer l\'examen '
              '(${i.nbQuestions} questions, ${i.dureeMin} min, '
              'minimum ${i.noteMin} %).';
        } else if (i.enCours) {
          icone = Icons.timer_outlined;
          texte = 'Un examen est en cours : le temps continue de s\'écouler.';
          action = FilledButton(
            onPressed: () => _commencer(context, i),
            child: const Text('Reprendre l\'examen'),
          );
        } else if (i.bloque) {
          icone = Icons.hourglass_bottom;
          texte =
              'Tentatives épuisées (meilleure note : ${i.meilleure ?? 0} %, '
              'minimum ${i.noteMin} %). '
              'Vous pourrez retenter ${quandRetenter(i.prochaine!)}. '
              'Révisez les leçons en attendant.';
        } else {
          texte =
              '${i.nbQuestions} questions · ${i.dureeMin} min · '
              'minimum ${i.noteMin} % · '
              '${i.restantes > 0 ? '${i.restantes} tentative(s) restante(s)' : 'nouvelle série de tentatives disponible'}'
              '${i.meilleure == null ? '' : ' · meilleure note ${i.meilleure} %'}.';
          action = FilledButton(
            onPressed: () => _commencer(context, i),
            child: const Text('Passer l\'examen'),
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icone, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(i.titre, style: theme.textTheme.titleMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(texte),
                if (action != null) ...[const SizedBox(height: 12), action],
              ],
            ),
          ),
        );
      },
    );
  }
}