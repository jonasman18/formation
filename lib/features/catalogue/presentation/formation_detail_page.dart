import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../inscriptions/presentation/demande_inscription.dart';
import '../../inscriptions/presentation/inscriptions_providers.dart';
import '../domain/formation.dart';
import 'catalogue_providers.dart';

/// Vrai si l'utilisateur est formateur ou administrateur (donc pas un apprenant).
final estPersonnelProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(currentUserIdProvider);
  final client = ref.watch(supabaseClientProvider);
  final admin = await client.rpc('is_admin');
  if (admin == true) return true;
  final formateur = await client.rpc('is_formateur');
  return formateur == true;
});

/// Vrai si l'utilisateur peut gérer cette formation (propriétaire ou admin).
final peutGererProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  formationId,
) async {
  ref.watch(currentUserIdProvider);
  final client = ref.watch(supabaseClientProvider);
  final r = await client.rpc(
    'peut_gerer',
    params: {'p_formation': formationId},
  );
  return r == true;
});

class FormationDetailPage extends ConsumerStatefulWidget {
  const FormationDetailPage({super.key, required this.formationId});
  final String formationId;

  @override
  ConsumerState<FormationDetailPage> createState() =>
      _FormationDetailPageState();
}

class _FormationDetailPageState extends ConsumerState<FormationDetailPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Données fraîches à chaque ouverture : une demande a pu être acceptée
    // entre-temps (les providers .family restent sinon en cache).
    Future.microtask(_rafraichir);
  }

  Future<void> _rafraichir() async {
    if (!mounted) return;
    final id = widget.formationId;
    ref.invalidate(inscritProvider(id));
    ref.invalidate(accesFormationProvider(id));
    ref.invalidate(maDemandeProvider(id));
  }

  Future<void> _sInscrire() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(catalogueRepositoryProvider).sInscrire(widget.formationId);
      ref.invalidate(inscritProvider(widget.formationId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Bloc d'action pour un formateur ou un administrateur.
  Widget _blocPersonnel(String id) {
    final peutGerer = ref.watch(peutGererProvider(id)).asData?.value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Vous êtes connecté en tant que formateur ou administrateur : '
          'l’inscription est réservée aux apprenants.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.go('/catalogue/formation/$id/cours'),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Voir le contenu'),
        ),
        if (peutGerer) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.go('/formateur/formation/$id'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Gérer cette formation'),
          ),
        ],
      ],
    );
  }

  Widget _blocApprenant(String id) {
    final inscrit = ref.watch(inscritProvider(id));
    final acces = ref.watch(accesFormationProvider(id));
    return inscrit.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(humanError(e)),
      data: (dejaInscrit) {
        if (dejaInscrit) {
          return FilledButton.icon(
            onPressed: () => context.go('/catalogue/formation/$id/cours'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Accéder au cours'),
          );
        }
        return acces.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(humanError(e)),
          data: (mode) => mode == 'sur_demande'
              ? DemandeInscription(formationId: id)
              : FilledButton(
                  onPressed: _busy ? null : _sInscrire,
                  child: const Text('S’inscrire à cette formation'),
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.formationId;
    final formation = ref.watch(formationProvider(id));
    final personnel = ref.watch(estPersonnelProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Formation')),
      body: AsyncBody<Formation>(
        value: formation,
        onRetry: () => ref.invalidate(formationProvider(id)),
        data: (f) => RefreshIndicator(
          onRefresh: _rafraichir,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(f.titre, style: theme.textTheme.headlineSmall),
              if (f.categorie != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(f.categorie!),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(f.description ?? 'Aucune description.'),
              const SizedBox(height: 24),
              personnel.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text(humanError(e)),
                data: (estPersonnel) =>
                    estPersonnel ? _blocPersonnel(id) : _blocApprenant(id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
