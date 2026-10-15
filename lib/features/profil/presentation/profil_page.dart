import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/widgets/avatar_utilisateur.dart';
import '../../../shared/widgets/learner_shell.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/profil_repository.dart';

class ProfilPage extends ConsumerStatefulWidget {
  const ProfilPage({super.key});

  @override
  ConsumerState<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends ConsumerState<ProfilPage> {
  bool _envoi = false;

  void _message(String texte) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
  }

  Future<void> _choisirPhoto(ImageSource source) async {
    try {
      final fichier = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (fichier == null) return;
      setState(() => _envoi = true);
      final octets = await fichier.readAsBytes();
      await ref.read(profilRepositoryProvider).changerAvatar(octets);
      ref.invalidate(currentProfileProvider);
      if (mounted) _message('Photo mise à jour');
    } catch (e) {
      if (mounted) _message('Échec de l\'envoi de la photo : $e');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Future<void> _supprimerPhoto() async {
    try {
      setState(() => _envoi = true);
      await ref.read(profilRepositoryProvider).supprimerAvatar();
      ref.invalidate(currentProfileProvider);
      if (mounted) _message('Photo supprimée');
    } catch (e) {
      if (mounted) _message('Échec : $e');
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  void _menuPhoto(bool aUnePhoto) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () {
                Navigator.pop(ctx);
                _choisirPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _choisirPhoto(ImageSource.camera);
              },
            ),
            if (aUnePhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Supprimer la photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _supprimerPhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _modifierNom(String nom, String prenom) async {
    final res = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _NomDialog(nom: nom, prenom: prenom),
    );
    if (res == null) return;
    try {
      await ref
          .read(profilRepositoryProvider)
          .modifierNomPrenom(nom: res.$1, prenom: res.$2);
      ref.invalidate(currentProfileProvider);
      if (mounted) _message('Profil mis à jour');
    } catch (e) {
      if (mounted) _message('Échec : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(currentProfileProvider);
    final email = ref.watch(supabaseClientProvider).auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Profil')),
      body: profil.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (p) {
          final aUnePhoto = p?.avatarUrl != null && p!.avatarUrl!.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: GestureDetector(
                  onTap: _envoi ? null : () => _menuPhoto(aUnePhoto),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AvatarUtilisateur(
                        nomComplet: p?.fullName ?? '',
                        url: p?.avatarUrl,
                        rayon: 52,
                      ),
                      if (_envoi)
                        const SizedBox(
                          width: 104,
                          height: 104,
                          child: CircularProgressIndicator(),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary,
                          child: Icon(
                            Icons.edit,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  p?.fullName ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (email != null)
                Center(
                  child: Text(
                    email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 8),
              Center(child: Chip(label: Text(p?.role.label ?? ''))),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: p == null
                    ? null
                    : () => _modifierNom(p.nom ?? '', p.prenom ?? ''),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Modifier mon nom'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NomDialog extends StatefulWidget {
  const _NomDialog({required this.nom, required this.prenom});
  final String nom;
  final String prenom;

  @override
  State<_NomDialog> createState() => _NomDialogState();
}

class _NomDialogState extends State<_NomDialog> {
  late final TextEditingController _nom = TextEditingController(
    text: widget.nom,
  );
  late final TextEditingController _prenom = TextEditingController(
    text: widget.prenom,
  );
  final _cle = GlobalKey<FormState>();

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    super.dispose();
  }

  String? _requis(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Obligatoire' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier mon nom'),
      content: Form(
        key: _cle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _prenom,
              decoration: const InputDecoration(labelText: 'Prénom'),
              textCapitalization: TextCapitalization.words,
              validator: _requis,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nom,
              decoration: const InputDecoration(labelText: 'Nom'),
              textCapitalization: TextCapitalization.words,
              validator: _requis,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_cle.currentState!.validate()) {
              Navigator.pop(context, (_nom.text.trim(), _prenom.text.trim()));
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
