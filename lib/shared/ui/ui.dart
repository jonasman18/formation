import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/async_body.dart';

/// Espacements standard.
class Esp {
  const Esp._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double page = 10;
}

/// Fond en dégradé identique à celui de la page de connexion.
class FondDegrade extends StatelessWidget {
  const FondDegrade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(cs.primary.withAlpha(38), cs.surface),
            cs.surface,
            Color.alphaBlend(cs.tertiary.withAlpha(26), cs.surface),
          ],
        ),
      ),
      child: child,
    );
  }
}
/// Contenu défilant centré, construit paresseusement (seuls les éléments
/// visibles sont construits).
Widget _corps({
  required List<Widget> enfants,
  Future<void> Function()? onRefresh,
  bool fab = false,
  double largeurMax = 720,
}) {
  final liste = ListView.builder(
    padding: EdgeInsets.fromLTRB(Esp.page, Esp.l, Esp.page, fab ? 88 : Esp.xl),
    physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    itemCount: enfants.length,
    itemBuilder: (_, i) => enfants[i],
  );
  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: largeurMax),
      child: onRefresh == null
          ? liste
          : RefreshIndicator(onRefresh: onRefresh, child: liste),
    ),
  );
}

/// Page standard : barre de titre + contenu défilant centré.
class PageStandard extends StatelessWidget {
  const PageStandard({
    super.key,
    required this.titre,
    required this.enfants,
    this.actions,
    this.fab,
    this.leading,
    this.onRefresh,
    this.largeurMax = 720,
  });

  final String titre;
  final List<Widget> enfants;
  final List<Widget>? actions;
  final Widget? fab;
  final Widget? leading;
  final Future<void> Function()? onRefresh;
  final double largeurMax;

    @override
  Widget build(BuildContext context) {
    return FondDegrade(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(titre), actions: actions, leading: leading),
        floatingActionButton: fab,
        body: _corps(
          enfants: enfants,
          onRefresh: onRefresh,
          fab: fab != null,
          largeurMax: largeurMax,
        ),
      ),
    );
  }
}

/// Page standard dont le contenu vient d'un provider (chargement / erreur / données).
class PageAsync<T> extends StatelessWidget {
  const PageAsync({
    super.key,
    required this.titre,
    required this.value,
    required this.enfants,
    this.onRetry,
    this.actions,
    this.fab,
    this.leading,
    this.haut,
    this.onRefresh,
    this.largeurMax = 720,
  });

  final String titre;
  final AsyncValue<T> value;
  final List<Widget> Function(T data) enfants;
  final VoidCallback? onRetry;
  final List<Widget>? actions;
  final Widget? fab;
  final Widget? leading;
  final Widget? haut; // zone fixe au-dessus de la liste (ex. recherche)
  final Future<void> Function()? onRefresh;
  final double largeurMax;

   @override
  Widget build(BuildContext context) {
    return FondDegrade(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(titre), actions: actions, leading: leading),
        floatingActionButton: fab,
        body: Column(
          children: [
            if (haut != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Esp.page, Esp.m, Esp.page, 0),
                child: haut,
              ),
            Expanded(
              child: AsyncBody<T>(
                value: value,
                onRetry: onRetry,
                data: (d) => _corps(
                  enfants: enfants(d),
                  onRefresh: onRefresh,
                  fab: fab != null,
                  largeurMax: largeurMax,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte avec titre, icône optionnelle, action optionnelle et message « vide ».
class CarteSection extends StatelessWidget {
  const CarteSection({
    super.key,
    this.titre,
    this.icone,
    this.action,
    this.vide,
    this.enfants = const [],
  });

  final String? titre;
  final IconData? icone;
  final Widget? action;
  final String? vide;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: Esp.m),
      child: Padding(
        padding: const EdgeInsets.all(Esp.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (titre != null) ...[
              Row(
                children: [
                  if (icone != null) ...[
                    Icon(icone, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: Esp.s),
                  ],
                  Expanded(
                    child: Text(titre!, style: theme.textTheme.titleMedium),
                  ),
                  ?action,
                ],
              ),
              const SizedBox(height: Esp.s),
            ],
            if (enfants.isEmpty && vide != null)
              Text(
                vide!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...enfants,
          ],
        ),
      ),
    );
  }
}

/// Carte cliquable (liste de formations, etc.).
class CarteTap extends StatelessWidget {
  const CarteTap({super.key, required this.enfants, this.onTap});

  final List<Widget> enfants;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Esp.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Esp.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: enfants,
          ),
        ),
      ),
    );
  }
}

/// 1 colonne sur téléphone, 2 sur tablette.
class GrilleCartes extends StatelessWidget {
  const GrilleCartes({super.key, required this.enfants, this.colonnesMax = 2});

  final List<Widget> enfants;
  final int colonnesMax;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 640 ? colonnesMax : 1;
        if (cols == 1) return Column(children: enfants);
        final w = (c.maxWidth - Esp.m * (cols - 1)) / cols;
        return Wrap(
          spacing: Esp.m,
          children: [for (final e in enfants) SizedBox(width: w, child: e)],
        );
      },
    );
  }
}

/// Écran « rien à afficher ».
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.message,
    this.icone = Icons.inbox_outlined,
    this.bouton,
  });

  final String message;
  final IconData icone;
  final Widget? bouton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Esp.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: Esp.m),
            Text(message, textAlign: TextAlign.center),
            if (bouton != null) ...[const SizedBox(height: Esp.l), bouton!],
          ],
        ),
      ),
    );
  }
}

enum Ton { neutre, succes, alerte, erreur, info }

/// Petite pastille colorée (statut, score, rôle…).
class Pastille extends StatelessWidget {
  const Pastille(this.texte, {super.key, this.ton = Ton.neutre, this.icone});

  final String texte;
  final Ton ton;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sombre = theme.brightness == Brightness.dark;

    final (Color bg, Color fg) = switch (ton) {
      Ton.succes => sombre
          ? (Colors.green.shade900, Colors.green.shade100)
          : (Colors.green.shade50, Colors.green.shade900),
      Ton.alerte => sombre
          ? (Colors.orange.shade900, Colors.orange.shade100)
          : (Colors.orange.shade50, Colors.orange.shade900),
      Ton.erreur => (cs.errorContainer, cs.onErrorContainer),
      Ton.info => (cs.primaryContainer, cs.onPrimaryContainer),
      Ton.neutre => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            texte,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne compacte : icône, titre, détail, élément à droite.
class LigneInfo extends StatelessWidget {
  const LigneInfo({
    super.key,
    required this.titre,
    this.detail,
    this.icone,
    this.fin,
    this.onTap,
  });

  final String titre;
  final String? detail;
  final IconData? icone;
  final Widget? fin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: onTap,
      leading: icone == null ? null : Icon(icone),
      title: Text(titre),
      subtitle: detail == null ? null : Text(detail!),
      trailing: fin,
    );
  }
}

/// Barre de progression arrondie avec libellé.
class BarreProgression extends StatelessWidget {
  const BarreProgression({super.key, required this.pourcentage, this.etiquette});

  final int pourcentage;
  final String? etiquette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (pourcentage / 100).clamp(0.0, 1.0),
            minHeight: 8,
          ),
        ),
        if (etiquette != null) ...[
          const SizedBox(height: Esp.xs),
          Text(etiquette!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

/// Avatar rond : photo (mise en cache) si elle existe, sinon l'initiale du nom.
class AvatarNom extends StatelessWidget {
  const AvatarNom({super.key, required this.nom, this.url, this.rayon = 20});

  final String nom;
  final String? url;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    final initiale = nom.trim().isEmpty ? '?' : nom.trim()[0].toUpperCase();
    final aPhoto = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: rayon,
      backgroundImage: aPhoto
          ? CachedNetworkImageProvider(url!, maxWidth: (rayon * 2 * 3).round())
          : null,
      child: aPhoto ? null : Text(initiale),
    );
  }
}

/// Minuscules + sans accents, pour une recherche tolérante.
String normaliser(String s) {
  const avec = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿœ';
  const sans = 'aaaaaceeeeiiiinooooouuuuyyo';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = avec.indexOf(c);
    b.write(i >= 0 ? sans[i] : c);
  }
  return b.toString();
}

/// Champ de recherche avec bouton « effacer » et délai de 250 ms
/// (évite de refiltrer la liste à chaque lettre).
class BarreRecherche extends StatefulWidget {
  const BarreRecherche({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Rechercher…',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<BarreRecherche> createState() => _BarreRechercheState();
}

class _BarreRechercheState extends State<BarreRecherche> {
  Timer? _timer;

  void _changer(String v) {
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 250),
      () => widget.onChanged(v),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, v, _) => TextField(
        controller: widget.controller,
        textInputAction: TextInputAction.search,
        onChanged: _changer,
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: v.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _timer?.cancel();
                    widget.controller.clear();
                    widget.onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// Bouton plein avec icône qui affiche un petit indicateur pendant le chargement.
class BoutonChargement extends StatelessWidget {
  const BoutonChargement({
    super.key,
    required this.label,
    required this.icone,
    required this.onPressed,
    this.chargement = false,
    this.labelChargement,
  });

  final String label;
  final IconData icone;
  final VoidCallback? onPressed;
  final bool chargement;
  final String? labelChargement;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: chargement ? null : onPressed,
      icon: chargement
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icone),
      label: Text(chargement ? (labelChargement ?? '…') : label),
    );
  }
}