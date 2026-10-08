import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/errors.dart';
import '../../../shared/widgets/async_body.dart';
import '../domain/app_notification.dart';
import 'notifications_providers.dart';

String _date(DateTime d) {
  String d2(int n) => n.toString().padLeft(2, '0');
  return '${d2(d.day)}/${d2(d.month)}/${d.year} ${d2(d.hour)}:${d2(d.minute)}';
}

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  Future<void> _agir(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(humanError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);
    final nonLues = ref.watch(nonLuesProvider);
    final repo = ref.read(notificationsRepositoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (nonLues > 0)
            TextButton(
              onPressed: () => _agir(context, repo.toutMarquerLu),
              child: const Text('Tout marquer lu'),
            ),
        ],
      ),
      body: AsyncBody<List<AppNotification>>(
        value: notifs,
        onRetry: () => ref.invalidate(notificationsProvider),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationsProvider);
            await ref.read(notificationsProvider.future);
          },
          child: items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Aucune notification.')),
                  ],
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return ListTile(
                      isThreeLine: (n.corps ?? '').isNotEmpty,
                      leading: Icon(
                        n.lue
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: n.lue ? null : theme.colorScheme.primary,
                      ),
                      title: Text(
                        n.titre,
                        style: TextStyle(
                          fontWeight: n.lue
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${(n.corps ?? '').isEmpty ? '' : '${n.corps}\n'}${_date(n.createdAt)}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            _agir(context, () => repo.supprimer(n.id)),
                      ),
                      onTap: n.lue
                          ? null
                          : () => _agir(context, () => repo.marquerLue(n.id)),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
