import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/async_body.dart';
import '../domain/copie.dart';
import 'formateur_providers.dart';

String dateHeure(DateTime d) {
  String d2(int n) => n.toString().padLeft(2, '0');
  return '${d2(d.day)}/${d2(d.month)}/${d.year} ${d2(d.hour)}:${d2(d.minute)}';
}

class CopiesPage extends ConsumerStatefulWidget {
  const CopiesPage({super.key});

  @override
  ConsumerState<CopiesPage> createState() => _CopiesPageState();
}

class _CopiesPageState extends ConsumerState<CopiesPage> {
  bool _corrigees = false;

  @override
  Widget build(BuildContext context) {
    final copies = ref.watch(copiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Copies des apprenants')),
      body: AsyncBody<List<Copie>>(
        value: copies,
        onRetry: () => ref.invalidate(copiesProvider),
        data: (items) {
          final aCorriger = items.where((c) => !c.corrigee).toList();
          final corrigees = items.where((c) => c.corrigee).toList();
          final liste = _corrigees ? corrigees : aCorriger;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text('À corriger (${aCorriger.length})'),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Corrigées (${corrigees.length})'),
                    ),
                  ],
                  selected: {_corrigees},
                  onSelectionChanged: (s) =>
                      setState(() => _corrigees = s.first),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(copiesProvider);
                    await ref.read(copiesProvider.future);
                  },
                  child: liste.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                _corrigees
                                    ? 'Aucune copie corrigée.'
                                    : 'Aucune copie à corriger. 🎉',
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: liste.length,
                          itemBuilder: (context, i) {
                            final c = liste[i];
                            return Card(
                              child: ListTile(
                                isThreeLine: true,
                                title: Text(c.apprenant),
                                subtitle: Text(
                                  '${c.exercice}\n${c.formation} · ${dateHeure(c.soumisAt)}',
                                ),
                                trailing: c.corrigee
                                    ? Text(c.noteTexte ?? '')
                                    : const Icon(Icons.chevron_right),
                                onTap: () =>
                                    context.go('/formateur/copies/${c.id}'),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
