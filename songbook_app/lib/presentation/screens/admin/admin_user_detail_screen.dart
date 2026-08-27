import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/app_role.dart';
import '../../../data/models/managed_user.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/admin_provider.dart';
import '../../providers/providers.dart';
import '../../widgets/content_pane.dart';
import 'role_label.dart';

/// One account, and the two things that can be done to it.
class AdminUserDetailScreen extends ConsumerWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(managedUsersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminUserTitle)),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.adminUsersUnavailable)),
        data: (all) {
          final user = all.where((u) => u.id == userId).firstOrNull;
          // Reached after deleting this very account, or via a stale link.
          if (user == null) {
            return Center(child: Text(l10n.adminUserGone));
          }
          return _Detail(user: user);
        },
      ),
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  final ManagedUser user;

  const _Detail({required this.user});

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  bool _busy = false;

  /// Whether this row is the signed-in administrator's own account.
  ///
  /// Both destructive actions are hidden for it. The Edge Function refuses them
  /// too, but a button that always fails is worse than no button: it invites the
  /// tap and then explains itself in a snackbar.
  bool get _isSelf => ref.read(currentUserProvider)?.id == widget.user.id;

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(managedUsersProvider);
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionDone)));
      }
    } on AdminFailure catch (failure) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(_messageFor(l10n, failure.code))),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _messageFor(AppLocalizations l10n, AdminFailureCode code) =>
      switch (code) {
        AdminFailureCode.forbidden => l10n.adminNotPermitted,
        AdminFailureCode.cannotActOnSelf => l10n.adminCannotActOnSelf,
        AdminFailureCode.lastAdministrator => l10n.adminLastAdministrator,
        AdminFailureCode.emailAlreadyRegistered =>
          l10n.authErrorEmailAlreadyRegistered,
        AdminFailureCode.network => l10n.authErrorNetwork,
        AdminFailureCode.unknown => l10n.adminActionFailed,
      };

  Future<void> _promptRole() async {
    final l10n = AppLocalizations.of(context);
    var selected = widget.user.role;

    final chosen = await showDialog<AppRole>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.adminChangeRole),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final role in AppRole.values)
                RoleOptionTile(
                  role: role,
                  selected: selected,
                  onSelected: (value) => setDialogState(() => selected = value),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );

    if (chosen == null || chosen == widget.user.role || !mounted) return;
    final repository = ref.read(adminRepositoryProvider);
    if (repository == null) return;
    await _run(() => repository.setRole(widget.user.id, chosen));
  }

  /// Deleting requires typing the address.
  ///
  /// A confirm dialog with a red button is not enough for something with no undo.
  /// Typing the address is the cheapest control that makes the action deliberate,
  /// and it also makes deleting the *wrong* row nearly impossible -- the mistake
  /// far more likely than deleting the right row by accident.
  Future<void> _promptDelete() async {
    final expected = widget.user.email ?? widget.user.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDialog(expected: expected),
    );

    if (confirmed != true || !mounted) return;

    final repository = ref.read(adminRepositoryProvider);
    if (repository == null) return;
    final router = GoRouter.of(context);
    await _run(() => repository.deleteUser(widget.user.id));
    // Off the detail screen for an account that no longer exists.
    if (mounted) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = widget.user;
    final tally = user.songs;

    return ContentPane.list(
      child: ListView(
        children: [
          ListTile(
            title: Text(user.label,
                style: Theme.of(context).textTheme.headlineSmall),
            subtitle: Text(user.email ?? ''),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(l10n.adminRole),
            subtitle: Text(roleLabel(l10n, user.role)),
            trailing: _isSelf
                ? null
                : TextButton(
                    onPressed: _busy ? null : _promptRole,
                    child: Text(l10n.adminChange),
                  ),
          ),
          if (_isSelf)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.adminCannotActOnSelf,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ListTile(
            leading: const Icon(Icons.mark_email_read_outlined),
            title: Text(l10n.adminEmailStatus),
            subtitle: Text(user.emailConfirmed
                ? l10n.adminEmailConfirmed
                : l10n.adminEmailUnconfirmed),
          ),
          ListTile(
            leading: const Icon(Icons.rule),
            title: Text(l10n.adminGuidelinesStatus),
            subtitle: Text(user.hasAcceptedGuidelines
                ? l10n.adminGuidelinesAccepted
                : l10n.adminGuidelinesNotAccepted),
          ),
          ListTile(
            leading: const Icon(Icons.login),
            title: Text(l10n.adminLastSignIn),
            subtitle: Text(user.lastSignInAt == null
                ? l10n.adminNeverSignedIn
                : '${user.lastSignInAt}'),
          ),
          ListTile(
            leading: const Icon(Icons.library_music_outlined),
            title: Text(l10n.adminSubmissions),
            subtitle: Text([
              l10n.adminTallyApproved(tally.approved),
              l10n.adminTallyPending(tally.pending),
              l10n.adminTallyRejected(tally.rejected),
            ].join(' · ')),
          ),
          const Divider(),
          if (!_isSelf)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_forever_outlined),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _busy ? null : _promptDelete,
                label: Text(l10n.adminDeleteAccount),
              ),
            ),
        ],
      ),
    );
  }
}

/// Typing the address out, for the one action with no undo.
///
/// Its own `StatefulWidget` because it owns a `TextEditingController`, and a
/// controller has to outlive the dialog's exit animation. Built inline first and
/// disposed the moment `showDialog` returned — while the popped route was still
/// transitioning out, so the next frame rebuilt the `TextField`, `EditableText`
/// re-subscribed, and the framework threw *A TextEditingController was used
/// after being disposed* on every dismissal, Cancel included. Same shape as
/// `_TokenDialog` in `import_song_screen.dart`.
class _DeleteDialog extends StatefulWidget {
  /// What has to be typed exactly: the address, or the id when there is none.
  final String expected;

  const _DeleteDialog({required this.expected});

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminDeleteAccount),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.adminDeleteWarning),
          const SizedBox(height: 12),
          // Says outright what survives. Somebody deleting a spammer wants to
          // know their songs go; somebody removing a member who moved away
          // needs to know the hymns stay.
          Text(
            l10n.adminDeleteKeepsApproved,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(l10n.adminDeleteTypeToConfirm(widget.expected)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: _controller.text.trim() == widget.expected
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(l10n.adminDeletePermanently),
        ),
      ],
    );
  }
}
