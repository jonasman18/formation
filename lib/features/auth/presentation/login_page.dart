import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/auth_field.dart';
import 'auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _emailValide = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String _messageConnexion(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'E-mail ou mot de passe incorrect.';
    }
    if (m.contains('email not confirmed')) {
      return 'Votre e-mail n’est pas encore confirmé. Vérifiez votre boîte de réception.';
    }
  }
  return humanError(e);
}

String? _validerEmail(String v) =>
    _emailValide.hasMatch(v.trim()) ? null : 'E-mail invalide';

String? _validerMotDePasse(String v) =>
    v.isEmpty ? 'Mot de passe requis' : null;

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  bool _masque = true;
  bool _tentative = false;

  /// Erreur du serveur (encadré rouge).
  String? _error;

  /// Erreurs de validation affichées sous les champs. Elles sont gérées
  /// ici à la main : on les efface simplement en les remettant à null.
  String? _emailErreur;
  String? _passwordErreur;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // Pendant la frappe (après une première tentative) : on revalide, sauf
  // si le champ est vide, auquel cas on n'affiche rien.
  void _emailChange(String v) {
    if (!_tentative) return;
    setState(() => _emailErreur = v.isEmpty ? null : _validerEmail(v));
  }

  void _passwordChange(String v) {
    if (!_tentative) return;
    setState(() => _passwordErreur = v.isEmpty ? null : _validerMotDePasse(v));
  }

  Future<void> _submit() async {
    if (_busy) return;

    final emailErr = _validerEmail(_email.text);
    final passErr = _validerMotDePasse(_password.text);
    setState(() {
      _tentative = true;
      _emailErreur = emailErr;
      _passwordErreur = passErr;
    });
    if (emailErr != null) {
      _emailFocus.requestFocus();
      return;
    }
    if (passErr != null) {
      _passwordFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text.trim(), password: _password.text);
      TextInput.finishAutofillContext(); // propose d'enregistrer le mot de passe
      // La redirection vers l'accueil est faite par le routeur.
    } catch (e) {
      TextInput.finishAutofillContext(shouldSave: false);
      if (mounted) setState(() => _error = _messageConnexion(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(scheme.primary.withAlpha(38), scheme.surface),
              scheme.surface,
              Color.alphaBlend(scheme.tertiary.withAlpha(26), scheme.surface),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - v)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(theme, scheme),
                      const SizedBox(height: 32),
                      _buildCard(theme, scheme),
                      const SizedBox(height: 16),
                      _buildRegisterLink(theme, scheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme scheme) {
    return Column(
      children: [
        ExcludeSemantics(
          child: Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.tertiary],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withAlpha(70),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(Icons.school_rounded, size: 36, color: scheme.onPrimary),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            'Formation',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Connectez-vous pour accéder à vos formations',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(ThemeData theme, ColorScheme scheme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _email,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                enableSuggestions: false,
                decoration: authInputDecoration(
                  scheme,
                  label: 'E-mail',
                  icon: Icons.email_outlined,
                  errorText: _emailErreur,
                  suffix: ClearFieldButton(
                    controller: _email,
                    focusNode: _emailFocus,
                    tooltip: 'Effacer l’e-mail',
                    onCleared: () => setState(() {
                      _emailErreur = null;
                      _error = null;
                    }),
                  ),
                ),
                onChanged: _emailChange,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                focusNode: _passwordFocus,
                obscureText: _masque,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: authInputDecoration(
                  scheme,
                  label: 'Mot de passe',
                  icon: Icons.lock_outline,
                  errorText: _passwordErreur,
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClearFieldButton(
                        controller: _password,
                        focusNode: _passwordFocus,
                        tooltip: 'Effacer le mot de passe',
                        onCleared: () => setState(() {
                          _passwordErreur = null;
                          _error = null;
                        }),
                      ),
                      IconButton(
                        tooltip: _masque
                            ? 'Afficher le mot de passe'
                            : 'Masquer le mot de passe',
                        icon: Icon(
                          _masque
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _masque = !_masque),
                      ),
                    ],
                  ),
                ),
                onChanged: _passwordChange,
                onSubmitted: (_) => _submit(),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Semantics(
                          liveRegion: true, // annoncé par TalkBack
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 20,
                                  color: scheme.onErrorContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                // Reste actif pendant le chargement : _submit() ignore
                // déjà les appels quand _busy, et le spinner reste lisible.
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _busy
                    ? SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.onPrimary,
                          semanticsLabel: 'Connexion en cours',
                        ),
                      )
                    : const Text('Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink(ThemeData theme, ColorScheme scheme) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Pas encore de compte ?',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        TextButton(
          onPressed: _busy ? null : () => context.go('/register'),
          child: const Text(
            'S’inscrire',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}