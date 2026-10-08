import 'user_role.dart';

class Profile {
  const Profile({
    required this.id,
    required this.role,
    this.nom,
    this.prenom,
    this.avatarUrl,
  });

  final String id;
  final UserRole role;
  final String? nom;
  final String? prenom;
  final String? avatarUrl;

  String get fullName {
    final parts = [
      prenom,
      nom,
    ].whereType<String>().where((s) => s.trim().isNotEmpty);
    return parts.isEmpty ? 'Utilisateur' : parts.join(' ');
  }

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
    id: m['id'] as String,
    role: UserRole.fromString(m['role'] as String?),
    nom: m['nom'] as String?,
    prenom: m['prenom'] as String?,
    avatarUrl: m['avatar_url'] as String?,
  );
}
