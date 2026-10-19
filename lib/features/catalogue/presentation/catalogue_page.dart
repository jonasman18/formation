import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/async_body.dart';

import '../domain/formation.dart';
import 'catalogue_providers.dart';
import '../../../shared/widgets/learner_shell.dart';

/// Minuscules + sans accents, pour une recherche tolérante.
String _norm(String s) {
  const avec = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿœ';
  const sans = 'aaaaaceeeeiiiinooooouuuuyyo';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = avec.indexOf(c);
    b.write(i >= 0 ? sans[i] : c);
  }
  return b.toString();
}

class CataloguePage extends ConsumerStatefulWidget {
  const CataloguePage({super.key});

  @override
  ConsumerState<CataloguePage> createState() => _CataloguePageState();
}

class _CataloguePageState extends ConsumerState<CataloguePage> {
  final _recherche = TextEditingController();
  String _requete = '';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  List<Formation> _filtrer(List<Formation> items) {
    final q = _norm(_requete.trim());
    if (q.isEmpty) return items;
    return items.where((f) {
      final texte = _norm(
        '${f.titre} ${f.description ?? ''} ${f.categorie ?? ''}',
      );
      return texte.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final formations = ref.watch(formationsPublieesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Catalogue'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _recherche,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher une formation…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _requete.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _recherche.clear();
                          setState(() => _requete = '');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _requete = v),
            ),
          ),
          Expanded(
            child: AsyncBody<List<Formation>>(
              value: formations,
              onRetry: () => ref.invalidate(formationsPublieesProvider),
              data: (tous) {
                final items = _filtrer(tous);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(formationsPublieesProvider);
                    await ref.read(formationsPublieesProvider.future);
                  },
                  child: items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                tous.isEmpty
                                    ? 'Aucune formation disponible pour le moment.'
                                    : 'Aucun résultat pour « ${_requete.trim()} ».',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final f = items[i];
                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () =>
                                    context.go('/catalogue/formation/${f.id}'),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (f.categorie != null) ...[
                                        Chip(
                                          label: Text(f.categorie!),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      Text(
                                        f.titre,
                                        style: theme.textTheme.titleMedium,
                                      ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}