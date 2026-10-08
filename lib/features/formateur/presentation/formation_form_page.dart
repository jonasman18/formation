import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../../catalogue/presentation/catalogue_providers.dart';
import '../domain/formation_geree.dart';
import 'formateur_providers.dart';

/// Création (formationId == null) ou modification d'une formation.
class FormationFormPage extends ConsumerWidget {
  const FormationFormPage({super.key, this.formationId});
  final String? formationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
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
            onRetry: () => ref.invalidate(formationGereeProvider(formationId!)),
            data: (f) => _FormationForm(categories: cats, initial: f),
          );
        },
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(humanError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titre,
            decoration: const InputDecoration(
              labelText: 'Titre',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Le titre est obligatoire'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          DropdownMenu<String?>(
            expandedInsets: EdgeInsets.zero,
            label: const Text('Catégorie'),
            initialSelection: _categorieId,
            onSelected: (v) => _categorieId = v,
            dropdownMenuEntries: [
              const DropdownMenuEntry<String?>(value: null, label: 'Aucune'),
              for (final c in widget.categories)
                DropdownMenuEntry<String?>(value: c.id, label: c.nom),
            ],
          ),
          const SizedBox(height: 24),
          Text('Statut', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'brouillon', label: Text('Brouillon')),
              ButtonSegment(value: 'publie', label: Text('Publiée')),
              ButtonSegment(value: 'archive', label: Text('Archivée')),
            ],
            selected: {_statut},
            onSelectionChanged: (s) => setState(() => _statut = s.first),
          ),
          const SizedBox(height: 4),
          Text(
            'Seules les formations « Publiée » apparaissent dans le catalogue.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          if (widget.initial == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Après l\'enregistrement, vous pourrez ajouter des modules et des leçons.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : _enregistrer,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer'),
          ),
          if (widget.initial != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => context.go(
                      '/formateur/formation/${widget.initial!.id}/contenu',
                    ),
              icon: const Icon(Icons.library_books_outlined),
              label: const Text('Gérer les modules et leçons'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _supprimer,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              label: Text(
                'Supprimer la formation',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
