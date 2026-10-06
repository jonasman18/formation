import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';

class _Tab {
  const _Tab(this.path, this.icon, this.selectedIcon, this.label);
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _catalogue =
    _Tab('/catalogue', Icons.explore_outlined, Icons.explore, 'Catalogue');
const _mesFormations = _Tab(
    '/mes-formations', Icons.school_outlined, Icons.school, 'Mes formations');
const _formateur = _Tab('/formateur', Icons.cast_for_education_outlined,
    Icons.cast_for_education, 'Formateur');
const _profil = _Tab('/profil', Icons.person_outline, Icons.person, 'Profil');

/// Coque de l'application : barre de navigation du bas.
class LearnerShell extends ConsumerWidget {
  const LearnerShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(currentProfileProvider).asData?.value;
    final role = profil?.role.name;
    final estStaff = role == 'formateur' || role == 'admin';

    final tabs = [
      _catalogue,
      _mesFormations,
      if (estStaff) _formateur,
      _profil,
    ];
    final index = tabs.indexWhere((t) => location.startsWith(t.path));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(tabs[i].path),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}