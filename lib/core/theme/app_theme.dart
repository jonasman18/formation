import 'package:flutter/material.dart';

/// Thème unique de l'application (clair et sombre bleu marine).
/// Les pages n'ont plus besoin de styler cartes, boutons et champs.
class AppTheme {
  static const _seed = Color(0xFF1F4E79);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

     static ColorScheme _schemeSombre() {
    return ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF1B2838),
      surfaceDim: const Color(0xFF16212F),
      surfaceBright: const Color(0xFF34495F),
      surfaceContainerLowest: const Color(0xFF16212F),
      surfaceContainerLow: const Color(0xFF243447), // cartes
      surfaceContainer: const Color(0xFF293A4F),
      surfaceContainerHigh: const Color(0xFF2F425A), // dialogues, menus
      surfaceContainerHighest: const Color(0xFF364B65), // champs, pastilles
      onSurface: const Color(0xFFE6ECF3),
      onSurfaceVariant: const Color(0xFFB8C4D2),
      outline: const Color(0xFF7A8DA3),
      outlineVariant: const Color(0xFF415670),
      primaryContainer: const Color(0xFF2A5F94),
      onPrimaryContainer: const Color(0xFFDCEAFB),
      surfaceTint: Colors.transparent,
    );
  }

    static ThemeData _build(Brightness brightness) {
    final cs = brightness == Brightness.dark
        ? _schemeSombre()
        : ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surface,
    );
    final texte = base.textTheme;
    final arrondi14 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    final styleBouton = texte.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    OutlineInputBorder bordure(Color c, [double largeur = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: largeur),
        );

    return base.copyWith(
      textTheme: texte.copyWith(
        headlineMedium: texte.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: texte.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: texte.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: texte.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      // Transparente : le dégradé de la page passe derrière la barre.
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: arrondi14,
          textStyle: styleBouton,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: arrondi14,
          textStyle: styleBouton,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: arrondi14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        border: bordure(cs.outlineVariant),
        enabledBorder: bordure(cs.outlineVariant),
        focusedBorder: bordure(cs.primary, 2),
        errorBorder: bordure(cs.error),
        focusedErrorBorder: bordure(cs.error, 2),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(color: cs.outlineVariant),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: arrondi14,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      drawerTheme: DrawerThemeData(backgroundColor: cs.surfaceContainerLow),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: cs.surfaceContainerHighest,
      ),
    );
  }
}