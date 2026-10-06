import 'dart:io';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(leconId == null ? 'Nouvelle leçon' : 'Modifier la leçon'),
      ),
      body: AsyncBody<List<Module>>(
        value: modules,
        onRetry: () => ref.invalidate(modulesProvider(formationId)),
        data: (items) {
          final module = items.where((m) => m.id == moduleId).firstOrNull;
          if (module == null) {
            return const Center(child: Text('Module introuvable.'));
          }
          Lecon? lecon;
          if (leconId != null) {
            lecon = module.lecons.where((l) => l.id == leconId).firstOrNull;
            if (lecon == null) {
              return const Center(child: Text('Leçon introuvable.'));
            }
          }
          final ordre = lecon?.ordre ??
              module.lecons.fold<int>(0, (a, l) => l.ordre > a ? l.ordre : a) +
                  1;
          return _LeconForm(
            formationId: formationId,
            moduleId: moduleId,
            ordre: ordre,
            initial: lecon,
          );
        },
      ),
    );
  }
}

class _LeconForm extends ConsumerStatefulWidget {
  const _LeconForm({
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
  String _type = 'texte'; // texte | pdf | video
  PlatformFile? _fichier; // fichier choisi mais pas encore envoyé
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final l = widget.initial;
    _titre = TextEditingController(text: l?.titre ?? '');
    _contenu = TextEditingController(text: l?.contenu ?? '');
    _type = l?.type.name ?? 'texte';
  }

  @override
  void dispose() {
    _titre.dispose();
    _contenu.dispose();
    super.dispose();
  }

  String get _retour => '/formateur/formation/${widget.formationId}/contenu';

  /// Fichier déjà enregistré pour ce type (si on modifie une leçon existante).
  String? get _cheminExistant {
    final l = widget.initial;
    if (l == null || l.type.name != _type) return null;
    final u = l.url;
    return (u == null || u.isEmpty) ? null : u;
  }

  String? get _nomFichier {
    if (_fichier != null) return _fichier!.name;
    final c = _cheminExistant;
    if (c == null) return null;
    return c.split('/').last.replaceFirst(RegExp(r'^\d+_'), '');
  }

  bool _estLocal(String? chemin) => chemin != null && !chemin.startsWith('http');

  void _msg(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _choisir() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions:
          _type == 'pdf' ? ['pdf'] : ['mp4', 'mov', 'webm', 'mkv'],
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.path == null) {
      _msg('Impossible de lire ce fichier.');
      return;
    }
    if (f.size > _tailleMaxOctets) {
      _msg('Fichier trop lourd (${(f.size / 1048576).toStringAsFixed(1)} Mo). '
          'Maximum : 50 Mo.');
      return;
    }
    setState(() => _fichier = f);
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type != 'texte' && _fichier == null && _cheminExistant == null) {
      _msg(_type == 'pdf'
          ? 'Choisissez un fichier PDF.'
          : 'Choisissez un fichier vidéo.');
      return;
    }

    final router = GoRouter.of(context);
    final repo = ref.read(formateurRepositoryProvider);
    final ancien = widget.initial?.url;
    setState(() => _busy = true);
    try {
      String? contenu;
      String? url;
      if (_type == 'texte') {
        contenu = _contenu.text.trim();
      } else if (_fichier != null) {
        url = await repo.uploaderFichier(
          widget.formationId,
          File(_fichier!.path!),
          _fichier!.name,
        );
      } else {
        url = _cheminExistant;
      }

      if (widget.initial == null) {
        await repo.creerLecon(
          moduleId: widget.moduleId,
          titre: _titre.text.trim(),
          type: _type,
          contenu: contenu,
          url: url,
          ordre: widget.ordre,
        );
      } else {
        await repo.modifierLecon(
          widget.initial!.id,
          titre: _titre.text.trim(),
          type: _type,
          contenu: contenu,
          url: url,
        );
      }

      // Ménage : on retire l'ancien fichier s'il n'est plus utilisé
      if (_estLocal(ancien) && ancien != url) {
        try {
          await repo.supprimerFichier(ancien!);
        } catch (_) {}
      }

      ref.invalidate(modulesProvider(widget.formationId));
      router.go(_retour);
    } catch (e) {
      if (mounted) _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _supprimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette leçon ?'),
        content: const Text(
            'La progression des apprenants sur cette leçon sera aussi supprimée.'),
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
    final fichier = widget.initial!.url;
    setState(() => _busy = true);
    try {
      await repo.supprimerLecon(widget.initial!.id);
      if (_estLocal(fichier)) {
        try {
          await repo.supprimerFichier(fichier!);
        } catch (_) {}
      }
      ref.invalidate(modulesProvider(widget.formationId));
      router.go(_retour);
    } catch (e) {
      if (mounted) _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nom = _nomFichier;

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
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Le titre est obligatoire' : null,
          ),
          const SizedBox(height: 24),
          Text('Type de contenu', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'texte',
                icon: Icon(Icons.article_outlined),
                label: Text('Texte'),
              ),
              ButtonSegment(
                value: 'pdf',
                icon: Icon(Icons.picture_as_pdf_outlined),
                label: Text('PDF'),
              ),
              ButtonSegment(
                value: 'video',
                icon: Icon(Icons.play_circle_outline),
                label: Text('Vidéo'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: _busy
                ? null
                : (s) => setState(() {
                      _type = s.first;
                      _fichier = null;
                    }),
          ),
          const SizedBox(height: 16),
          if (_type == 'texte')
            TextFormField(
              controller: _contenu,
              decoration: const InputDecoration(
                labelText: 'Contenu',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              minLines: 8,
              maxLines: 20,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (_type == 'texte' &&
                      (v == null || v.trim().isEmpty))
                  ? 'Écrivez le contenu de la leçon'
                  : null,
            )
          else ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _choisir,
              icon: const Icon(Icons.upload_file),
              label: Text(nom == null
                  ? (_type == 'pdf' ? 'Choisir un PDF' : 'Choisir une vidéo')
                  : 'Remplacer le fichier'),
            ),
            if (nom != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(nom, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: _fichier == null
                    ? const Text('Fichier déjà enregistré')
                    : Text(
                        '${(_fichier!.size / 1048576).toStringAsFixed(1)} Mo, '
                        'sera envoyé à l\'enregistrement'),
              ),
            const SizedBox(height: 4),
            Text('Taille maximale : 50 Mo.', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 24),
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
          if (_busy && _fichier != null) ...[
            const SizedBox(height: 8),
            const Text(
              'Envoi du fichier en cours, patientez…',
              textAlign: TextAlign.center,
            ),
          ],
          if (widget.initial != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _supprimer,
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