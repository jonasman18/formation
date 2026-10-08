import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/utils/pick_file.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/fichier_tile.dart';
import '../data/exercice_fichiers.dart';
import '../domain/exercice.dart';
import 'exercices_providers.dart';

class ExercicePage extends ConsumerStatefulWidget {
  const ExercicePage({
    super.key,
    required this.formationId,
    required this.exerciceId,
  });

  final String formationId;
  final String exerciceId;

  @override
  ConsumerState<ExercicePage> createState() => _ExercicePageState();
}

class _ExercicePageState extends ConsumerState<ExercicePage> {
  final _controller = TextEditingController();
  bool _edition = false;
  bool _busy = false;
  FichierChoisi? _nouveau; // fichier choisi, pas encore envoyé
  bool _retirer = false; // l'apprenant retire le fichier déjà envoyé

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _note(double n) => '${n.toStringAsFixed(n % 1 == 0 ? 0 : 2)} / 20';

  void _msg(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  void _reinitialiserFichier() {
    _nouveau = null;
    _retirer = false;
  }

  Future<void> _choisir() async {
    final f = await choisirFichier(extensions: extensionsRendu);
    if (f == null || !mounted) return;
    if (f.octets.length > tailleMaxOctets) {
      _msg('Fichier trop volumineux (20 Mo maximum).');
      return;
    }
    setState(() {
      _nouveau = f;
      _retirer = false;
    });
  }

  Future<void> _envoyer(Soumission? s) async {
    final texte = _controller.text.trim();
    final ancien = s?.fichierPath;
    final garderAncien = ancien != null && !_retirer && _nouveau == null;

    if (texte.isEmpty && _nouveau == null && !garderAncien) {
      _msg('Écrivez une réponse ou joignez un fichier avant d\'envoyer.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final fichiers = ref.read(exerciceFichiersRepositoryProvider);
    final repo = ref.read(exercicesRepositoryProvider);

    setState(() => _busy = true);
    String? nouveauChemin;
    var soumis = false;
    try {
      if (_nouveau != null) {
        nouveauChemin = await fichiers.uploaderRendu(
          exerciceId: widget.exerciceId,
          nom: _nouveau!.nom,
          octets: _nouveau!.octets,
        );
      }
      await repo.soumettre(
        widget.exerciceId,
        texte,
        fichierPath: nouveauChemin,
        retirerFichier: _retirer && nouveauChemin == null,
      );
      soumis = true;

      if (ancien != null && (nouveauChemin != null || _retirer)) {
        await fichiers.supprimerFichierStockage(
          ExerciceFichiersRepository.bucketRendus,
          ancien,
        );
      }

      ref.invalidate(maSoumissionProvider(widget.exerciceId));
      await ref.read(maSoumissionProvider(widget.exerciceId).future);
      if (mounted) {
        setState(() {
          _edition = false;
          _reinitialiserFichier();
        });
        messenger.showSnackBar(
          const SnackBar(content: Text('Réponse envoyée ✓')),
        );
      }
    } catch (e) {
      if (!soumis && nouveauChemin != null) {
        await fichiers.supprimerFichierStockage(
          ExerciceFichiersRepository.bucketRendus,
          nouveauChemin,
        );
      }
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exo = ref.watch(exerciceProvider(widget.exerciceId));
    final soum = ref.watch(maSoumissionProvider(widget.exerciceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Exercice')),
      body: AsyncBody<Exercice>(
        value: exo,
        onRetry: () => ref.invalidate(exerciceProvider(widget.exerciceId)),
        data: (e) => AsyncBody<Soumission?>(
          value: soum,
          onRetry: () =>
              ref.invalidate(maSoumissionProvider(widget.exerciceId)),
          data: (s) => _contenu(e, s),
        ),
      ),
    );
  }

  Widget _contenu(Exercice e, Soumission? s) {
    final theme = Theme.of(context);
    final enRetard =
        e.dateLimite != null && DateTime.now().isAfter(e.dateLimite!);
    final consignes =
        ref.watch(consignesProvider(widget.exerciceId)).asData?.value ??
        const <FichierJoint>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(e.titre, style: theme.textTheme.headlineSmall),
        if (e.dateLimite != null) ...[
          const SizedBox(height: 4),
          Text(
            'À rendre avant le ${_date(e.dateLimite!)}'
            '${enRetard ? ' (date dépassée)' : ''}',
            style: TextStyle(color: enRetard ? theme.colorScheme.error : null),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          e.consigne ?? 'Aucune consigne.',
          style: theme.textTheme.bodyLarge,
        ),
        if (consignes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Documents', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          for (final f in consignes)
            Card(
              child: FichierTile(
                bucket: ExerciceFichiersRepository.bucketConsignes,
                chemin: f.chemin,
                nom: f.titre,
              ),
            ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        if (s == null || _edition) ..._formulaire(s) else ..._lecture(s),
      ],
    );
  }

  List<Widget> _formulaire(Soumission? s) => [
    Text('Votre réponse', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    TextField(
      controller: _controller,
      minLines: 6,
      maxLines: 14,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Écrivez votre réponse ici (facultatif si vous joignez un fichier)…',
      ),
    ),
    const SizedBox(height: 12),
    if (_nouveau != null)
      Card(
        child: ListTile(
          leading: const Icon(Icons.attach_file),
          title: Text(
            _nouveau!.nom,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            tooltip: 'Retirer',
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : () => setState(() => _nouveau = null),
          ),
        ),
      )
    else if (s?.fichierPath != null && !_retirer)
      Card(
        child: FichierTile(
          bucket: ExerciceFichiersRepository.bucketRendus,
          chemin: s!.fichierPath!,
          nom: nomDepuisChemin(s.fichierPath!),
          trailing: IconButton(
            tooltip: 'Retirer',
            icon: const Icon(Icons.close),
            onPressed: _busy ? null : () => setState(() => _retirer = true),
          ),
        ),
      ),
    OutlinedButton.icon(
      onPressed: _busy ? null : _choisir,
      icon: const Icon(Icons.attach_file),
      label: const Text('Joindre un fichier (PDF, image, Word)'),
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: _busy ? null : () => _envoyer(s),
      icon: _busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send),
      label: Text(s == null ? 'Envoyer' : 'Enregistrer les modifications'),
    ),
    if (s != null)
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                _edition = false;
                _reinitialiserFichier();
              }),
        child: const Text('Annuler'),
      ),
  ];

  List<Widget> _lecture(Soumission s) {
    final theme = Theme.of(context);
    return [
      Row(
        children: [
          Icon(
            s.corrigee ? Icons.task_alt : Icons.hourglass_top,
            color: s.corrigee ? Colors.green : null,
          ),
          const SizedBox(width: 8),
          Text(
            s.corrigee ? 'Corrigé' : 'Envoyé, en attente de correction',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
      const SizedBox(height: 12),
      if ((s.contenu ?? '').isNotEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: double.infinity, child: Text(s.contenu!)),
          ),
        ),
      if (s.fichierPath != null)
        Card(
          child: FichierTile(
            bucket: ExerciceFichiersRepository.bucketRendus,
            chemin: s.fichierPath!,
            nom: nomDepuisChemin(s.fichierPath!),
          ),
        ),
      if (s.corrigee) ...[
        const SizedBox(height: 16),
        if (s.note != null)
          Text(
            'Note : ${_note(s.note!)}',
            style: theme.textTheme.headlineSmall,
          ),
        if ((s.commentaire ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Commentaire du formateur', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(s.commentaire!),
        ],
      ] else ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _controller.text = s.contenu ?? '';
            _reinitialiserFichier();
            _edition = true;
          }),
          icon: const Icon(Icons.edit),
          label: const Text('Modifier ma réponse'),
        ),
      ],
    ];
  }
}
