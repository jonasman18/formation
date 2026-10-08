import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../../cours/domain/cours.dart';
import '../../cours/presentation/cours_providers.dart';
import 'formateur_providers.dart';

const _tailleMaxOctets = 50 * 1024 * 1024; // limite du plan gratuit Supabase

/// Création (leconId == null) ou modification d'une leçon.
class LeconFormPage extends ConsumerWidget {
  const LeconFormPage({
    super.key,
    required this.formationId,
    required this.moduleId,
    this.leconId,
  });

  final String formationId;
  final String moduleId;
  final String? leconId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(modulesProvider(formationId));
    // On garde l'ancienne valeur pendant un rechargement (le formulaire n'est pas détruit).
    final items = modules.hasValue ? modules.value : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(leconId == null ? 'Nouvelle leçon' : 'Modifier la leçon'),
      ),
      body: items == null
          ? AsyncBody<List<Module>>(
              value: modules,
              onRetry: () => ref.invalidate(modulesProvider(formationId)),
              data: (_) => const SizedBox.shrink(),
            )
          : _corps(items, modules.isLoading),
    );
  }

  Widget _corps(List<Module> items, bool enChargement) {
    final module = items.where((m) => m.id == moduleId).firstOrNull;
    if (module == null) {
      return const Center(child: Text('Module introuvable.'));
    }
    Lecon? lecon;
    if (leconId != null) {
      lecon = module.lecons.where((l) => l.id == leconId).firstOrNull;
      if (lecon == null) {
        return enChargement
            ? const Center(child: CircularProgressIndicator())
            : const Center(child: Text('Leçon introuvable.'));
      }
    }
    final ordre =
        lecon?.ordre ??
        module.lecons.fold<int>(0, (a, l) => l.ordre > a ? l.ordre : a) + 1;
    return _LeconForm(
      key: ValueKey(leconId ?? 'nouvelle'),
      formationId: formationId,
      moduleId: moduleId,
      ordre: ordre,
      initial: lecon,
    );
  }
}

class _LeconForm extends ConsumerStatefulWidget {
  const _LeconForm({
    super.key,
    required this.formationId,
    required this.moduleId,
    required this.ordre,
    this.initial,
  });

  final String formationId;
  final String moduleId;
  final int ordre;
  final Lecon? initial;

  @override
  ConsumerState<_LeconForm> createState() => _LeconFormState();
}

class _LeconFormState extends ConsumerState<_LeconForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titre;
  late final TextEditingController _contenu;
  bool _busy = false; // enregistrement / suppression
  String? _envoiEnCours; // nom du fichier en cours d'envoi

  @override
  void initState() {
    super.initState();
    _titre = TextEditingController(text: widget.initial?.titre ?? '');
    _contenu = TextEditingController(text: widget.initial?.contenu ?? '');
  }

  @override
  void dispose() {
    _titre.dispose();
    _contenu.dispose();
    super.dispose();
  }

  String get _retour => '/formateur/formation/${widget.formationId}/contenu';

  void _msg(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  String _sansExtension(String nom) {
    final i = nom.lastIndexOf('.');
    return i > 0 ? nom.substring(0, i) : nom;
  }

  Future<bool> _confirmer(String titre, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: Text(message),
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
    return ok == true && mounted;
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(formateurRepositoryProvider);
    final texte = _contenu.text.trim();
    final contenu = texte.isEmpty ? null : texte;

    setState(() => _busy = true);
    try {
      if (widget.initial == null) {
        final id = await repo.creerLecon(
          moduleId: widget.moduleId,
          titre: _titre.text.trim(),
          contenu: contenu,
          ordre: widget.ordre,
        );
        ref.invalidate(modulesProvider(widget.formationId));
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Leçon créée. Vous pouvez maintenant y ajouter des fichiers (PDF, vidéos).',
            ),
          ),
        );
        router.go('$_retour/module/${widget.moduleId}/lecon/$id');
      } else {
        await repo.modifierLecon(
          widget.initial!.id,
          titre: _titre.text.trim(),
          contenu: contenu,
        );
        ref.invalidate(modulesProvider(widget.formationId));
        router.go(_retour);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ajouter(TypeLecon type) async {
    final lecon = widget.initial!;
    final pdf = type == TypeLecon.pdf;
    final fichiers = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: pdf ? ['pdf'] : ['mp4', 'mov', 'webm', 'mkv'],
    );
    if (fichiers.isEmpty || !mounted) return;

    final repo = ref.read(formateurRepositoryProvider);
    var ordre = lecon.ressources.fold<int>(
      0,
      (a, r) => r.ordre > a ? r.ordre : a,
    );
    var ajoutes = 0;
    try {
      for (final f in fichiers) {
        final taille = await f.length();
        if (taille != null && taille > _tailleMaxOctets) {
          _msg('« ${f.name} » dépasse 50 Mo : ignoré.');
          continue;
        }
        ordre++;
        if (mounted) setState(() => _envoiEnCours = f.name);
        final octets = await f.readAsBytes();
        await repo.ajouterRessource(
          formationId: widget.formationId,
          leconId: lecon.id,
          type: type.name,
          fichier: octets,
          nom: f.name,
          titre: _sansExtension(f.name),
          ordre: ordre,
        );
        ajoutes++;
      }
      if (ajoutes > 0) _msg('$ajoutes fichier(s) ajouté(s) ✓');
    } catch (e) {
      _msg(humanError(e));
    } finally {
      if (mounted) {
        setState(() => _envoiEnCours = null);
        ref.invalidate(modulesProvider(widget.formationId));
      }
    }
  }

  Future<void> _retirer(Ressource r) async {
    final ok = await _confirmer('Retirer ce fichier ?', r.nom);
    if (!ok) return;
    try {
      await ref
          .read(formateurRepositoryProvider)
          .supprimerRessource(r.id, r.url);
      if (mounted) ref.invalidate(modulesProvider(widget.formationId));
    } catch (e) {
      _msg(humanError(e));
    }
  }

  Future<void> _supprimerLecon() async {
    final ok = await _confirmer(
      'Supprimer cette leçon ?',
      'Ses fichiers et la progression des apprenants seront aussi supprimés.',
    );
    if (!ok) return;
    if (!mounted) return; // corrige use_build_context_synchronously

    final router = GoRouter.of(context);
    final repo = ref.read(formateurRepositoryProvider);
    final fichiers = widget.initial!.ressources.map((r) => r.url).toList();
    setState(() => _busy = true);
    try {
      await repo.supprimerLecon(widget.initial!.id);
      for (final chemin in fichiers) {
        if (chemin.startsWith('http')) continue;
        try {
          await repo.supprimerFichier(chemin);
        } catch (_) {}
      }
      ref.invalidate(modulesProvider(widget.formationId));
      router.go(_retour);
    } catch (e) {
      _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lecon = widget.initial;
    final occupe = _busy || _envoiEnCours != null;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titre,
            decoration: const InputDecoration(
              labelText: 'Titre de la leçon',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Le titre est obligatoire'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contenu,
            decoration: const InputDecoration(
              labelText: 'Texte de la leçon (facultatif)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 6,
            maxLines: 20,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: occupe ? null : _enregistrer,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(lecon == null ? 'Créer la leçon' : 'Enregistrer'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text('Fichiers de la leçon', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (lecon == null)
            Text(
              'Créez d\'abord la leçon : vous pourrez ensuite y ajouter des PDF et des vidéos.',
              style: theme.textTheme.bodySmall,
            )
          else ...[
            if (lecon.ressources.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucun fichier pour le moment.'),
              ),
            for (final r in lecon.ressources)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    r.type == TypeLecon.video
                        ? Icons.play_circle_outline
                        : Icons.picture_as_pdf_outlined,
                  ),
                  title: Text(
                    r.nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(r.type == TypeLecon.video ? 'Vidéo' : 'PDF'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: occupe ? null : () => _retirer(r),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: occupe ? null : () => _ajouter(TypeLecon.pdf),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Ajouter des PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: occupe ? null : () => _ajouter(TypeLecon.video),
                  icon: const Icon(Icons.video_file_outlined),
                  label: const Text('Ajouter des vidéos'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Les fichiers sont enregistrés dès leur envoi. Taille maximale : 50 Mo par fichier.',
              style: theme.textTheme.bodySmall,
            ),
            if (_envoiEnCours != null) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text('Envoi de « $_envoiEnCours » en cours, patientez…'),
            ],
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: occupe ? null : _supprimerLecon,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              label: Text(
                'Supprimer la leçon',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
