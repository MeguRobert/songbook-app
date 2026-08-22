import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../router/app_router.dart';
import '../../providers/admin_provider.dart';

/// Wraps an admin screen and decides whether to show it.
///
/// **A widget rather than a `redirect` on the route, deliberately.** Two reasons,
/// both practical:
///
/// 1. The rank arrives asynchronously. go_router does not re-run `redirect` when
///    a provider changes, so a redirect-based guard would need a
///    `refreshListenable` bridging Riverpod to Listenable, and would still have
///    to answer "checking" with *something* in the meantime. A ConsumerWidget
///    rebuilds on its own when the future resolves.
/// 2. `redirect` runs during navigation, so the denied path means navigating
///    while building — the class of bug that produces "setState during build"
///    in debug and a blank frame in release.
///
/// The three states are the point. A guard that treats not-yet-known as denied
/// bounces an administrator out of a bookmarked `/admin` URL on every cold load,
/// which is the failure mode this file exists to prevent.
class AdminGate extends ConsumerWidget {
  /// Whether this screen needs Administrator, or merely Moderator.
  ///
  /// The moderation queue is the only admin-area screen a moderator may open, so
  /// this is false there and true everywhere else.
  final bool needsAdmin;

  final Widget child;

  const AdminGate({
    super.key,
    required this.child,
    this.needsAdmin = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminAccessProvider(needsAdmin));
    final l10n = AppLocalizations.of(context);

    return switch (access) {
      AdminAccess.granted => child,
      AdminAccess.checking => Scaffold(
          appBar: AppBar(title: Text(l10n.adminTitle)),
          body: const Center(child: CircularProgressIndicator()),
        ),
      AdminAccess.denied => Scaffold(
          appBar: AppBar(title: Text(l10n.adminTitle)),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),
                  // Says it plainly instead of bouncing to the home screen. A
                  // silent redirect from a bookmarked link is indistinguishable
                  // from a broken link, and this area is documented in a public
                  // repo, so its existence is not a secret worth keeping.
                  Text(
                    l10n.adminNotPermitted,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: Text(l10n.routeGoHome),
                  ),
                ],
              ),
            ),
          ),
        ),
    };
  }
}
