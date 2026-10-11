import 'package:supabase_flutter/supabase_flutter.dart';

class CertificatException implements Exception {
  CertificatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CertificatsService {
  CertificatsService(this._client);
  final SupabaseClient _client;

  /// Génère (ou récupère) le certificat et renvoie un lien PDF valable 1 h.
  Future<String> obtenirUrl(String formationId) async {
    try {
      final res = await _client.functions.invoke(
        'generer-certificat',
        body: {'formation_id': formationId},
      );
      final data = res.data;
      final url = data is Map ? data['url'] as String? : null;
      if (url == null) throw CertificatException('Certificat indisponible.');
      return url;
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map && d['error'] != null
          ? '${d['error']}'
          : 'Erreur ${e.status}.';
      throw CertificatException(msg);
    }
  }
}
