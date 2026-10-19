import 'package:flutter/material.dart';

import '../domain/cours.dart';
import 'lecon_media.dart';

/// Ouvre une vidéo ou un PDF dans un panneau (même lecteur que côté apprenant).
void ouvrirRessource(BuildContext context, Ressource r) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.nom, style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (r.type == TypeLecon.video)
              VideoLecon(key: ValueKey(r.id), chemin: r.url)
            else
              PdfLecon(chemin: r.url, nom: r.nom),
          ],
        ),
      ),
    ),
  );
}