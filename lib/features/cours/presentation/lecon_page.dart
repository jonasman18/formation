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
              if (lecon.aTexte)
                Text(lecon.contenu!, style: theme.textTheme.bodyLarge),
              for (final v in lecon.videos) ...[
                const SizedBox(height: 20),
                Text(v.nom, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                VideoLecon(key: ValueKey(v.id), chemin: v.url),
              ],
              if (lecon.pdfs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Documents', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final p in lecon.pdfs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PdfLecon(chemin: p.url, nom: p.nom),
                  ),
              ],
              if (!lecon.aTexte && lecon.ressources.isEmpty)
                const Text('Aucun contenu pour le moment.'),
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
