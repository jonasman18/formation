import 'package:flutter/material.dart';

class AvatarUtilisateur extends StatelessWidget {
  const AvatarUtilisateur({
    super.key,
    required this.nomComplet,
    this.url,
    this.rayon = 20,
  });

  final String nomComplet;
  final String? url;
  final double rayon;

  String get _initiales {
    final mots = nomComplet
        .trim()
        .split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty)
        .toList();
    if (mots.isEmpty) return '?';
    final a = mots.first[0];
    final b = mots.length > 1 ? mots.last[0] : '';
    return (a + b).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final aUneImage = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: rayon,
      backgroundImage: aUneImage ? NetworkImage(url!) : null,
      child: aUneImage
          ? null
          : Text(_initiales, style: TextStyle(fontSize: rayon * 0.7)),
    );
  }
}
