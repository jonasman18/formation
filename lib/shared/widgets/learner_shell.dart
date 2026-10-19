import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_providers.dart';
import '../../features/notifications/presentation/notifications_providers.dart';
import 'avatar_utilisateur.dart';
import '../../features/gamification/presentation/ligne_points.dart';

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
const _espaceFormateur = _Tab(
  '/formateur',
  Icons.cast_for_education_outlined,
  Icons.cast_for_education,
  'Espace formateur',
);
const _copies = _Tab(
  '/formateur/copies',
  Icons.rate_review_outlined,
  Icons.rate_review,
  'Copies à corriger',
);
const _demandes = _Tab(
  '/formateur/demandes',
  Icons.how_to_reg_outlined,
  Icons.how_to_reg,
  'Demandes d’inscription',
);
const _admin = _Tab(
  '/admin',
  Icons.admin_panel_settings_outlined,
  Icons.admin_panel_settings,
  'Administration',
);
const _notifications = _Tab(
  '/notifications',
  Icons.notifications_outlined,
  Icons.notifications,
  'Notifications',
);
const _profil = _Tab('/profil', Icons.person_outline, Icons.person, 'Profil');

/// Menus par rôle.
List<_Tab> _onglets(String? role) => switch (role) {
  'admin' => const [_admin, _notifications, _profil],
  'formateur' => const [
    _espaceFormateur,
    _copies,
    _demandes,
    _notifications,
    _profil,
  ],
  _ => const [_catalogue, _mesFormations, _notifications, _profil],
};

/// Coque de l'application : menu latéral caché (ouvert par le bouton ☰).
class LearnerShell extends ConsumerWidget {
  const LearnerShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(currentProfileProvider).asData?.value;
    final role = profil?.role.name;
    final nonLues = ref.watch(nonLuesProvider);

    final tabs = _onglets(role);

    // Onglet dont le chemin correspond le mieux (le plus long) à la page.
    var index = -1;
    var meilleur = -1;
    for (var i = 0; i < tabs.length; i++) {
      final p = tabs[i].path;
      final correspond = location == p || location.startsWith('$p/');
      if (correspond && p.length > meilleur) {
        meilleur = p.length;
        index = i;
      }
    }
    if (role == 'admin' && index < 0 && location.startsWith('/formateur')) {
      index = 0;
    }

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
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Formation',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                if (profil != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      shellScaffoldKey.currentState?.closeDrawer();
                      context.go('/profil');
                    },
                    child: Row(
                      children: [
                        AvatarUtilisateur(
                          nomComplet: profil.fullName,
                          url: profil.avatarUrl,
                          rayon: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profil.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                profil.role.label,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const LignePoints(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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

/// Bouton ☰  dans `leading:` de l'AppBar des pages principales.
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
