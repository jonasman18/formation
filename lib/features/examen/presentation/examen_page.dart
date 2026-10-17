import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../data/examen_service.dart';

class ExamenPage extends ConsumerStatefulWidget {
  const ExamenPage({super.key, required this.formationId});

  final String formationId;

  @override
  ConsumerState<ExamenPage> createState() => _ExamenPageState();
}

class _ExamenPageState extends ConsumerState<ExamenPage>
    with WidgetsBindingObserver {
  ExamenSession? _session;
  Object? _erreur;
  ExamenResultat? _resultat;

  final Map<String, Set<String>> _reponses = {};
  final Stopwatch _chrono = Stopwatch();
  Duration _restantInitial = Duration.zero;
  DateTime _limiteLocale = DateTime.now();
  Duration _restant = Duration.zero;

  Timer? _tick;
  Timer? _sauve;
  DateTime _dernierEssai = DateTime.fromMillisecondsSinceEpoch(0);

  bool _sale = false;
  bool _envoi = false;
  bool _termine = false;
  bool _autoSoumis = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _demarrer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _sauve?.cancel();
    _chrono.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _sauvegarder();
    } else if (state == AppLifecycleState.resumed) {
      _maj();
    }
  }

  void _msg(String texte) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _demarrer() async {
    try {
      final s = await ref
          .read(examenServiceProvider)
          .demarrer(widget.formationId);
      if (!mounted) return;
      setState(() {
        _session = s;
        _reponses.addAll(s.reponses);
        _restantInitial = s.restant;
        _limiteLocale = DateTime.now().add(s.restant);
        _restant = s.restant;
      });
      _chrono.start();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _maj());
      _sauve = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _sauvegarder(),
      );
      _maj();
    } catch (e) {
      if (mounted) setState(() => _erreur = e);
    }
  }

  void _maj() {
    if (_session == null || _termine || !mounted) return;
    final r1 = _restantInitial - _chrono.elapsed;
    final r2 = _limiteLocale.difference(DateTime.now());
    var r = r1 < r2 ? r1 : r2;
    if (r.isNegative) r = Duration.zero;
    setState(() => _restant = r);

    if (r == Duration.zero &&
        !_envoi &&
        DateTime.now().difference(_dernierEssai) > const Duration(seconds: 5)) {
      _envoyer(auto: true);
    }
  }

  Future<void> _sauvegarder() async {
    final s = _session;
    if (s == null || !_sale || _termine || !mounted) return;
    _sale = false;
    try {
      await ref
          .read(examenServiceProvider)
          .enregistrerReponses(s.tentativeId, _reponses);
    } catch (_) {
      _sale = true;
    }
  }

  Future<void> _envoyer({bool auto = false}) async {
    final s = _session;
    if (s == null || _envoi || _termine) return;

    if (!auto) {
      final vides = s.questions
          .where((q) => (_reponses[q.id] ?? {}).isEmpty)
          .length;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Soumettre l\'examen ?'),
          content: Text(
            vides > 0
                ? 'Il reste $vides question(s) sans réponse : elles compteront '
                      'comme fausses. Une fois soumis, vous ne pourrez plus '
                      'modifier vos réponses.'
                : 'Une fois soumis, vous ne pourrez plus modifier vos réponses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Revenir à l\'examen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Soumettre'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted || _envoi || _termine) return;
    }

    _dernierEssai = DateTime.now();
    setState(() => _envoi = true);
    try {
      final res = await ref
          .read(examenServiceProvider)
          .soumettre(s.tentativeId, _reponses);
      if (!mounted) return;
      _tick?.cancel();
      _sauve?.cancel();
      ref.invalidate(examenInfosProvider(widget.formationId));
      setState(() {
        _resultat = res;
        _termine = true;
        _autoSoumis = auto;
      });
    } catch (e) {
      if (!auto) _msg(humanError(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _confirmerSortie() async {
    final quitter = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter l\'examen ?'),
        content: const Text(
          'Le chronomètre continue de tourner. Vous pourrez reprendre tant '
          'que le temps n\'est pas écoulé ; à la fin du temps, vos réponses '
          'enregistrées seront corrigées automatiquement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Rester'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (quitter != true || !mounted) return;
    await _sauvegarder();
    if (mounted) context.pop();
  }

  String _format(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _session;
    final enCours = s != null && _resultat == null;
    final urgent = _restant < const Duration(seconds: 60);
    final total = s == null ? 1 : (s.dureeMin * 60).clamp(1, 1 << 30);

    return PopScope(
      canPop: _resultat != null || s == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmerSortie();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Examen final'),
          actions: [
            if (enCours)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    _format(_restant),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: urgent ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
              ),
          ],
          bottom: enCours
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(
                    value: (_restant.inSeconds / total).clamp(0.0, 1.0),
                    color: urgent ? theme.colorScheme.error : null,
                  ),
                )
              : null,
        ),
        body: _corps(theme),
      ),
    );
  }

  Widget _corps(ThemeData theme) {
    if (_erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(humanError(_erreur!), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }
    final s = _session;
    if (s == null) return const Center(child: CircularProgressIndicator());
    if (_resultat != null) return _resultatView(theme, _resultat!);
    return _formulaire(theme, s);
  }

  Widget _formulaire(ThemeData theme, ExamenSession s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.titre, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Note minimale pour réussir : ${s.noteMin} %. '
          'Plusieurs réponses peuvent être justes. '
          'Vos réponses sont enregistrées automatiquement.',
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < s.questions.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '${i + 1}. ${s.questions[i].enonce}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  for (final c in s.questions[i].choix)
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(c.texte),
                      value: (_reponses[s.questions[i].id] ?? {}).contains(
                        c.id,
                      ),
                      onChanged: _envoi
                          ? null
                          : (v) => setState(() {
                              final set = _reponses.putIfAbsent(
                                s.questions[i].id,
                                () => <String>{},
                              );
                              if (v == true) {
                                set.add(c.id);
                              } else {
                                set.remove(c.id);
                              }
                              _sale = true;
                            }),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _envoi ? null : () => _envoyer(),
          child: _envoi
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Soumettre l\'examen'),
        ),
      ],
    );
  }

  Widget _resultatView(ThemeData theme, ExamenResultat r) {
    final couleur = r.reussi ? Colors.green : theme.colorScheme.error;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          r.reussi ? Icons.emoji_events : Icons.sentiment_dissatisfied,
          size: 72,
          color: couleur,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '${r.score} %',
            style: theme.textTheme.displayMedium?.copyWith(color: couleur),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            r.reussi ? 'Bravo, examen réussi !' : 'Examen non réussi',
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '${r.bonnes} bonne(s) réponse(s) sur ${r.total} '
            '(minimum requis : ${r.noteMin} %)',
            textAlign: TextAlign.center,
          ),
        ),
        if (_autoSoumis) ...[
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Le temps était écoulé : l\'examen a été soumis automatiquement.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (!r.reussi) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              r.tentativesRestantes > 0
                  ? 'Il vous reste ${r.tentativesRestantes} tentative(s).'
                  : r.prochaine != null
                  ? 'Plus de tentatives pour le moment. '
                        'Vous pourrez retenter ${quandRetenter(r.prochaine!)}.'
                  : 'Vous n\'avez plus de tentatives.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 32),
        if (r.reussi) ...[
          FilledButton(
            onPressed: () => context.go('/mes-formations'),
            child: const Text('Obtenir mon certificat'),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          onPressed: () =>
              context.go('/catalogue/formation/${widget.formationId}/cours'),
          child: const Text('Retour au cours'),
        ),
      ],
    );
  }
}