import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/errors.dart';
import 'inscriptions_providers.dart';

class AccesFormationSwitch extends ConsumerStatefulWidget {
  const AccesFormationSwitch({super.key, required this.formationId});
  final String formationId;

  @override
  ConsumerState<AccesFormationSwitch> createState() =>
      _AccesFormationSwitchState();
}

class _AccesFormationSwitchState extends ConsumerState<AccesFormationSwitch> {
  bool _busy = false;

  Future<void> _changer(bool surDemande) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(inscriptionsRepositoryProvider);
    setState(() => _busy = true);
    try {
      await repo.definirAcces(
        widget.formationId,
        surDemande ? 'sur_demande' : 'libre',
      );
      ref.invalidate(accesFormationProvider(widget.formationId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(humanError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acces =
        ref.watch(accesFormationProvider(widget.formationId)).asData?.value ??
        'libre';
    final surDemande = acces == 'sur_demande';

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Inscription sur validation'),
      subtitle: Text(
        surDemande
            ? 'Les apprenants envoient une demande que vous acceptez ou refusez.'
            : 'Tout apprenant peut s\'inscrire librement.',
      ),
      value: surDemande,
      onChanged: _busy ? null : _changer,
    );
  }
}
