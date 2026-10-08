import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../../exercices/presentation/exercices_providers.dart';
import '../domain/copie.dart';
import 'copies_page.dart' show dateHeure;
import 'formateur_providers.dart';

class CorrectionPage extends ConsumerWidget {
  const CorrectionPage({super.key, required this.soumissionId});
  final String soumissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copies = ref.watch(copiesProvider);
    final items = copies.hasValue ? copies.value : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Correction')),
      body: items == null
          ? AsyncBody<List<Copie>>(
              value: copies,
              onRetry: () => ref.invalidate(copiesProvider),
              data: (_) => const SizedBox.shrink(),
            )
          : _corps(items, copies.isLoading),
    );
  }

  Widget _corps(List<Copie> items, bool enChargement) {
    final copie = items.where((c) => c.id == soumissionId).firstOrNull;
    if (copie == null) {
      return enChargement
          ? const Center(child: CircularProgressIndicator())
          : const Center(child: Text('Copie introuvable.'));
    }
    return _CorrectionForm(key: ValueKey(copie.id), copie: copie);
  }
}

class _CorrectionForm extends ConsumerStatefulWidget {
  const _CorrectionForm({super.key, required this.copie});
  final Copie copie;

  @override
  ConsumerState<_CorrectionForm> createState() => _CorrectionFormState();
}

class _CorrectionFormState extends ConsumerState<_CorrectionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _note;
  late final TextEditingController _commentaire;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final c = widget.copie;
    _note = TextEditingController(
      text: c.note == null
          ? ''
          : c.note!.toStringAsFixed(c.note! % 1 == 0 ? 0 : 2),
    );
    _commentaire = TextEditingController(text: c.commentaire ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    _commentaire.dispose();
    super.dispose();
  }

  double? _lireNote(String? v) =>
      double.tryParse((v ?? '').trim().replaceAll(',', '.'));

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(formateurRepositoryProvider);
    final com = _commentaire.text.trim();

    setState(() => _busy = true);
    try {
      await repo.corriger(
        widget.copie.id,
        note: _lireNote(_note.text)!,
        commentaire: com.isEmpty ? null : com,
      );
      ref.invalidate(copiesProvider);
      ref.invalidate(maSoumissionProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Correction enregistrée ✓')),
      );
      router.go('/formateur/copies');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.copie;
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(c.apprenant, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(c.exercice, style: theme.textTheme.titleMedium),
          Text(
            '${c.formation}${c.module.isEmpty ? '' : ' · ${c.module}'}\n'
            'Rendu le ${dateHeure(c.soumisAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if ((c.consigne ?? '').isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Consigne'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(c.consigne!),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text('Réponse de l\'apprenant', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(
                  (c.contenu ?? '').isEmpty ? '(réponse vide)' : c.contenu!,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _note,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Note sur 20',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final n = _lireNote(v);
              if (n == null) return 'Saisissez une note (ex. 14 ou 14,5)';
              if (n < 0 || n > 20) {
                return 'La note doit être comprise entre 0 et 20';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _commentaire,
            decoration: const InputDecoration(
              labelText: 'Commentaire (facultatif)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _enregistrer,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    c.corrigee
                        ? 'Mettre à jour la correction'
                        : 'Enregistrer la correction',
                  ),
          ),
        ],
      ),
    );
  }
}
