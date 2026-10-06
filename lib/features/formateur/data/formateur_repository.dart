import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/formation_geree.dart';

class FormateurRepository {
  FormateurRepository(this._client);
  final SupabaseClient _client;

  static const _cols = 'id, titre, description, statut, categorie_id';

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
    final row =
        await _client.from('formations').select(_cols).eq('id', id).single();
    return FormationGeree.fromMap(row);
  }

  Future<List<CategorieOption>> fetchCategories() async {
    final rows = await _client.from('categories').select('id, nom').order('nom');
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
    await _client.from('formations').update({
      'titre': titre,
      'description': description,
      'categorie_id': categorieId,
      'statut': statut,
    }).eq('id', id);
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
  Future<void> creerLecon({
    required String moduleId,
    required String titre,
    required String type,
    String? contenu,
    String? url,
    required int ordre,
  }) async {
    await _client.from('lecons').insert({
      'module_id': moduleId,
      'titre': titre,
      'type': type,
      'contenu': contenu,
      'url': url,
      'ordre': ordre,
    });
  }

  Future<void> modifierLecon(
    String id, {
    required String titre,
    required String type,
    String? contenu,
    String? url,
  }) async {
    await _client.from('lecons').update({
      'titre': titre,
      'type': type,
      'contenu': contenu,
      'url': url,
    }).eq('id', id);
  }

  Future<void> supprimerLecon(String id) async {
    await _client.from('lecons').delete().eq('id', id);
  }

    // ---------- Fichiers (bucket « documents ») ----------
  Future<String> uploaderFichier(
    String formationId,
    File fichier,
    String nom,
  ) async {
    final propre = nom.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final chemin =
        '$formationId/${DateTime.now().millisecondsSinceEpoch}_$propre';
    await _client.storage.from('documents').upload(
          chemin,
          fichier,
          fileOptions: FileOptions(contentType: _mime(nom)),
        );
    return chemin;
  }

  Future<void> supprimerFichier(String chemin) async {
    await _client.storage.from('documents').remove([chemin]);
  }
}

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