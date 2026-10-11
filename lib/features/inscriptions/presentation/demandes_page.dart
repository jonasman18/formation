import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../../formateur/presentation/copies_page.dart' show dateHeure;
import '../domain/demande.dart';
import 'inscriptions_providers.dart';

class DemandesPage extends ConsumerStatefulWidget {
  const DemandesPage({super.key});

  @override
  ConsumerState<DemandesPage> createState() => _DemandesPageState();
}

class _DemandesPageState extends ConsumerState<DemandesPage> {
  String? _enCours; // id de la demande en cours de traitement

  Future<void> _traiter(Demande d, {required bool accepter}) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!accepter) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Refuser cette demande ?'),
          content: Text('${d.apprenant} sera informé(e) du refus.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Refuser'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final repo = ref.read(inscriptionsRepositoryProvider);
    setState(() => _enCours = d.id);
    try {
      await repo.traiter(d.id, accepter: accepter);
      ref.invalidate(demandesProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accepter ? '${d.apprenant} est inscrit(e) ✓' : 'Demande refusée',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demandes = ref.watch(demandesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Demandes d\'inscription')),
      body: AsyncBody<List<Demande>>(
        value: demandes,
        onRetry: () => ref.invalidate(demandesProvider),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Aucune demande en attente.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(demandesProvider);
              await ref.read(demandesProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final d = items[i];
                final occupe = _enCours == d.id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.apprenant, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(d.formation),
                        Text(
                          'Demandé le ${dateHeure(d.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        if ((d.message ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('« ${d.message} »'),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: occupe
                                    ? null
                                    : () => _traiter(d, accepter: false),
                                child: const Text('Refuser'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: occupe
                                    ? null
                                    : () => _traiter(d, accepter: true),
                                child: occupe
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Accepter'),
                              ),
                            ),
                          ],
                        ),
                      ],
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
