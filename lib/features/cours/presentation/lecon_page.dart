import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../domain/cours.dart';
import 'cours_providers.dart';
import 'lecon_media.dart';

class LeconPage extends ConsumerStatefulWidget {
  const LeconPage({
    super.key,
    required this.formationId,
    required this.leconId,
  });

  final String formationId;
  final String leconId;

  @override
  ConsumerState<LeconPage> createState() => _LeconPageState();
}

class _LeconPageState extends ConsumerState<LeconPage> {
  bool _busy = false;

  Lecon? _trouver(List<Module> modules) {
    for (final m in modules) {
      for (final l in m.lecons) {
        if (l.id == widget.leconId) return l;
      }
    }
    return null;
  }

  Future<void> _terminer() async {
    setState(() => _busy = true);
    try {
      await ref.read(coursRepositoryProvider).marquerTerminee(widget.leconId);
      ref.invalidate(leconsTermineesProvider);
      await ref.read(leconsTermineesProvider.future);
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
    final modules = ref.watch(modulesProvider(widget.formationId));
    final terminees = ref.watch(leconsTermineesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Leçon')),
      body: AsyncBody<List<Module>>(
        value: modules,
        onRetry: () => ref.invalidate(modulesProvider(widget.formationId)),
        data: (items) {
          final lecon = _trouver(items);
          if (lecon == null) {
            return const Center(child: Text('Leçon introuvable.'));
          }
          final terminee = terminees.asData?.value.contains(lecon.id) ?? false;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(lecon.titre, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              if (lecon.type == TypeLecon.texte)
                Text(
                  lecon.contenu ?? 'Aucun contenu.',
                  style: theme.textTheme.bodyLarge,
                )
                else if (lecon.type == TypeLecon.video)
                VideoLecon(key: ValueKey(lecon.id), chemin: lecon.url)
              else
                PdfLecon(chemin: lecon.url),
              const SizedBox(height: 32),
              if (terminee)
                const FilledButton.tonal(
                  onPressed: null,
                  child: Text('Leçon terminée ✓'),
                )
              else
                FilledButton.icon(
                  onPressed: _busy ? null : _terminer,
                  icon: const Icon(Icons.check),
                  label: const Text('Marquer comme terminée'),
                ),
            ],
          );
        },
      ),
    );
  }
}