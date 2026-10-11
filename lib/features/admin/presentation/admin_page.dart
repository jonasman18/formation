import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../domain/admin_models.dart';
import 'admin_providers.dart';
import '../../../shared/widgets/learner_shell.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const MenuButton(),
          title: const Text('Administration'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Utilisateurs'),
              Tab(text: 'Catégories'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_UtilisateursTab(), _CategoriesTab()],
        ),
      ),
    );
  }
}

// ======================= Utilisateurs =======================

class _UtilisateursTab extends ConsumerStatefulWidget {
  const _UtilisateursTab();

  @override
  ConsumerState<_UtilisateursTab> createState() => _UtilisateursTabState();
}

class _UtilisateursTabState extends ConsumerState<_UtilisateursTab> {
  String _recherche = '';
  String? _filtreRole; // null = tous

  Future<void> _changerRole(Utilisateur u, String role) async {
    if (role == u.role) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le rôle ?'),
        content: Text(
          '${u.nomComplet.isEmpty ? u.email : u.nomComplet} '
          'deviendra « ${libelleRole(role)} ».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(adminRepositoryProvider);
    try {
      await repo.changerRole(u.id, role);
      ref.invalidate(utilisateursProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Rôle mis à jour : ${libelleRole(role)}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final monId = Supabase.instance.client.auth.currentUser?.id;
    final liste = ref.watch(utilisateursProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Rechercher',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) =>
                setState(() => _recherche = v.trim().toLowerCase()),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: const Text('Tous'),
                  selected: _filtreRole == null,
                  onSelected: (_) => setState(() => _filtreRole = null),
                ),
              ),
              for (final r in rolesDisponibles)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(libelleRole(r)),
                    selected: _filtreRole == r,
                    onSelected: (_) => setState(() => _filtreRole = r),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncBody<List<Utilisateur>>(
            value: liste,
            onRetry: () => ref.invalidate(utilisateursProvider),
            data: (tous) {
              final items = tous.where((u) {
                if (_filtreRole != null && u.role != _filtreRole) return false;
                if (_recherche.isEmpty) return true;
                return u.email.toLowerCase().contains(_recherche) ||
                    u.nomComplet.toLowerCase().contains(_recherche);
              }).toList();

              if (items.isEmpty) {
                return const Center(child: Text('Aucun utilisateur.'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(utilisateursProvider);
                  await ref.read(utilisateursProvider.future);
                },
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = items[i];
                    final moi = u.id == monId;
                    return ListTile(
                      leading: CircleAvatar(child: Text(u.initiales)),
                      title: Text(
                        u.nomComplet.isEmpty ? u.email : u.nomComplet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${u.email}${moi ? ' · vous' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: moi
                          // on ne peut pas se retirer soi-même le rôle admin
                          ? Chip(label: Text(libelleRole(u.role)))
                          : PopupMenuButton<String>(
                              tooltip: 'Changer le rôle',
                              onSelected: (r) => _changerRole(u, r),
                              itemBuilder: (_) => [
                                for (final r in rolesDisponibles)
                                  CheckedPopupMenuItem<String>(
                                    value: r,
                                    checked: r == u.role,
                                    child: Text(libelleRole(r)),
                                  ),
                              ],
                              child: Chip(
                                label: Text(libelleRole(u.role)),
                                avatar: const Icon(Icons.arrow_drop_down),
                              ),
                            ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ======================= Catégories =======================

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  Future<String?> _saisirNom(BuildContext context, {String? initial}) {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial == null ? 'Nouvelle catégorie' : 'Renommer'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final v = c.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(ctx, v);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _creer(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final nom = await _saisirNom(context);
    if (nom == null) return;
    try {
      await ref.read(adminRepositoryProvider).creerCategorie(nom);
      ref.invalidate(categoriesAdminProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    }
  }

  Future<void> _renommer(
    BuildContext context,
    WidgetRef ref,
    CategorieAdmin c,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final nom = await _saisirNom(context, initial: c.nom);
    if (nom == null || nom == c.nom) return;
    try {
      await ref.read(adminRepositoryProvider).renommerCategorie(c.id, nom);
      ref.invalidate(categoriesAdminProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    }
  }

  Future<void> _supprimer(
    BuildContext context,
    WidgetRef ref,
    CategorieAdmin c,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer « ${c.nom} » ?'),
        content: Text(
          c.nbFormations == 0
              ? 'Cette catégorie ne contient aucune formation.'
              : '${c.nbFormations} formation(s) seront conservées, '
                    'mais n\'auront plus de catégorie.',
        ),
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
    if (ok != true) return;
    try {
      await ref.read(adminRepositoryProvider).supprimerCategorie(c.id);
      ref.invalidate(categoriesAdminProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(categoriesAdminProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: () => _creer(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle catégorie'),
            ),
          ),
        ),
        Expanded(
          child: AsyncBody<List<CategorieAdmin>>(
            value: liste,
            onRetry: () => ref.invalidate(categoriesAdminProvider),
            data: (items) {
              if (items.isEmpty) {
                return const Center(child: Text('Aucune catégorie.'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = items[i];
                  return ListTile(
                    leading: const Icon(Icons.label_outline),
                    title: Text(c.nom),
                    subtitle: Text('${c.nbFormations} formation(s)'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Renommer',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _renommer(context, ref, c),
                        ),
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _supprimer(context, ref, c),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
