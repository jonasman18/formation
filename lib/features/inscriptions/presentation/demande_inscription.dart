import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/errors.dart';
import 'inscriptions_providers.dart';

class DemandeInscription extends ConsumerStatefulWidget {
  const DemandeInscription({super.key, required this.formationId});
  final String formationId;

  @override
  ConsumerState<DemandeInscription> createState() => _DemandeInscriptionState();
}

class _DemandeInscriptionState extends ConsumerState<DemandeInscription> {
  bool _busy = false;

  Future<String?> _saisirMessage() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demande d\'inscription'),
        content: TextField(
          controller: c,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Message au formateur (facultatif)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  Future<void> _demander() async {
    final messenger = ScaffoldMessenger.of(context);
    final message = await _saisirMessage();
    if (message == null || !mounted) return; // annulé

    final repo = ref.read(inscriptionsRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repo.demander(widget.formationId, message: message);
      ref.invalidate(maDemandeProvider(widget.formationId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Demande envoyée ✓')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _annuler() async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(inscriptionsRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repo.annuler(widget.formationId);
      ref.invalidate(maDemandeProvider(widget.formationId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statut = ref.watch(maDemandeProvider(widget.formationId));

    return statut.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(humanError(e)),
      data: (s) {
        if (s == 'en_attente') {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.hourglass_top),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Demande envoyée. En attente de validation par le formateur.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : _annuler,
                    child: const Text('Annuler ma demande'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s == 'refusee') ...[
                  Text(
                    'Votre précédente demande n\'a pas été acceptée.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else
                  const Text(
                    'Cette formation est accessible sur validation du formateur.',
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _demander,
                  icon: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.how_to_reg),
                  label: Text(
                    s == 'refusee'
                        ? 'Refaire une demande'
                        : 'Demander l\'inscription',
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
