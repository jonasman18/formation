import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/ui/ui.dart';
import '../data/suivi_service.dart';

String _d(DateTime? d) {
  if (d == null) return '—';
  String t(int n) => n.toString().padLeft(2, '0');
  return '${t(d.day)}/${t(d.month)}/${d.year} ${t(d.hour)}h${t(d.minute)}';
}

String _note(double n) => '${n.toStringAsFixed(n % 1 == 0 ? 0 : 2)} / 20';

class SuiviDetailPage extends ConsumerWidget {
  const SuiviDetailPage({
    super.key,
    required this.formationId,
    required this.apprenantId,
  });

  final String formationId;
  final String apprenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cle = (formationId, apprenantId);

    return PageAsync<SuiviDetail>(
      titre: 'Fiche de l\'apprenant',
      value: ref.watch(suiviDetailProvider(cle)),
      onRetry: () => ref.invalidate(suiviDetailProvider(cle)),
      onRefresh: () async {
        ref.invalidate(suiviDetailProvider(cle));
        await ref.read(suiviDetailProvider(cle).future);
      },
      enfants: (d) => [
        Row(
          children: [
            AvatarNom(nom: d.nom, url: d.avatarUrl, rayon: 28),
            const SizedBox(width: Esp.m),
            Expanded(
              child: Text(d.nom, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: Esp.l),
        CarteSection(
          titre: 'Progression',
          icone: Icons.trending_up,
          enfants: [
            BarreProgression(
              pourcentage: d.pourcentage,
              etiquette:
                  '${d.pourcentage} % · ${d.leconsTerminees}/${d.totalLecons} leçons terminées',
            ),
          ],
        ),
        CarteSection(
          titre: 'Quiz',
          icone: Icons.quiz_outlined,
          vide: 'Aucun quiz dans cette formation.',
          enfants: [
            for (final q in d.quiz)
              LigneInfo(
                titre: q.titre,
                detail: q.tentatives == 0
                    ? 'Pas encore tenté'
                    : 'Meilleur score : ${q.meilleurScore ?? 0} %'
                        '${q.noteMin == null ? '' : ' (minimum ${q.noteMin} %)'}'
                        ' · ${q.tentatives} tentative(s)',
                fin: q.tentatives == 0
                    ? const Pastille('Non tenté')
                    : q.reussi
                        ? const Pastille('Réussi', ton: Ton.succes)
                        : const Pastille('Non réussi', ton: Ton.erreur),
              ),
          ],
        ),
        if (d.examen != null)
          CarteSection(
            titre: 'Examen final',
            icone: Icons.workspace_premium_outlined,
            vide: 'Pas encore passé.',
            enfants: [
              for (final t in d.examen!.tentatives)
                LigneInfo(
                  titre: t.statut == 'en_cours'
                      ? 'En cours'
                      : '${t.score ?? 0} %',
                  detail: 'Début : ${_d(t.debutAt)}'
                      '${t.statut == 'expire' ? ' · temps écoulé (soumis automatiquement)' : ''}',
                  fin: t.statut == 'en_cours'
                      ? const Pastille('En cours', ton: Ton.info)
                      : t.reussi
                          ? const Pastille('Réussi', ton: Ton.succes)
                          : const Pastille('Non réussi', ton: Ton.erreur),
                ),
            ],
          ),
        CarteSection(
          titre: 'Exercices',
          icone: Icons.assignment_outlined,
          vide: 'Aucun exercice dans cette formation.',
          enfants: [
            for (final e in d.exercices)
              LigneInfo(
                titre: e.titre,
                detail: !e.rendu
                    ? 'Non rendu'
                    : 'Rendu le ${_d(e.soumisAt)}'
                        '${(e.commentaire ?? '').isEmpty ? '' : '\n« ${e.commentaire} »'}',
                fin: !e.rendu
                    ? const Pastille('Non rendu', ton: Ton.alerte)
                    : e.note == null
                        ? const Pastille('À corriger', ton: Ton.info)
                        : Pastille(_note(e.note!), ton: Ton.succes),
              ),
          ],
        ),
      ],
    );
  }
}