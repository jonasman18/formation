import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(Supabase.instance.client),
);

final utilisateursProvider = FutureProvider.autoDispose<List<Utilisateur>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchUtilisateurs(),
);

final categoriesAdminProvider =
    FutureProvider.autoDispose<List<CategorieAdmin>>(
      (ref) => ref.watch(adminRepositoryProvider).fetchCategories(),
    );
