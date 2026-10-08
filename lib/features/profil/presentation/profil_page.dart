import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/widgets/async_body.dart';
import '../../auth/domain/profile.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../shared/widgets/learner_shell.dart';

class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final email = ref.watch(supabaseClientProvider).auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), title: const Text('Profil')),
      body: AsyncBody<Profile?>(
        value: profile,
        onRetry: () => ref.invalidate(currentProfileProvider),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            const Center(
              child: CircleAvatar(
                radius: 40,
                child: Icon(Icons.person, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                p?.fullName ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (email != null) Center(child: Text(email)),
            const SizedBox(height: 8),
            Center(child: Chip(label: Text(p?.role.label ?? ''))),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
          ],
        ),
      ),
    );
  }
}
