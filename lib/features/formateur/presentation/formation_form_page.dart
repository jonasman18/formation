import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/ui/ui.dart';
import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../../catalogue/presentation/catalogue_providers.dart';
import '../domain/formation_geree.dart';
import 'formateur_providers.dart';
import '../../inscriptions/presentation/acces_formation_switch.dart';

/// Création (formationId == null) ou modification d'une formation.
class FormationFormPage extends ConsumerWidget {
  const FormationFormPage({super.key, this.formationId});
  final String? formationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return FondDegrade(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(formationId == null ? 'Nouvelle formation' : 'Modifier'),
        ),
        body: AsyncBody<List<CategorieOption>>(
          value: categories,
          onRetry: () => ref.invalidate(categoriesProvider),
          data: (cats) {
            if (formationId == null) {
              return _FormationForm(categories: cats);
            }
            final formation = ref.watch(formationGereeProvider(formationId!));
            return AsyncBody<FormationGeree>(
              value: formation,
              onRetry: () =>
                  ref.invalidate(formationGereeProvider(formationId!)),
              data: (f) => _FormationForm(categories: cats, initial: f),
            );
          },
        ),
      ),
    );
  }
}

class _FormationForm extends ConsumerStatefulWidget {
  const _FormationForm({required this.categories, this.initial});
  final List<CategorieOption> categories;
  final FormationGeree? initial;

  @override
  ConsumerState<_FormationForm> createState() => _FormationFormState();
}

class _FormationFormState extends ConsumerState<_FormationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titre;
  late final TextEditingController _description;
  String? _categorieId;
  String _statut = 'brouillon';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _titre = TextEditingController(text: f?.titre ?? '');
    _description = TextEditingController(text: f?.description ?? '');
    _categorieId = f?.categorieId;
    _statut = f?.statut ?? 'brouillon';
  }

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    super.dispose();
  }

  void _rafraichir() {
    ref.invalidate(formationsGereesProvider);
    ref.invalidate(formationGereeProvider);
    ref.invalidate(formationsPublieesProvider);
    ref.invalidate(formationProvider);
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final repo = ref.read(formateurRepositoryProvider);
      final desc = _description.text.trim();
      final titre = _titre.text.trim();
      String? nouvelId;
      if (widget.initial == null) {
        nouvelId = await repo.creer(
          titre: titre,
          description: desc.isEmpty ? null : desc,
          categorieId: _categorieId,
          statut: _statut,
        );
      } else {
        await repo.modifier(
          widget.initial!.id,
          titre: titre,
          description: desc.isEmpty ? null : desc,
          categorieId: _categorieId,
          statut: _statut,
        );
      }
      _rafraichir();
      if (nouvelId != null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Formation créée. Ajoutez maintenant vos modules et leçons.',
            ),
          ),
        );
        router.go('/formateur/formation/$nouvelId');
      } else {
        router.go('/formateur');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette formation ?'),
        content: const Text(
          'Les modules, leçons, quiz, exercices et inscriptions associés '
          'seront aussi supprimés. Cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(formateurRepositoryProvider).supprimer(widget.initial!.id);
      _rafraichir();
      router.go('/formateur');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(humanError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final edition = widget.initial != null;
    final id = widget.initial?.id;

    return Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                 child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Esp.page,
                    vertical: Esp.l,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // ── Destinations (modification uniquement) ──
                    if (edition) ...[
                      Text(
                        'Gérer cette formation',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: Esp.s),
                      Row(
                        children: [
                          Expanded(
                            child: _Tuile(
                              icone: Icons.library_books_outlined,
                              label: 'Modules et leçons',
                              onTap: _busy
                                  ? null
                                  : () => context.push(
                                      '/formateur/formation/$id/contenu',
                                    ),
                            ),
                          ),
                          const SizedBox(width: Esp.m),
                          Expanded(
                            child: _Tuile(
                              icone: Icons.groups_outlined,
                              label: 'Apprenants',
                              onTap: _busy
                                  ? null
                                  : () => context.push(
                                      '/formateur/formation/$id/suivi',
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Esp.m),
                      Row(
                        children: [
                          Expanded(
                            child: _Tuile(
                              icone: Icons.campaign_outlined,
                              label: 'Annonces',
                              onTap: _busy
                                  ? null
                                  : () => context.push(
                                      '/formateur/formation/$id/annonces',
                                    ),
                            ),
                          ),
                          const SizedBox(width: Esp.m),
                          Expanded(
                            child: _Tuile(
                              icone: Icons.assignment_outlined,
                              label: 'Examen final',
                              onTap: _busy
                                  ? null
                                  : () => context.push(
                                      '/formateur/formation/$id/examen',
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Esp.xl),
                    ],

                    // ── Informations ──
                    CarteSection(
                      titre: 'Informations',
                      icone: Icons.edit_note_outlined,
                      enfants: [
                        TextFormField(
                          controller: _titre,
                          decoration: const InputDecoration(labelText: 'Titre'),
                          textCapitalization: TextCapitalization.sentences,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Le titre est obligatoire'
                              : null,
                        ),
                        const SizedBox(height: Esp.l),
                        TextFormField(
                          controller: _description,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            alignLabelWithHint: true,
                          ),
                          minLines: 1,
                          maxLines: 8,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                        const SizedBox(height: Esp.l),
                        SizedBox(
                          width: double.infinity,
                          child: DropdownMenu<String?>(
                            expandedInsets: EdgeInsets.zero,
                            label: const Text('Catégorie'),
                            initialSelection: _categorieId,
                            onSelected: (v) => _categorieId = v,
                            dropdownMenuEntries: [
                              const DropdownMenuEntry<String?>(
                                value: null,
                                label: 'Aucune',
                              ),
                              for (final c in widget.categories)
                                DropdownMenuEntry<String?>(
                                  value: c.id,
                                  label: c.nom,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── Publication ──
                    CarteSection(
                      titre: 'Publication',
                      icone: Icons.public,
                      enfants: [
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'brouillon',
                                label: Text('Brouillon'),
                              ),
                              ButtonSegment(
                                value: 'publie',
                                label: Text('Publiée'),
                              ),
                              ButtonSegment(
                                value: 'archive',
                                label: Text('Archivée'),
                              ),
                            ],
                            selected: {_statut},
                            onSelectionChanged: (s) =>
                                setState(() => _statut = s.first),
                          ),
                        ),
                        const SizedBox(height: Esp.s),
                        Text(
                          'Seules les formations « Publiée » apparaissent dans le catalogue.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        if (edition) ...[
                          const SizedBox(height: Esp.m),
                          AccesFormationSwitch(formationId: id!),
                        ],
                      ],
                    ),

                    if (!edition)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        child: Text(
                          'Après l\'enregistrement, vous pourrez ajouter des modules et des leçons.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),

                    // ── Zone dangereuse (à part, tout en bas) ──
                    if (edition) ...[
                      const SizedBox(height: Esp.xl),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _supprimer,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(
                            color: cs.error.withValues(alpha: 0.5),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Supprimer la formation'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Barre fixe : Enregistrer toujours visible ──
        _BarreEnregistrer(
          label: edition ? 'Enregistrer' : 'Créer la formation',
          chargement: _busy,
          onPressed: _enregistrer,
        ),
      ],
    );
  }
}

/// Tuile de navigation : icône + libellé.
class _Tuile extends StatelessWidget {
  const _Tuile({required this.icone, required this.label, this.onTap});

  final IconData icone;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Esp.s),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 26, color: theme.colorScheme.primary),
                const SizedBox(height: Esp.s),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre du bas, fixe : bouton principal du formulaire.
class _BarreEnregistrer extends StatelessWidget {
  const _BarreEnregistrer({
    required this.label,
    required this.chargement,
    required this.onPressed,
  });

  final String label;
  final bool chargement;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Esp.m),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SizedBox(
                width: double.infinity,
                child: BoutonChargement(
                  label: label,
                  icone: Icons.save_outlined,
                  labelChargement: 'Enregistrement…',
                  chargement: chargement,
                  onPressed: onPressed,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}