import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../../formateur/presentation/copies_page.dart' show dateHeure;
import '../domain/annonce.dart';
import 'annonces_providers.dart';

class AnnoncesPage extends ConsumerWidget {
  const AnnoncesPage({
    super.key,
    required this.formationId,
    required this.peutPublier,
  });

  final String formationId;
  final bool peutPublier;

  Future<void> _publier(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final saisie = await showDialog<({String titre, String corps})>(
      context: context,
      builder: (_) => const _NouvelleAnnonceDialog(),
    );
    if (saisie == null) return;
    try {
      final nb = await ref
          .read(annoncesRepositoryProvider)
          .publier(
            formationId: formationId,
            titre: saisie.titre,
            corps: saisie.corps,
          );
      ref.invalidate(annoncesProvider(formationId));
      messenger.showSnackBar(
        SnackBar(content: Text('Annonce envoyée à $nb inscrit(s).')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    }
  }

  Future<void> _supprimer(
    BuildContext context,
    WidgetRef ref,
    Annonce a,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: const Text(
          'Les notifications déjà envoyées ne sont pas retirées.',
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
      await ref.read(annoncesRepositoryProvider).supprimer(a.id);
      ref.invalidate(annoncesProvider(formationId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annonces = ref.watch(annoncesProvider(formationId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Annonces')),
      floatingActionButton: peutPublier
          ? FloatingActionButton.extended(
              onPressed: () => _publier(context, ref),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Nouvelle annonce'),
            )
          : null,
      body: AsyncBody<List<Annonce>>(
        value: annonces,
        onRetry: () => ref.invalidate(annoncesProvider(formationId)),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(annoncesProvider(formationId));
            await ref.read(annoncesProvider(formationId).future);
          },
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 160),
                    Center(child: Text('Aucune annonce pour le moment.')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final a = items[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    a.titre,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                if (peutPublier)
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        _supprimer(context, ref, a),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(a.corps),
                            const SizedBox(height: 8),
                            Text(
                              [
                                if (a.auteur != null) a.auteur!,
                                dateHeure(a.creeLe),
                              ].join(' · '),
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _NouvelleAnnonceDialog extends StatefulWidget {
  const _NouvelleAnnonceDialog();

  @override
  State<_NouvelleAnnonceDialog> createState() => _NouvelleAnnonceDialogState();
}

class _NouvelleAnnonceDialogState extends State<_NouvelleAnnonceDialog> {
  final _titre = TextEditingController();
  final _corps = TextEditingController();
  final _cle = GlobalKey<FormState>();

  @override
  void dispose() {
    _titre.dispose();
    _corps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle annonce'),
      content: Form(
        key: _cle,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titre,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
              ),
              TextFormField(
                controller: _corps,
                maxLength: 1000,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Message requis' : null,
              ),
              const SizedBox(height: 4),
              const Text(
                'Tous les inscrits recevront une notification.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (!_cle.currentState!.validate()) return;
            Navigator.pop(context, (
              titre: _titre.text.trim(),
              corps: _corps.text.trim(),
            ));
          },
          child: const Text('Publier'),
        ),
      ],
    );
  }
}
