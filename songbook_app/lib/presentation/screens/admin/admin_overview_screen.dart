import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../providers/admin_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/content_pane.dart';

/// The administration home: what needs attention, and where to go.
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.watch(moderationQueueProvider);
    final users = ref.watch(managedUsersProvider);
    final settings = ref.watch(appSettingsProvider);

    // A count that has not loaded shows an em dash rather than a zero. "0
    // waiting" and "not loaded" are different facts and a moderator acts
    // differently on each.
    String count(AsyncValue<List<Object>> value) => value.maybeWhen(
          data: (items) => '${items.length}',
          orElse: () => '—',
        );

    final submissionsClosed = settings.maybeWhen(
      data: (value) => !value.submissionsOpen,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminTitle)),
      body: ContentPane.list(
        child: ListView(
          children: [
            if (submissionsClosed)
              // Surfaced here because a closed door is easy to set and easy to
              // forget, and the symptom -- nobody can contribute -- looks like a
              // bug from every other seat in the project.
              Card(
                margin: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.do_not_disturb_on_outlined),
                  title: Text(l10n.adminSubmissionsClosedNotice),
                  trailing: TextButton(
                    onPressed: () => context.push(AppRoutes.adminSettings),
                    child: Text(l10n.adminReopen),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: Text(l10n.moderationQueueTitle),
              subtitle: Text(l10n.adminWaitingCount(count(queue))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.adminQueue),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: Text(l10n.adminUsersTitle),
              subtitle: Text(l10n.adminMemberCount(count(users))),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.adminUsers),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: Text(l10n.adminSettingsTitle),
              subtitle: Text(l10n.adminSettingsSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.adminSettings),
            ),
          ],
        ),
      ),
    );
  }
}
