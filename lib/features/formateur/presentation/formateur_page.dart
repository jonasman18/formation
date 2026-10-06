import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/async_body.dart';
import '../domain/formation_geree.dart';
import 'formateur_providers.dart';

class FormateurPage extends ConsumerWidget {
  const FormateurPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formations = ref.watch(formationsGereesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Espace formateur')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/formateur/formation/nouvelle'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle formation'),
      ),
      body: AsyncBody<List<FormationGeree>>(
        value: formations,
        onRetry: () => ref.invalidate(formationsGereesProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(formationsGereesProvider);
            await ref.read(formationsGereesProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Vous n\'avez pas encore de formation.')),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final f = items[i];
                    return Card(
                      child: ListTile(
                        title: Text(f.titre),
                        subtitle: Text(libelleStatut(f.statut)),
                        leading: Icon(
                          f.statut == 'publie'
                              ? Icons.public
                              : Icons.edit_note,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/formateur/formation/${f.id}'),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}