import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

int _i(dynamic v) => (v as num?)?.round() ?? 0;
int? _in(dynamic v) => v == null ? null : (v as num).round();

class SuiviApprenant {
  const SuiviApprenant({
    required this.id,
    required this.nom,
    required this.avatarUrl,
    required this.pourcentage,
    required this.leconsTerminees,
    required this.totalLecons,
    required this.quizMoyenne,
    required this.quizReussis,
    required this.quizTotal,
    required this.examenExiste,
    required this.examenReussi,
    required this.examenScore,
    required this.examenTentatives,
    required this.rendus,
    required this.exercicesTotal,
    required this.certifie,
  });

  final String id;
  final String nom;
  final String? avatarUrl;
  final int pourcentage;
  final int leconsTerminees;
  final int totalLecons;
  final int? quizMoyenne;
  final int quizReussis;
  final int quizTotal;
  final bool examenExiste;
  final bool examenReussi;
  final int? examenScore;
  final int examenTentatives;
  final int rendus;
  final int exercicesTotal;
  final bool certifie;

  factory SuiviApprenant.fromJson(Map<String, dynamic> j) => SuiviApprenant(
    id: j['apprenant_id'] as String,
    nom: (j['nom'] as String?) ?? 'Apprenant',
    avatarUrl: j['avatar_url'] as String?,
    pourcentage: _i(j['pourcentage']),
    leconsTerminees: _i(j['lecons_terminees']),
    totalLecons: _i(j['total_lecons']),
    quizMoyenne: _in(j['quiz_moyenne']),
    quizReussis: _i(j['quiz_reussis']),
    quizTotal: _i(j['quiz_total']),
    examenExiste: j['examen_existe'] == true,
    examenReussi: j['examen_reussi'] == true,
    examenScore: _in(j['examen_score']),
    examenTentatives: _i(j['examen_tentatives']),
    rendus: _i(j['rendus']),
    exercicesTotal: _i(j['exercices_total']),
    certifie: j['certifie'] == true,
  );
}

class QuizSuivi {
  const QuizSuivi({
    required this.titre,
    required this.noteMin,
    required this.meilleurScore,
    required this.reussi,
    required this.tentatives,
  });

  final String titre;
  final int? noteMin;
  final int? meilleurScore;
  final bool reussi;
  final int tentatives;

  factory QuizSuivi.fromJson(Map<String, dynamic> j) => QuizSuivi(
    titre: (j['titre'] as String?) ?? '',
    noteMin: _in(j['note_min']),
    meilleurScore: _in(j['meilleur_score']),
    reussi: j['reussi'] == true,
    tentatives: _i(j['tentatives']),
  );
}

class TentativeExamen {
  const TentativeExamen({
    required this.debutAt,
    required this.soumisAt,
    required this.score,
    required this.reussi,
    required this.statut,
  });

  final DateTime? debutAt;
  final DateTime? soumisAt;
  final int? score;
  final bool reussi;
  final String statut;

  factory TentativeExamen.fromJson(Map<String, dynamic> j) => TentativeExamen(
    debutAt: _date(j['debut_at']),
    soumisAt: _date(j['soumis_at']),
    score: _in(j['score']),
    reussi: j['reussi'] == true,
    statut: (j['statut'] as String?) ?? '',
  );
}

class ExamenSuivi {
  const ExamenSuivi({
    required this.titre,
    required this.noteMin,
    required this.tentatives,
  });

  final String titre;
  final int? noteMin;
  final List<TentativeExamen> tentatives;
}

class ExerciceSuivi {
  const ExerciceSuivi({
    required this.titre,
    required this.rendu,
    required this.note,
    required this.commentaire,
    required this.soumisAt,
  });

  final String titre;
  final bool rendu;
  final double? note;
  final String? commentaire;
  final DateTime? soumisAt;

  factory ExerciceSuivi.fromJson(Map<String, dynamic> j) => ExerciceSuivi(
    titre: (j['titre'] as String?) ?? '',
    rendu: j['rendu'] == true,
    note: (j['note'] as num?)?.toDouble(),
    commentaire: j['commentaire'] as String?,
    soumisAt: _date(j['soumis_at']),
  );
}

class SuiviDetail {
  const SuiviDetail({
    required this.nom,
    required this.avatarUrl,
    required this.pourcentage,
    required this.leconsTerminees,
    required this.totalLecons,
    required this.quiz,
    required this.examen,
    required this.exercices,
  });

  final String nom;
  final String? avatarUrl;
  final int pourcentage;
  final int leconsTerminees;
  final int totalLecons;
  final List<QuizSuivi> quiz;
  final ExamenSuivi? examen;
  final List<ExerciceSuivi> exercices;

  factory SuiviDetail.fromJson(Map<String, dynamic> j) {
    final ex = j['examen'];
    return SuiviDetail(
      nom: (j['nom'] as String?) ?? 'Apprenant',
      avatarUrl: j['avatar_url'] as String?,
      pourcentage: _i(j['pourcentage']),
      leconsTerminees: _i(j['lecons_terminees']),
      totalLecons: _i(j['total_lecons']),
      quiz: [
        for (final q in (j['quiz'] as List? ?? const []))
          QuizSuivi.fromJson(Map<String, dynamic>.from(q as Map)),
      ],
      examen: ex == null
          ? null
          : ExamenSuivi(
              titre: ((ex as Map)['titre'] as String?) ?? 'Examen final',
              noteMin: _in(ex['note_min']),
              tentatives: [
                for (final t in (ex['tentatives'] as List? ?? const []))
                  TentativeExamen.fromJson(Map<String, dynamic>.from(t as Map)),
              ],
            ),
      exercices: [
        for (final e in (j['exercices'] as List? ?? const []))
          ExerciceSuivi.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
  }
}

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v as String)?.toLocal();

final suiviApprenantsProvider = FutureProvider.autoDispose
    .family<List<SuiviApprenant>, String>((ref, formationId) async {
  final r = await Supabase.instance.client.rpc(
    'suivi_apprenants',
    params: {'p_formation': formationId},
  );
  return [
    for (final e in (r as List? ?? const []))
      SuiviApprenant.fromJson(Map<String, dynamic>.from(e as Map)),
  ];
});

final suiviDetailProvider = FutureProvider.autoDispose
    .family<SuiviDetail, (String, String)>((ref, cle) async {
  final r = await Supabase.instance.client.rpc(
    'suivi_apprenant_detail',
    params: {'p_formation': cle.$1, 'p_apprenant': cle.$2},
  );
  return SuiviDetail.fromJson(Map<String, dynamic>.from(r as Map));
});