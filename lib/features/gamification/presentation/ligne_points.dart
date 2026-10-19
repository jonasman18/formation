import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gamification_service.dart';

/// Petite ligne « Niveau · points » pour l'en-tête du menu (apprenants).
class LignePoints extends ConsumerWidget {
  const LignePoints({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(mesPointsProvider).asData?.value;
    if (p == null || !p.apprenant) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '${p.niveau.nom} · ${p.points} pts',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}