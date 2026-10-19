import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

class Niveau {
  const Niveau({
    required this.numero,
    required this.nom,
    required this.seuil,
    required this.suivant,
  });

  final int numero;
  final String nom;
  final int seuil;
  final int? suivant; // null = niveau maximum

  factory Niveau.fromJson(Map<String, dynamic> j) => Niveau(
    numero: _i(j['numero']),
    nom: (j['nom'] as String?) ?? '',
    seuil: _i(j['seuil']),
    suivant: j['suivant'] == null ? null : _i(j['suivant']),
  );
}

class BadgeInfo {
  const BadgeInfo({
    required this.code,
    required this.titre,
    required this.description,
  });

  final String code;
  final String titre;
  final String description;

  factory BadgeInfo.fromJson(Map<String, dynamic> j) => BadgeInfo(
    code: (j['code'] as String?) ?? '',
    titre: (j['titre'] as String?) ?? '',
    description: (j['description'] as String?) ?? '',
  );
}

class MesPoints {
  const MesPoints({
    required this.apprenant,
    required this.points,
    required this.ptsLecons,
    required this.ptsQuiz,
    required this.ptsExamens,
    required this.ptsFormations,
    required this.niveau,
    required this.badges,
    required this.rang,
    required this.visible,
  });

  final bool apprenant;
  final int points;
  final int ptsLecons;
  final int ptsQuiz;
  final int ptsExamens;
  final int ptsFormations;
  final Niveau niveau;
  final List<BadgeInfo> badges;
  final int? rang;
  final bool visible;

  /// Avancement vers le niveau suivant, de 0 à 1.
  double get progression {
    final s = niveau.suivant;
    if (s == null) return 1;
    final etendue = s - niveau.seuil;
    if (etendue <= 0) return 1;
    return ((points - niveau.seuil) / etendue).clamp(0.0, 1.0);
  }

  int? get restant => niveau.suivant == null ? null : niveau.suivant! - points;

  factory MesPoints.fromJson(Map<String, dynamic> j) => MesPoints(
    apprenant: j['apprenant'] == true,
    points: _i(j['points']),
    ptsLecons: _i(j['pts_lecons']),
    ptsQuiz: _i(j['pts_quiz']),
    ptsExamens: _i(j['pts_examens']),
    ptsFormations: _i(j['pts_formations']),
    niveau: Niveau.fromJson(Map<String, dynamic>.from(j['niveau'] as Map)),
    badges: [
      for (final b in (j['badges'] as List? ?? const []))
        BadgeInfo.fromJson(Map<String, dynamic>.from(b as Map)),
    ],
    rang: j['rang'] == null ? null : _i(j['rang']),
    visible: j['visible'] != false,
  );
}

class EntreeClassement {
  const EntreeClassement({
    required this.rang,
    required this.nom,
    required this.avatarUrl,
    required this.points,
    required this.niveau,
    required this.moi,
  });

  final int rang;
  final String nom;
  final String? avatarUrl;
  final int points;
  final String niveau;
  final bool moi;

  factory EntreeClassement.fromJson(Map<String, dynamic> j) =>
      EntreeClassement(
        rang: _i(j['rang']),
        nom: (j['nom'] as String?) ?? 'Apprenant',
        avatarUrl: j['avatar_url'] as String?,
        points: _i(j['points']),
        niveau: (j['niveau'] as String?) ?? '',
        moi: j['moi'] == true,
      );
}

final mesPointsProvider = FutureProvider.autoDispose<MesPoints>((ref) async {
  final r = await Supabase.instance.client.rpc('mes_points');
  return MesPoints.fromJson(Map<String, dynamic>.from(r as Map));
});

final classementProvider =
    FutureProvider.autoDispose<List<EntreeClassement>>((ref) async {
  final r = await Supabase.instance.client.rpc(
    'classement',
    params: {'p_limite': 50},
  );
  return [
    for (final e in (r as List? ?? const []))
      EntreeClassement.fromJson(Map<String, dynamic>.from(e as Map)),
  ];
});

Future<void> definirClassementVisible(bool visible) async {
  await Supabase.instance.client.rpc(
    'definir_classement_visible',
    params: {'p_visible': visible},
  );
}