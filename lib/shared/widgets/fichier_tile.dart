import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/errors.dart';

/// Nom lisible à partir d'un chemin de stockage (`<horodatage>_nom.pdf` → `nom.pdf`).
String nomDepuisChemin(String chemin) =>
    chemin.split('/').last.replaceFirst(RegExp(r'^\d+_'), '');

/// Ligne cliquable : génère un lien signé (1 h) et ouvre le fichier.
class FichierTile extends StatefulWidget {
  const FichierTile({
    super.key,
    required this.bucket,
    required this.chemin,
    required this.nom,
    this.trailing,
  });

  final String bucket;
  final String chemin;
  final String nom;
  final Widget? trailing;

  @override
  State<FichierTile> createState() => _FichierTileState();
}

class _FichierTileState extends State<FichierTile> {
  bool _busy = false;

  IconData get _icone {
    final n = widget.nom.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg')) {
      return Icons.image_outlined;
    }
    return Icons.description_outlined;
  }

  Future<void> _ouvrir() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final url = await Supabase.instance.client.storage
          .from(widget.bucket)
          .createSignedUrl(widget.chemin, 3600);
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le fichier.')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _busy
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_icone),
      title: Text(widget.nom, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: widget.trailing,
      onTap: _busy ? null : _ouvrir,
    );
  }
}
