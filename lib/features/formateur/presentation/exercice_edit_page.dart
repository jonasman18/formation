import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/utils/pick_file.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/fichier_tile.dart';
import '../../cours/presentation/cours_providers.dart';
import '../../exercices/data/exercice_fichiers.dart';
import '../../exercices/domain/exercice.dart';
import '../../exercices/presentation/exercices_providers.dart';
import 'formateur_providers.dart';

/// Création (exerciceId == null) ou modification d'un exercice.
class ExerciceEditPage extends ConsumerWidget {
  const ExerciceEditPage({
    super.key,
    required this.formationId,
    required this.moduleId,
    this.exerciceId,
  });

  final String formationId;
  final String moduleId;
  final String? exerciceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          exerciceId == null ? 'Nouvel exercice' : 'Modifier l\'exercice',
        ),
      ),
      body: exerciceId == null
          ? _ExerciceForm(formationId: formationId, moduleId: moduleId)
          : AsyncBody<Exercice>(
              value: ref.watch(exerciceProvider(exerciceId!)),
              onRetry: () => ref.invalidate(exerciceProvider(exerciceId!)),
              data: (e) => _ExerciceForm(
                key: ValueKey(e.id),
                formationId: formationId,
                moduleId: moduleId,
                initial: e,
              ),
            ),
    );
  }
}

class _ExerciceForm extends ConsumerStatefulWidget {
  const _ExerciceForm({
    super.key,
    required this.formationId,
    required this.moduleId,
    this.initial,
  });

  final String formationId;
  final String moduleId;
  final Exercice? initial;

  @override
  ConsumerState<_ExerciceForm> createState() => _ExerciceFormState();
}

class _ExerciceFormState extends ConsumerState<_ExerciceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titre;
  late final TextEditingController _consigne;
  DateTime? _limite;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _titre = TextEditingController(text: e?.titre ?? '');
    _consigne = TextEditingController(text: e?.consigne ?? '');
    _limite = e?.dateLimite;
  }

  @override
  void dispose() {
    _titre.dispose();
    _consigne.dispose();
    super.dispose();
  }

  String get _retour => '/formateur/formation/${widget.formationId}/contenu';

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _msg(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _choisirDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _limite ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    // fin de journée (23 h 59), heure locale
    setState(() => _limite = DateTime(d.year, d.month, d.day, 23, 59));
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final router = GoRouter.of(context);
    final repo = ref.read(formateurRepositoryProvider);
    final consigne = _consigne.text.trim();

    setState(() => _busy = true);
    try {
      if (widget.initial == null) {
        final id = await repo.creerExercice(
          moduleId: widget.moduleId,
          titre: _titre.text.trim(),
          consigne: consigne.isEmpty ? null : consigne,
          dateLimite: _limite,
        );
        ref.invalidate(modulesProvider(widget.formationId));
        ref.invalidate(exerciceProvider);
        _msg('Exercice créé. Vous pouvez maintenant joindre des PDF.');
        // on reste sur l'exercice pour pouvoir y ajouter des documents
        router.go('$_retour/module/${widget.moduleId}/exercice/$id');
        return;
      }
      await repo.modifierExercice(
        widget.initial!.id,
        titre: _titre.text.trim(),
        consigne: consigne.isEmpty ? null : consigne,
        dateLimite: _limite,
      );
      ref.invalidate(modulesProvider(widget.formationId));
      ref.invalidate(exerciceProvider);
      router.go(_retour);
    } catch (e) {
      _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ajouterPdf() async {
    final f = await choisirFichier(extensions: ['pdf']);
    if (f == null || !mounted) return;
    if (f.octets.length > tailleMaxOctets) {
      _msg('Fichier trop volumineux (20 Mo maximum).');
      return;
    }
    final id = widget.initial!.id;
    final repo = ref.read(exerciceFichiersRepositoryProvider);

    setState(() => _busy = true);
    try {
      await repo.ajouterConsigne(
        formationId: widget.formationId,
        exerciceId: id,
        nom: f.nom,
        octets: f.octets,
      );
      ref.invalidate(consignesProvider(id));
    } catch (e) {
      _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retirerPdf(FichierJoint f) async {
    final repo = ref.read(exerciceFichiersRepositoryProvider);
    final id = widget.initial!.id;
    setState(() => _busy = true);
    try {
      await repo.supprimerConsigne(f);
      ref.invalidate(consignesProvider(id));
    } catch (e) {
      _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet exercice ?'),
        content: const Text(
          'Les copies déjà déposées par les apprenants seront supprimées.',
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
    final repo = ref.read(formateurRepositoryProvider);
    final fichiersRepo = ref.read(exerciceFichiersRepositoryProvider);
    final id = widget.initial!.id;
    final joints = ref.read(consignesProvider(id)).asData?.value ?? const [];

    setState(() => _busy = true);
    try {
      await repo.supprimerExercice(id);
      for (final f in joints) {
        await fichiersRepo.supprimerFichierStockage(
          ExerciceFichiersRepository.bucketConsignes,
          f.chemin,
        );
      }
      ref.invalidate(modulesProvider(widget.formationId));
      ref.invalidate(exerciceProvider);
      router.go(_retour);
    } catch (e) {
      _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _documents() {
    final theme = Theme.of(context);
    final id = widget.initial!.id;
    final liste =
        ref.watch(consignesProvider(id)).asData?.value ??
        const <FichierJoint>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Documents joints (PDF)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (liste.isEmpty)
          Text('Aucun document.', style: theme.textTheme.bodySmall),
        for (final f in liste)
          Card(
            child: FichierTile(
              bucket: ExerciceFichiersRepository.bucketConsignes,
              chemin: f.chemin,
              nom: f.titre,
              trailing: IconButton(
                tooltip: 'Retirer',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy ? null : () => _retirerPdf(f),
              ),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _busy ? null : _ajouterPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Ajouter un PDF'),
        ),
      ],
    );
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
              labelText: 'Titre de l\'exercice',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Le titre est obligatoire'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _consigne,
            decoration: const InputDecoration(
              labelText: 'Consigne',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 5,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Text('Date limite (facultative)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _choisirDate,
                icon: const Icon(Icons.event),
                label: Text(
                  _limite == null ? 'Choisir une date' : _date(_limite!),
                ),
              ),
              if (_limite != null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _limite = null),
                  child: const Text('Retirer'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.initial != null)
            _documents()
          else
            Text(
              'Vous pourrez joindre des PDF juste après la création.',
              style: theme.textTheme.bodySmall,
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
                    widget.initial == null
                        ? 'Créer l\'exercice'
                        : 'Enregistrer',
                  ),
          ),
          if (widget.initial != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _supprimer,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              label: Text(
                'Supprimer l\'exercice',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
