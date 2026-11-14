import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cle = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _charger();
    return ThemeMode.system;
  }

  Future<void> _charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = switch (p.getString(_cle)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {}
  }

  Future<void> definir(ThemeMode m) async {
    state = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_cle, m.name);
    } catch (_) {}
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Bouton lune / soleil pour basculer entre mode clair et sombre.
class BoutonTheme extends ConsumerWidget {
  const BoutonTheme({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On se base sur le thème réellement affiché (même si le mode est « Auto »).
    final sombre = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: sombre ? 'Mode clair' : 'Mode sombre',
      onPressed: () => ref
          .read(themeModeProvider.notifier)
          .definir(sombre ? ThemeMode.light : ThemeMode.dark),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          sombre ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey(sombre),
        ),
      ),
    );
  }
}