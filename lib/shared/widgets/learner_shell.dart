import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/notifications/presentation/notifications_providers.dart';

/// Clé du Scaffold du menu : permet de l'ouvrir depuis n'importe quelle page.
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

class _Tab {
  const _Tab(this.path, this.icon, this.selectedIcon, this.label);
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _catalogue = _Tab(
  '/catalogue',
  Icons.explore_outlined,
  Icons.explore,
  'Catalogue',
);
const _mesFormations = _Tab(
  '/mes-formations',
  Icons.school_outlined,
  Icons.school,
  'Mes formations',
);
const _formateur = _Tab(
  '/formateur',
  Icons.cast_for_education_outlined,
  Icons.cast_for_education,
  'Formateur',
);
const _notifications = _Tab(
  '/notifications',
  Icons.notifications_outlined,
  Icons.notifications,
  'Notifications',
);
const _profil = _Tab('/profil', Icons.person_outline, Icons.person, 'Profil');

/// Coque de l'application : menu latéral caché (ouvert par le bouton ☰).
class LearnerShell extends ConsumerWidget {
  const LearnerShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(currentProfileProvider).asData?.value;
    final role = profil?.role.name;
    final estStaff = role == 'formateur' || role == 'admin';
    final nonLues = ref.watch(nonLuesProvider);

    final tabs = [
      _catalogue,
      _mesFormations,
      if (estStaff) _formateur,
      _notifications,
      _profil,
    ];
    final index = tabs.indexWhere((t) => location.startsWith(t.path));

    Widget icone(_Tab t, IconData data) {
      final icon = Icon(data);
      if (t.path != '/notifications' || nonLues == 0) return icon;
      return Badge(label: Text('$nonLues'), child: icon);
    }

    return Scaffold(
      key: shellScaffoldKey,
      drawer: NavigationDrawer(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) {
          shellScaffoldKey.currentState?.closeDrawer();
          context.go(tabs[i].path);
        },
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 24, 16, 12),
            child: Text(
              'Formation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
          for (final t in tabs)
            NavigationDrawerDestination(
              icon: icone(t, t.icon),
              selectedIcon: icone(t, t.selectedIcon),
              label: Text(t.label),
            ),
        ],
      ),
      body: child,
    );
  }
}

/// Bouton ☰ à placer dans `leading:` de l'AppBar des pages principales.
/// Affiche un badge s'il y a des notifications non lues.
class MenuButton extends ConsumerWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nonLues = ref.watch(nonLuesProvider);
    const menu = Icon(Icons.menu);
    return IconButton(
      tooltip: 'Menu',
      icon: nonLues == 0 ? menu : Badge(label: Text('$nonLues'), child: menu),
      onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
    );
  }
}
