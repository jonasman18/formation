import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../shared/widgets/async_body.dart';
import '../../../shared/widgets/learner_shell.dart';
import '../../certificats/data/certificats_service.dart';
import '../domain/formation.dart';
import 'catalogue_providers.dart';

final certificatsServiceProvider = Provider(
  (ref) => CertificatsService(ref.watch(supabaseClientProvider)),
);

class MesFormationsPage extends ConsumerStatefulWidget {
  const MesFormationsPage({super.key});

  @override
  ConsumerState<MesFormationsPage> createState() => _MesFormationsPageState();
}

class _MesFormationsPageState extends ConsumerState<MesFormationsPage> {
  /// Formation dont le certificat est en cours de génération.
  String? _busyId;

  Future<void> _certificat(String formationId) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyId = formationId);
    try {
      final url = await ref
          .read(certificatsServiceProvider)
          .obtenirUrl(formationId);
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossible d’ouvrir le certificat.')),
        );
      }
    } on CertificatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mes = ref.watch(mesFormationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Mes formations'),
      ),
      body: AsyncBody<List<MaFormation>>(
        value: mes,
        onRetry: () => ref.invalidate(mesFormationsProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(mesFormationsProvider);
            await ref.read(mesFormationsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 160),
                    const Center(
                      child: Text('Vous n’êtes inscrit à aucune formation.'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: FilledButton.tonal(
                        onPressed: () => context.go('/catalogue'),
                        child: const Text('Explorer le catalogue'),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final m = items[i];
                    final termine = m.pourcentage >= 100;
                    final enCours = _busyId == m.formation.id;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.go(
                          '/catalogue/formation/${m.formation.id}/cours',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.formation.titre,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(
                                value: m.pourcentage / 100,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${m.pourcentage} % terminé',
                                style: theme.textTheme.labelMedium,
                              ),
                              if (termine) ...[
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: enCours
                                      ? null
                                      : () => _certificat(m.formation.id),
                                  icon: enCours
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.workspace_premium_outlined,
                                        ),
                                  label: Text(
                                    enCours
                                        ? 'Génération…'
                                        : 'Obtenir mon certificat',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
