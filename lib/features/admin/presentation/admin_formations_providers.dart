import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/admin_formations_repository.dart';
import '../domain/formation_admin.dart';

final adminFormationsRepositoryProvider = Provider(
  (ref) => AdminFormationsRepository(ref.watch(supabaseClientProvider)),
);

final formationsAdminProvider =
    FutureProvider.autoDispose<List<FormationAdmin>>(
      (ref) => ref.watch(adminFormationsRepositoryProvider).fetch(),
    );
