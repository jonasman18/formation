import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/copie.dart';
import '../domain/formation_geree.dart';
import '../domain/quiz_edition.dart';

String _mime(String nom) {
  final ext = nom.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'webm' => 'video/webm',
    'mkv' => 'video/x-matroska',
    _ => 'application/octet-stream',
  };
}

class FormateurRepository {
  FormateurRepository(this._client);
  final SupabaseClient _client;

  static const _cols = 'id, titre, description, statut, categorie_id';

  // ---------- Formations ----------
  Future<List<FormationGeree>> fetchMesFormations() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('formations')
        .select(_cols)
        .eq('formateur_id', uid)
        .order('created_at', ascending: false);
    return rows.map(FormationGeree.fromMap).toList();
  }

  Future<FormationGeree> fetchFormation(String id) async {
    final row = await _client
        .from('formations')
        .select(_cols)
        .eq('id', id)
        .single();
    return FormationGeree.fromMap(row);
  }

  Future<List<CategorieOption>> fetchCategories() async {
    final rows = await _client
        .from('categories')
        .select('id, nom')
        .order('nom');
    return rows.map(CategorieOption.fromMap).toList();
  }

  Future<String> creer({
    required String titre,
    String? description,
    String? categorieId,
    required String statut,
  }) async {
    final row = await _client
        .from('formations')
        .insert({
          'titre': titre,
          'description': description,
          'categorie_id': categorieId,
          'statut': statut,
          'formateur_id': _client.auth.currentUser!.id,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> modifier(
    String id, {
    required String titre,
    String? description,
    String? categorieId,
    required String statut,
  }) async {
    await _client
        .from('formations')
        .update({
          'titre': titre,
          'description': description,
          'categorie_id': categorieId,
          'statut': statut,
        })
        .eq('id', id);
  }

  Future<void> supprimer(String id) async {
    await _client.from('formations').delete().eq('id', id);
  }

  // ---------- Modules ----------
  Future<void> creerModule(String formationId, String titre, int ordre) async {
    await _client.from('modules').insert({
      'formation_id': formationId,
      'titre': titre,
      'ordre': ordre,
    });
  }

  Future<void> renommerModule(String id, String titre) async {
    await _client.from('modules').update({'titre': titre}).eq('id', id);
  }

  Future<void> supprimerModule(String id) async {
    await _client.from('modules').delete().eq('id', id);
  }

  // ---------- Leçons ----------
  Future<String> creerLecon({
    required String moduleId,
    required String titre,
    String? contenu,
    required int ordre,
  }) async {
    final row = await _client
        .from('lecons')
        .insert({
          'module_id': moduleId,
          'titre': titre,
          'type':
              'texte', // champ hérité : le contenu réel est dans « ressources »
          'contenu': contenu,
          'ordre': ordre,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> modifierLecon(
    String id, {
    required String titre,
    String? contenu,
  }) async {
    await _client
        .from('lecons')
        .update({'titre': titre, 'contenu': contenu})
        .eq('id', id);
  }

  Future<void> supprimerLecon(String id) async {
    await _client.from('lecons').delete().eq('id', id);
  }

  // ---------- Fichiers (bucket « documents ») ----------
  Future<String> uploaderFichier(
    String formationId,
    Uint8List octets,
    String nom,
  ) async {
    final propre = nom.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final chemin =
        '$formationId/${DateTime.now().millisecondsSinceEpoch}_$propre';
    await _client.storage
        .from('documents')
        .uploadBinary(
          chemin,
          octets,
          fileOptions: FileOptions(contentType: _mime(nom)),
        );
    return chemin;
  }

  Future<void> supprimerFichier(String chemin) async {
    await _client.storage.from('documents').remove([chemin]);
  }

  // ---------- Ressources (PDF / vidéos d'une leçon) ----------
  Future<void> ajouterRessource({
    required String formationId,
    required String leconId,
    required String type, // 'pdf' | 'video'
    required Uint8List fichier,
    required String nom,
    required String titre,
    required int ordre,
  }) async {
    final chemin = await uploaderFichier(formationId, fichier, nom);
    try {
      await _client.from('ressources').insert({
        'lecon_id': leconId,
        'type': type,
        'titre': titre,
        'url': chemin,
        'ordre': ordre,
      });
    } catch (e) {
      // la ligne n'a pas pu être créée : on retire le fichier envoyé
      try {
        await supprimerFichier(chemin);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> supprimerRessource(String id, String chemin) async {
    await _client.from('ressources').delete().eq('id', id);
    if (!chemin.startsWith('http')) {
      try {
        await supprimerFichier(chemin);
      } catch (_) {}
    }
  }

  // ---------- Copies des apprenants ----------
  /// Copies des exercices de mes formations
  Future<List<Copie>> fetchCopies() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('soumissions')
        .select(
          'id, contenu, note, commentaire, soumis_at, corrige_at, profiles(nom, prenom), exercices(titre, consigne, modules(titre, formations(titre)))',
        )
        .neq('apprenant_id', uid)
        .order('soumis_at', ascending: false);
    return rows.map(Copie.fromMap).toList();
  }

  Future<void> corriger(
    String soumissionId, {
    required double note,
    String? commentaire,
  }) async {
    await _client
        .from('soumissions')
        .update({
          'note': note,
          'commentaire': commentaire,
          'corrige_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', soumissionId);
  }

  // ---------- Quiz ----------
  Future<QuizEdition> fetchQuizEdition(String id) async {
    final row = await _client
        .from('quiz')
        .select(
          'id, titre, note_min, questions(id, enonce, ordre, choix(id, texte, choix_corrects(choix_id)))',
        )
        .eq('id', id)
        .single();
    return QuizEdition.fromMap(row);
  }

  Future<String> enregistrerQuiz({
    required String moduleId,
    String? quizId,
    required String titre,
    required int noteMin,
    required List<Map<String, dynamic>> questions,
  }) async {
    final id = await _client.rpc(
      'enregistrer_quiz',
      params: {
        'p_module': moduleId,
        'p_quiz': quizId,
        'p_titre': titre,
        'p_note_min': noteMin,
        'p_questions': questions,
      },
    );
    return id as String;
  }

  Future<void> supprimerQuiz(String id) async {
    await _client.from('quiz').delete().eq('id', id);
  }

  // ---------- Exercices ----------
  Future<String> creerExercice({
    required String moduleId,
    required String titre,
    String? consigne,
    DateTime? dateLimite,
  }) async {
    final row = await _client
        .from('exercices')
        .insert({
          'module_id': moduleId,
          'titre': titre,
          'consigne': consigne,
          'date_limite': dateLimite?.toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> modifierExercice(
    String id, {
    required String titre,
    String? consigne,
    DateTime? dateLimite,
  }) async {
    await _client
        .from('exercices')
        .update({
          'titre': titre,
          'consigne': consigne,
          'date_limite': dateLimite?.toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> supprimerExercice(String id) async {
    await _client.from('exercices').delete().eq('id', id);
  }
}
