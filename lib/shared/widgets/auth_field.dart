import 'package:flutter/material.dart';

/// Décoration commune des champs des pages d'authentification
/// (champ rempli, coins arrondis, contour coloré au focus).
///
/// [errorText] est géré par la page elle-même (et non par un validator
/// de Flutter), ce qui permet de l'effacer de façon fiable.
InputDecoration authInputDecoration(
  ColorScheme scheme, {
  required String label,
  required IconData icon,
  Widget? suffix,
  String? helper,
  String? errorText,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    helperText: helper,
    errorText: errorText,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    filled: true,
    fillColor: scheme.surfaceContainerHighest.withAlpha(110),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: border(Colors.transparent),
    enabledBorder: border(Colors.transparent),
    focusedBorder: border(scheme.primary, 2),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 2),
  );
}

/// Bouton « × » qui n'apparaît que lorsque le champ n'est pas vide.
/// Il vide le champ, appelle [onCleared] (la page y efface l'erreur du
/// champ), puis rend le focus au champ.
class ClearFieldButton extends StatelessWidget {
  const ClearFieldButton({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.tooltip,
    this.onCleared,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String tooltip;
  final VoidCallback? onCleared;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.text.isEmpty) return const SizedBox.shrink();
        return IconButton(
          tooltip: tooltip,
          icon: const Icon(Icons.close),
          onPressed: () {
            controller.clear();
            onCleared?.call();
            focusNode.requestFocus();
          },
        );
      },
    );
  }
}