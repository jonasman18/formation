import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_body.dart';
import '../data/admin_stats_repository.dart';

class StatistiquesAdminTab extends ConsumerStatefulWidget {
  const StatistiquesAdminTab({super.key});

  @override
  ConsumerState<StatistiquesAdminTab> createState() =>
      _StatistiquesAdminTabState();
}

class _StatistiquesAdminTabState extends ConsumerState<StatistiquesAdminTab> {
  // 0 = depuis le début
  int _jours = 30;

  int? get _periode => _jours == 0 ? null : _jours;

  String get _libelle => _jours == 0 ? 'au total' : 'sur $_jours jours';

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsAdminProvider(_periode));

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(statsAdminProvider(_periode).future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 7, label: Text('7 j')),
              ButtonSegment(value: 30, label: Text('30 j')),
              ButtonSegment(value: 90, label: Text('90 j')),
              ButtonSegment(value: 0, label: Text('Tout')),
            ],
            selected: {_jours},
            onSelectionChanged: (s) => setState(() => _jours = s.first),
          ),
          const SizedBox(height: 16),
          SizedBox(
            // AsyncBody gère chargement / erreur ; la liste reste défilable
            child: AsyncBody<StatsAdmin>(
              value: stats,
              onRetry: () => ref.invalidate(statsAdminProvider(_periode)),
              data: (s) => _contenu(context, s),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenu(BuildContext context, StatsAdmin s) {
    final theme = Theme.of(context);
    final avecPeriode = _jours != 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _Carte(
              icone: Icons.people_outline,
              titre: 'Utilisateurs',
              valeur: '${s.utilisateurs}',
              detail: avecPeriode
                  ? '+${s.nouveauxUtilisateurs} $_libelle'
                  : '${s.apprenants} apprenants',
            ),
            _Carte(
              icone: Icons.school_outlined,
              titre: 'Formations publiées',
              valeur: '${s.publiees}',
              detail:
                  '${s.formations} au total · ${s.brouillons} brouillon(s)',
            ),
            _Carte(
              icone: Icons.how_to_reg_outlined,
              titre: 'Inscriptions',
              valeur: '${avecPeriode ? s.inscriptionsPeriode : s.inscriptions}',
              detail: avecPeriode
                  ? '$_libelle · ${s.inscriptions} au total'
                  : 'au total',
            ),
            _Carte(
              icone: Icons.workspace_premium_outlined,
              titre: 'Certificats',
              valeur: '${avecPeriode ? s.certificatsPeriode : s.certificats}',
              detail: avecPeriode
                  ? '$_libelle · ${s.certificats} au total'
                  : 'délivrés',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Activité', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          s.parMois ? 'Par mois' : 'Par jour',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SizedBox(height: 220, child: _courbe(context, s)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            _Legende(couleur: theme.colorScheme.primary, texte: 'Inscriptions'),
            _Legende(
              couleur: theme.colorScheme.tertiary,
              texte: 'Nouveaux comptes',
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Utilisateurs par rôle', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _camembert(context, s),
        const SizedBox(height: 24),
        Text(
          'Formations les plus suivies ($_libelle)',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (s.top.isEmpty)
          const Text('Aucune inscription sur cette période.')
        else
          for (final t in s.top) _LigneTop(t: t, max: s.top.first.inscrits),
      ],
    );
  }

  Widget _courbe(BuildContext context, StatsAdmin s) {
    final theme = Theme.of(context);
    final n = s.serie.length;
    if (n == 0) return const Center(child: Text('Pas de données'));

    final maxVal = s.serie
        .map((p) => math.max(p.inscriptions, p.comptes))
        .fold<int>(0, math.max);
    final maxY = math.max(3, (maxVal * 1.2).ceil()).toDouble();
    final pas = math.max(1, ((n - 1) / 4).ceil()).toDouble();

    String etiquette(String d) => s.parMois
        ? '${d.substring(5, 7)}/${d.substring(2, 4)}'
        : '${d.substring(8, 10)}/${d.substring(5, 7)}';

    LineChartBarData ligne(Color c, int Function(PointSerie) valeur) =>
        LineChartBarData(
          spots: [
            for (var i = 0; i < n; i++)
              FlSpot(i.toDouble(), valeur(s.serie[i]).toDouble()),
          ],
          isCurved: false,
          color: c,
          barWidth: 3,
          dotData: FlDotData(show: n <= 14),
        );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(drawVerticalLine: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${value.toInt()}',
                  style: theme.textTheme.bodySmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: pas,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= n) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    etiquette(s.serie[i].date),
                    style: theme.textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          ligne(theme.colorScheme.primary, (p) => p.inscriptions),
          ligne(theme.colorScheme.tertiary, (p) => p.comptes),
        ],
      ),
    );
  }

  Widget _camembert(BuildContext context, StatsAdmin s) {
    final theme = Theme.of(context);
    final donnees = [
      ('Apprenants', s.apprenants, theme.colorScheme.primary),
      ('Formateurs', s.formateurs, theme.colorScheme.tertiary),
      ('Administrateurs', s.admins, theme.colorScheme.secondary),
    ];
    final visibles = donnees.where((d) => d.$2 > 0).toList();
    if (visibles.isEmpty) return const Text('Aucun utilisateur.');

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 28,
              sections: [
                for (final d in visibles)
                  PieChartSectionData(
                    value: d.$2.toDouble(),
                    color: d.$3,
                    radius: 40,
                    title: '${d.$2}',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in donnees)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _Legende(couleur: d.$3, texte: '${d.$1} : ${d.$2}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({
    required this.icone,
    required this.titre,
    required this.valeur,
    required this.detail,
  });

  final IconData icone;
  final String titre;
  final String valeur;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(valeur, style: theme.textTheme.headlineMedium),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  const _Legende({required this.couleur, required this.texte});

  final Color couleur;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(texte),
      ],
    );
  }
}

class _LigneTop extends StatelessWidget {
  const _LigneTop({required this.t, required this.max});

  final TopFormation t;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('${t.inscrits}'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: max == 0 ? 0 : t.inscrits / max,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}