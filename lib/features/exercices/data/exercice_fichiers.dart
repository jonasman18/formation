import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FichierJoint {
  const FichierJoint({
    required this.id,
    required this.titre,
    required this.chemin,
  });
  final String id;
  final String titre;
  final String chemin;
}

class ExerciceFichiersRepository {
  ExerciceFichiersRepository(this._client);
  final SupabaseClient _client;

  static const bucketConsignes = 'documents';
  static const bucketRendus = 'rendus';

  // ---------- Consignes (PDF joints par le formateur) ----------
  Future<List<FichierJoint>> fetchConsignes(String exerciceId) async {
    final rows = await _client
        .from('ressources')
        .select('id, titre, url, ordre')
        .eq('exercice_id', exerciceId)
        .order('ordre');
    return rows
        .map(
          (r) => FichierJoint(
            id: r['id'] as String,
            titre: (r['titre'] as String?) ?? 'Document',
            chemin: r['url'] as String,
          ),
        )
        .toList();
  }

  Future<void> ajouterConsigne({
    required String formationId,
    required String exerciceId,
    required String nom,
    required Uint8List octets,
  }) async {
    final chemin =
        '$formationId/exercices/$exerciceId/${_horodatage()}_${_sain(nom)}';
    await _client.storage
        .from(bucketConsignes)
        .uploadBinary(
          chemin,
          octets,
          fileOptions: FileOptions(contentType: _mime(nom)),
        );
    try {
      await _client.from('ressources').insert({
        'exercice_id': exerciceId,
        'type': 'pdf',
        'titre': nom,
        'url': chemin,
        // l'ordre suit simplement l'ordre d'ajout
        'ordre': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (_) {
      await supprimerFichierStockage(bucketConsignes, chemin);
      rethrow;
    }
  }

  Future<void> supprimerConsigne(FichierJoint f) async {
    await _client.from('ressources').delete().eq('id', f.id);
    await supprimerFichierStockage(bucketConsignes, f.chemin);
  }

  // ---------- Rendus (fichier joint par l'apprenant) ----------
  Future<String> uploaderRendu({
    required String exerciceId,
    required String nom,
    required Uint8List octets,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final chemin = '$exerciceId/$uid/${_horodatage()}_${_sain(nom)}';
    await _client.storage
        .from(bucketRendus)
        .uploadBinary(
          chemin,
          octets,
          fileOptions: FileOptions(contentType: _mime(nom)),
        );
    return chemin;
  }

  Future<String?> fetchFichierSoumission(String soumissionId) async {
    final row = await _client
        .from('soumissions')
        .select('fichier_path')
        .eq('id', soumissionId)
        .maybeSingle();
    return row?['fichier_path'] as String?;
  }

  /// Suppression "au mieux" : une erreur ici ne doit pas bloquer l'action en cours.
  Future<void> supprimerFichierStockage(String bucket, String chemin) async {
    try {
      await _client.storage.from(bucket).remove([chemin]);
    } catch (_) {}
  }

  static String _horodatage() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  // pas d'accents ni d'espaces dans une clé de stockage
  static String _sain(String nom) =>
      nom.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static String _mime(String nom) {
    final n = nom.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (n.endsWith('.doc')) return 'application/msword';
    return 'application/octet-stream';
  }
}

final exerciceFichiersRepositoryProvider = Provider<ExerciceFichiersRepository>(
  (ref) => ExerciceFichiersRepository(Supabase.instance.client),
);

final consignesProvider = FutureProvider.autoDispose
    .family<List<FichierJoint>, String>(
      (ref, exerciceId) => ref
          .watch(exerciceFichiersRepositoryProvider)
          .fetchConsignes(exerciceId),
    );

/// Chemin du fichier rendu pour une soumission (null s'il n'y en a pas).
final fichierSoumissionProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, soumissionId) => ref
          .watch(exerciceFichiersRepositoryProvider)
          .fetchFichierSoumission(soumissionId),
    );
