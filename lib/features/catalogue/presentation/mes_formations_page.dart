import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/async_body.dart';
import '../domain/formation.dart';
import 'catalogue_providers.dart';

class MesFormationsPage extends ConsumerWidget {
  const MesFormationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mes = ref.watch(mesFormationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes formations')),
      body: AsyncBody<List<MaFormation>>(
        value: mes,
        onRetry: () => ref.invalidate(mesFormationsProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mesFormationsProvider);
            await ref.read(mesFormationsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 160),
                    const Center(
                      child: Text('Vous n’êtes inscrit à aucune formation.'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: FilledButton.tonal(
                        onPressed: () => context.go('/catalogue'),
                        child: const Text('Explorer le catalogue'),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final m = items[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context
                            .go('/catalogue/formation/${m.formation.id}/cours'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.formation.titre,
                                  style: theme.textTheme.titleMedium),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                  value: m.pourcentage / 100),
                              const SizedBox(height: 4),
                              Text('${m.pourcentage} % terminé',
                                  style: theme.textTheme.labelMedium),
                            ],
                          ),
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