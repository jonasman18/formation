import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../domain/formation.dart';
import 'catalogue_providers.dart';
import 'package:go_router/go_router.dart';

class FormationDetailPage extends ConsumerStatefulWidget {
  const FormationDetailPage({super.key, required this.formationId});
  final String formationId;

  @override
  ConsumerState<FormationDetailPage> createState() =>
      _FormationDetailPageState();
}

class _FormationDetailPageState extends ConsumerState<FormationDetailPage> {
  bool _busy = false;

  Future<void> _sInscrire() async {
    setState(() => _busy = true);
    try {
      await ref.read(catalogueRepositoryProvider).sInscrire(widget.formationId);
      ref.invalidate(inscritProvider(widget.formationId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(humanError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.formationId;
    final formation = ref.watch(formationProvider(id));
    final inscrit = ref.watch(inscritProvider(id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Formation')),
      body: AsyncBody<Formation>(
        value: formation,
        onRetry: () => ref.invalidate(formationProvider(id)),
        data: (f) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(f.titre, style: theme.textTheme.headlineSmall),
            if (f.categorie != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(f.categorie!),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(f.description ?? 'Aucune description.'),
            const SizedBox(height: 24),
            inscrit.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(humanError(e)),
                data: (dejaInscrit) => dejaInscrit
                  ? FilledButton.icon(
                      onPressed: () => context.go('/catalogue/formation/$id/cours'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Accéder au cours'),
                    )
                  : FilledButton(
                      onPressed: _busy ? null : _sInscrire,
                      child: const Text('S’inscrire à cette formation'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}