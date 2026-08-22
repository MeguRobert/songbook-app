import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/app_role.dart';
import '../../../data/models/managed_user.dart';
import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/content_pane.dart';
import 'role_label.dart';

/// Every account, with what they are allowed to do and what they have submitted.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _query = '';
  AppRole? _roleFilter;

  List<ManagedUser> _filter(List<ManagedUser> users) {
    final needle = _query.trim().toLowerCase();
    return users.where((user) {
      if (_roleFilter != null && user.role != _roleFilter) return false;
      if (needle.isEmpty) return true;
      return user.label.toLowerCase().contains(needle) ||
          (user.email ?? '').toLowerCase().contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(managedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminUsersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            tooltip: l10n.adminInvite,
            onPressed: () => _promptInvite(context),
          ),
        ],
      ),
      body: Column(
        children: [
          ContentPane.form(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: l10n.adminSearchUsers,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: Text(l10n.adminFilterAll),
                          selected: _roleFilter == null,
                          onSelected: (_) => setState(() => _roleFilter = null),
                        ),
                        for (final role in AppRole.values)
                          FilterChip(
                            label: Text(roleLabel(l10n, role)),
                            selected: _roleFilter == role,
                            onSelected: (_) =>
                                setState(() => _roleFilter = role),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  // The commonest cause is not being an administrator any more,
                  // and the second is being offline. Neither is worth a stack
                  // trace on screen.
                  child: Text(l10n.adminUsersUnavailable,
                      textAlign: TextAlign.center),
                ),
              ),
              data: (all) {
                final shown = _filter(all);
                if (shown.isEmpty) {
                  return Center(child: Text(l10n.adminNoMatchingUsers));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.refresh(managedUsersProvider),
                  child: ContentPane.list(
                    child: ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _UserRow(user: shown[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptInvite(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    // Captured before the dialog rather than after it. Reading them from
    // `context` once the await has returned is the use_build_context_synchronously
    // trap: this State's `mounted` says the widget is alive, which is not the
    // same claim as this BuildContext still being valid.
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var role = AppRole.member;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.adminInvite),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: l10n.emailLabel),
                  validator: (value) =>
                      (value == null || !value.contains('@'))
                          ? l10n.authErrorInvalidEmail
                          : null,
                ),
                const SizedBox(height: 12),
                for (final option in AppRole.values)
                  RoleOptionTile(
                    role: option,
                    selected: role,
                    // No descriptions here: the invite dialog is already tall
                    // with a text field above it, and the detail screen's role
                    // picker is where the explanation belongs.
                    showDescription: false,
                    onSelected: (value) => setDialogState(() => role = value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(l10n.adminSendInvite),
            ),
          ],
        ),
      ),
    );

    final email = controller.text;
    controller.dispose();
    if (confirmed != true || !mounted) return;

    final repository = ref.read(adminRepositoryProvider);
    if (repository == null) return;
    try {
      await repository.invite(email, role: role);
      ref.invalidate(managedUsersProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminInviteSent)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionFailed)));
    }
  }
}

class _UserRow extends StatelessWidget {
  final ManagedUser user;

  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tally = user.songs;

    // The tally is here rather than only on the detail screen because it is what
    // a moderator wants at the moment they are looking somebody up: three
    // rejections is a different conversation from three approvals.
    final parts = <String>[
      roleLabel(l10n, user.role),
      if (tally.approved > 0) l10n.adminTallyApproved(tally.approved),
      if (tally.pending > 0) l10n.adminTallyPending(tally.pending),
      if (tally.rejected > 0) l10n.adminTallyRejected(tally.rejected),
      if (user.isDormant) l10n.adminNeverSignedIn,
    ];

    return ListTile(
      leading: CircleAvatar(
        child: Text(user.label.characters.first.toUpperCase()),
      ),
      title: Text(user.label),
      subtitle: Text(parts.join(' · ')),
      trailing: user.emailConfirmed
          ? null
          : Tooltip(
              message: l10n.adminEmailUnconfirmed,
              child: const Icon(Icons.mark_email_unread_outlined, size: 20),
            ),
      onTap: () => context.push(AppRoutes.adminUserPath(user.id)),
    );
  }
}
