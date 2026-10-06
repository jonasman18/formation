import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/async_body.dart';

import '../domain/formation.dart';
import 'catalogue_providers.dart';

class CataloguePage extends ConsumerWidget {
  const CataloguePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formations = ref.watch(formationsPublieesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue'),
        
      ),
      body: AsyncBody<List<Formation>>(
        value: formations,
        onRetry: () => ref.invalidate(formationsPublieesProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(formationsPublieesProvider);
            await ref.read(formationsPublieesProvider.future);
          },
          child: items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 160),
                  Center(
                      child: Text('Aucune formation disponible pour le moment.')),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final f = items[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.go('/catalogue/formation/${f.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (f.categorie != null) ...[
                                Chip(
                                  label: Text(f.categorie!),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text(f.titre, style: theme.textTheme.titleMedium),
                              if (f.description != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  f.description!,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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