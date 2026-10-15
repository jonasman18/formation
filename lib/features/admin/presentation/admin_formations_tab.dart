import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../domain/admin_models.dart';
import '../domain/formation_admin.dart';
import 'admin_formations_providers.dart';
import 'admin_providers.dart';

/// Onglet « Formations » de l'administration : vue d'ensemble de toutes les
/// formations, avec leur responsable. L'administrateur supervise : il ouvre une
/// formation pour la modifier et peut changer le formateur responsable.
class FormationsAdminTab extends ConsumerWidget {
  const FormationsAdminTab({super.key});

  Future<void> _changerResponsable(
    BuildContext context,
    WidgetRef ref,
    FormationAdmin f,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final utilisateurs = await ref.read(utilisateursProvider.future);
    if (!context.mounted) return;

    final formateurs = utilisateurs
        .where((u) => u.role == 'formateur')
        .toList();
    if (formateurs.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun formateur : passez d’abord un utilisateur au rôle Formateur.',
          ),
        ),
      );
      return;
    }

    final choisi = await showDialog<Utilisateur>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Responsable de « ${f.titre} »'),
        children: [
          for (final u in formateurs)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, u),
              child: Row(
                children: [
                  Expanded(
                    child: Text(u.nomComplet.isEmpty ? u.email : u.nomComplet),
                  ),
                  if (u.id == f.formateurId) const Icon(Icons.check, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
    if (choisi == null || choisi.id == f.formateurId) return;

    try {
      await ref
          .read(adminFormationsRepositoryProvider)
          .changerResponsable(f.id, choisi.id);
      ref.invalidate(formationsAdminProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Nouveau responsable : '
            '${choisi.nomComplet.isEmpty ? choisi.email : choisi.nomComplet}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(formationsAdminProvider);

    return AsyncBody<List<FormationAdmin>>(
      value: liste,
      onRetry: () => ref.invalidate(formationsAdminProvider),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('Aucune formation.'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(formationsAdminProvider);
            await ref.read(formationsAdminProvider.future);
          },
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final f = items[i];
              return ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(
                  f.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Responsable : ${f.formateurNom.isEmpty ? '—' : f.formateurNom}'
                  '\n${f.libelleStatut} · ${f.nbInscrits} inscrit(s)',
                ),
                isThreeLine: true,
                onTap: () => context.push('/formateur/formation/${f.id}'),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Actions',
                  onSelected: (v) {
                    if (v == 'responsable') {
                      _changerResponsable(context, ref, f);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'responsable',
                      child: Text('Changer le responsable'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
