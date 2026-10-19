import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_body.dart';
import '../../cours/domain/cours.dart';
import '../../cours/presentation/cours_providers.dart';
import '../../cours/presentation/ouvrir_ressource.dart';

class AdminContenuPage extends ConsumerWidget {
  const AdminContenuPage({super.key, required this.formationId});

  final String formationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contenu de la formation')),
      body: AsyncBody<List<Module>>(
        value: ref.watch(modulesProvider(formationId)),
        onRetry: () => ref.invalidate(modulesProvider(formationId)),
        data: (modules) {
          if (modules.isEmpty) {
            return const Center(child: Text('Cette formation n\'a pas encore de module.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final m in modules)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    initiallyExpanded: modules.length == 1,
                    title: Text(m.titre),
                    children: [
                      if (m.lecons.isEmpty)
                        const ListTile(title: Text('Aucune leçon')),
                      for (final l in m.lecons) _LeconAdmin(lecon: l),
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

class _LeconAdmin extends StatelessWidget {
  const _LeconAdmin({required this.lecon});

  final Lecon lecon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nbVideos = lecon.ressources.where((r) => r.type == TypeLecon.video).length;
    final nbPdfs = lecon.ressources.length - nbVideos;

    return ExpansionTile(
      title: Text(lecon.titre),
      subtitle: Text('$nbVideos vidéo(s) · $nbPdfs PDF'),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        if (lecon.aTexte)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(lecon.contenu!, style: theme.textTheme.bodyMedium),
            ),
          ),
        for (final r in lecon.ressources)
          ListTile(
            dense: true,
            leading: Icon(
              r.type == TypeLecon.video
                  ? Icons.play_circle_outline
                  : Icons.picture_as_pdf_outlined,
            ),
            title: Text(r.nom, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              r.type == TypeLecon.video ? 'Vidéo' : 'PDF',
            ),
            onTap: () => ouvrirRessource(context, r),
          ),
        if (!lecon.aTexte && lecon.ressources.isEmpty)
          const ListTile(dense: true, title: Text('Aucun contenu.')),
      ],
    );
  }
}