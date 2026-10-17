import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/certificats_service.dart';

class CertificatItem {
  const CertificatItem({
    required this.formationId,
    required this.titre,
    required this.code,
    required this.delivreAt,
  });

  final String formationId;
  final String titre;
  final String code;
  final DateTime delivreAt;
}

final mesCertificatsProvider =
    FutureProvider.autoDispose<List<CertificatItem>>((ref) async {
      final client = ref.watch(supabaseClientProvider);
      final uid = client.auth.currentUser?.id;
      if (uid == null) return [];
      final rows = await client
          .from('certificats')
          .select('formation_id, code, delivre_at, formations(titre)')
          .eq('apprenant_id', uid)
          .order('delivre_at', ascending: false);
      return (rows as List).map((r) {
        final m = r as Map<String, dynamic>;
        final formation = m['formations'] as Map<String, dynamic>?;
        return CertificatItem(
          formationId: m['formation_id'] as String,
          titre: (formation?['titre'] as String?) ?? 'Formation',
          code: (m['code'] as String?) ?? '',
          delivreAt: DateTime.parse(m['delivre_at'] as String).toLocal(),
        );
      }).toList();
    });

class MesCertificatsPage extends ConsumerStatefulWidget {
  const MesCertificatsPage({super.key});

  @override
  ConsumerState<MesCertificatsPage> createState() => _MesCertificatsPageState();
}

class _MesCertificatsPageState extends ConsumerState<MesCertificatsPage> {
  String? _enCours;

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _ouvrir(CertificatItem c) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _enCours = c.formationId);
    try {
      final url = await ref
          .read(certificatsServiceProvider)
          .obtenirUrl(c.formationId);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Échec : $e')));
    } finally {
      if (mounted) setState(() => _enCours = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final certificats = ref.watch(mesCertificatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes certificats')),
      body: certificats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (liste) {
          if (liste.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun certificat pour l\'instant.\n'
                  'Terminez une formation à 100 % pour en obtenir un.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(mesCertificatsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: liste.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final c = liste[i];
                final occupe = _enCours == c.formationId;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: Text(c.titre),
                    subtitle: Text(
                      'Délivré le ${_date(c.delivreAt)}'
                      '${c.code.isEmpty ? '' : '\nCode : ${c.code}'}',
                    ),
                    isThreeLine: c.code.isNotEmpty,
                    trailing: occupe
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    onTap: occupe ? null : () => _ouvrir(c),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}