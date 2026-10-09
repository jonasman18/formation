import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

const tailleMaxOctets = 20 * 1024 * 1024; // 20 Mo
const extensionsRendu = ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'];

class FichierChoisi {
  const FichierChoisi({required this.nom, required this.octets});
  final String nom;
  final Uint8List octets;
}

/// Ouvre le sélecteur de fichiers. Renvoie null si l'utilisateur annule.
Future<FichierChoisi?> choisirFichier({
  required List<String> extensions,
}) async {
  final fichiers = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  if (fichiers.isEmpty) return null;

  final f = fichiers.first;
  final octets = await f.readAsBytes();
  return FichierChoisi(nom: f.name, octets: octets);
}
