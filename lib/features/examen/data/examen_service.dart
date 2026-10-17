import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

final examenServiceProvider = Provider<ExamenService>(
  (ref) => ExamenService(ref.watch(supabaseClientProvider)),
);

final examenInfosProvider = FutureProvider.autoDispose
    .family<ExamenInfos?, String>(
      (ref, formationId) => ref.watch(examenServiceProvider).infos(formationId),
    );

class ExamenInfos {
  const ExamenInfos({
    required this.titre,
    required this.dureeMin,
    required this.noteMin,
    required this.maxTentatives,
    required this.nbQuestions,
    required this.utilisees,
    required this.meilleure,
    required this.reussi,
    required this.enCours,
    required this.progressionOk,
    required this.delaiRepriseH,
    required this.prochaine,
  });

  factory ExamenInfos.fromMap(Map<String, dynamic> m) => ExamenInfos(
    titre: m['titre'] as String,
    dureeMin: (m['duree_min'] as num).toInt(),
    noteMin: (m['note_min'] as num).toInt(),
    maxTentatives: (m['max_tentatives'] as num).toInt(),
    nbQuestions: (m['nb_questions'] as num).toInt(),
    utilisees: (m['tentatives_utilisees'] as num).toInt(),
    meilleure: (m['meilleure_note'] as num?)?.toInt(),
    reussi: m['reussi'] as bool,
    enCours: m['en_cours'] as bool,
    progressionOk: m['progression_ok'] as bool,
    delaiRepriseH: (m['delai_reprise_h'] as num).toInt(),
    prochaine: m['prochaine_tentative'] == null
        ? null
        : DateTime.parse(m['prochaine_tentative'] as String).toLocal(),
  );

  final String titre;
  final int dureeMin;
  final int noteMin;
  final int maxTentatives;
  final int nbQuestions;
  final int utilisees;
  final int? meilleure;
  final bool reussi;
  final bool enCours;
  final bool progressionOk;
  final int delaiRepriseH;
  final DateTime? prochaine;

  int get restantes => (maxTentatives - utilisees).clamp(0, maxTentatives);

  /// Bloqué tant que l'heure de reprise n'est pas passée.
  bool get bloque => prochaine != null && prochaine!.isAfter(DateTime.now());
}

class ExamenChoix {
  const ExamenChoix({required this.id, required this.texte});
  final String id;
  final String texte;
}

class ExamenQuestion {
  const ExamenQuestion({
    required this.id,
    required this.enonce,
    required this.choix,
  });
  final String id;
  final String enonce;
  final List<ExamenChoix> choix;
}

class ExamenSession {
  const ExamenSession({
    required this.tentativeId,
    required this.restant,
    required this.titre,
    required this.noteMin,
    required this.dureeMin,
    required this.reponses,
    required this.questions,
  });

  factory ExamenSession.fromMap(Map<String, dynamic> m) {
    final limite = DateTime.parse(m['limite_at'] as String);
    final maintenant = DateTime.parse(m['maintenant'] as String);
    final rep = (m['reponses'] as Map?) ?? const {};
    return ExamenSession(
      tentativeId: m['tentative_id'] as String,
      restant: limite.difference(maintenant),
      titre: m['titre'] as String,
      noteMin: (m['note_min'] as num).toInt(),
      dureeMin: (m['duree_min'] as num).toInt(),
      reponses: {
        for (final e in rep.entries)
          e.key as String: {for (final x in e.value as List) x as String},
      },
      questions: [
        for (final q in m['questions'] as List)
          ExamenQuestion(
            id: q['id'] as String,
            enonce: q['enonce'] as String,
            choix: [
              for (final c in q['choix'] as List)
                ExamenChoix(id: c['id'] as String, texte: c['texte'] as String),
            ],
          ),
      ],
    );
  }

  final String tentativeId;
  final Duration restant;
  final String titre;
  final int noteMin;
  final int dureeMin;
  final Map<String, Set<String>> reponses;
  final List<ExamenQuestion> questions;
}

class ExamenResultat {
  const ExamenResultat({
    required this.score,
    required this.reussi,
    required this.bonnes,
    required this.total,
    required this.noteMin,
    required this.tentativesRestantes,
    required this.prochaine,
  });

  factory ExamenResultat.fromMap(Map<String, dynamic> m) => ExamenResultat(
    score: (m['score'] as num).toInt(),
    reussi: m['reussi'] as bool,
    bonnes: (m['bonnes'] as num).toInt(),
    total: (m['total'] as num).toInt(),
    noteMin: (m['note_min'] as num).toInt(),
    tentativesRestantes: (m['tentatives_restantes'] as num).toInt(),
    prochaine: m['prochaine_tentative'] == null
        ? null
        : DateTime.parse(m['prochaine_tentative'] as String).toLocal(),
  );

  final int score;
  final bool reussi;
  final int bonnes;
  final int total;
  final int noteMin;
  final int tentativesRestantes;
  final DateTime? prochaine;
}

class ExamenService {
  ExamenService(this._client);
  final SupabaseClient _client;

  Map<String, dynamic> _payload(Map<String, Set<String>> reponses) => {
    for (final e in reponses.entries) e.key: e.value.toList(),
  };

  Future<ExamenInfos?> infos(String formationId) async {
    final res = await _client.rpc(
      'infos_examen',
      params: {'p_formation': formationId},
    );
    if (res == null) return null;
    return ExamenInfos.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<ExamenSession> demarrer(String formationId) async {
    final res = await _client.rpc(
      'demarrer_examen',
      params: {'p_formation': formationId},
    );
    return ExamenSession.fromMap(Map<String, dynamic>.from(res as Map));
  }

  Future<void> enregistrerReponses(
    String tentativeId,
    Map<String, Set<String>> reponses,
  ) async {
    await _client.rpc(
      'enregistrer_reponses_examen',
      params: {'p_tentative': tentativeId, 'p_reponses': _payload(reponses)},
    );
  }

  Future<ExamenResultat> soumettre(
    String tentativeId,
    Map<String, Set<String>> reponses,
  ) async {
    final res = await _client.rpc(
      'soumettre_examen',
      params: {'p_tentative': tentativeId, 'p_reponses': _payload(reponses)},
    );
    return ExamenResultat.fromMap(Map<String, dynamic>.from(res as Map));
  }
}

/// Ex. : « le 25/10/2026 à 14h30 (dans 6 j 5 h) »
String quandRetenter(DateTime d) {
  String z(int n) => n.toString().padLeft(2, '0');
  final reste = d.difference(DateTime.now());
  final String dans;
  if (reste.inDays > 0) {
    dans = 'dans ${reste.inDays} j ${reste.inHours % 24} h';
  } else if (reste.inHours > 0) {
    dans = 'dans ${reste.inHours} h ${z(reste.inMinutes % 60)} min';
  } else {
    dans = 'dans ${reste.inMinutes + 1} min';
  }
  return 'le ${z(d.day)}/${z(d.month)}/${d.year} à ${z(d.hour)}h${z(d.minute)} ($dans)';
}