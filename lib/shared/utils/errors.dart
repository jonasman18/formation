import 'package:supabase_flutter/supabase_flutter.dart';

/// Message lisible pour l'utilisateur à partir d'une exception.
String humanError(Object error) {
  if (error is AuthException) return error.message;
  if (error is PostgrestException) return error.message;
  return 'Une erreur est survenue. Vérifiez votre connexion et réessayez.';
}
