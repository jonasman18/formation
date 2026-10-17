import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

final adminStatsRepositoryProvider = Provider<AdminStatsRepository>(
  (ref) => AdminStatsRepository(ref.watch(supabaseClientProvider)),
);

/// [jours] == null : depuis le début.
final statsAdminProvider = FutureProvider.autoDispose.family<StatsAdmin, int?>(
  (ref, jours) => ref.watch(adminStatsRepositoryProvider).charger(jours),
);

class PointSerie {
  const PointSerie({
    required this.date,
    required this.inscriptions,
    required this.comptes,
  });
  final String date; // AAAA-MM-JJ
  final int inscriptions;
  final int comptes;
}

class TopFormation {
  const TopFormation({required this.titre, required this.inscrits});
  final String titre;
  final int inscrits;
}

class StatsAdmin {
  const StatsAdmin({
    required this.utilisateurs,
    required this.apprenants,
    required this.formateurs,
    required this.admins,
    required this.nouveauxUtilisateurs,
    required this.formations,
    required this.publiees,
    required this.brouillons,
    required this.archivees,
    required this.inscriptions,
    required this.inscriptionsPeriode,
    required this.certificats,
    required this.certificatsPeriode,
    required this.top,
    required this.parMois,
    required this.serie,
  });

  factory StatsAdmin.fromMap(Map<String, dynamic> m) {
    Map<String, dynamic> sub(String k) =>
        Map<String, dynamic>.from(m[k] as Map);
    int n(Map<String, dynamic> x, String k) => (x[k] as num).toInt();

    final u = sub('utilisateurs');
    final f = sub('formations');
    final i = sub('inscriptions');
    final c = sub('certificats');

    return StatsAdmin(
      utilisateurs: n(u, 'total'),
      apprenants: n(u, 'apprenants'),
      formateurs: n(u, 'formateurs'),
      admins: n(u, 'admins'),
      nouveauxUtilisateurs: n(u, 'nouveaux'),
      formations: n(f, 'total'),
      publiees: n(f, 'publiees'),
      brouillons: n(f, 'brouillons'),
      archivees: n(f, 'archivees'),
      inscriptions: n(i, 'total'),
      inscriptionsPeriode: n(i, 'periode'),
      certificats: n(c, 'total'),
      certificatsPeriode: n(c, 'periode'),
      top: [
        for (final t in m['top_formations'] as List)
          TopFormation(
            titre: t['titre'] as String,
            inscrits: (t['inscrits'] as num).toInt(),
          ),
      ],
      parMois: m['pas'] == 'month',
      serie: [
        for (final p in m['serie'] as List)
          PointSerie(
            date: p['date'] as String,
            inscriptions: (p['inscriptions'] as num).toInt(),
            comptes: (p['comptes'] as num).toInt(),
          ),
      ],
    );
  }

  final int utilisateurs;
  final int apprenants;
  final int formateurs;
  final int admins;
  final int nouveauxUtilisateurs;
  final int formations;
  final int publiees;
  final int brouillons;
  final int archivees;
  final int inscriptions;
  final int inscriptionsPeriode;
  final int certificats;
  final int certificatsPeriode;
  final List<TopFormation> top;
  final bool parMois;
  final List<PointSerie> serie;
}

class AdminStatsRepository {
  AdminStatsRepository(this._client);
  final SupabaseClient _client;

  Future<StatsAdmin> charger(int? jours) async {
    final res = await _client.rpc(
      'admin_statistiques',
      params: {'p_jours': jours},
    );
    return StatsAdmin.fromMap(Map<String, dynamic>.from(res as Map));
  }
}