import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/submission.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/content_pane.dart';

/// What the user sent in, and what happened to it.
///
/// The reason this screen exists at all is the rejection reason. A queue that
/// silently swallows contributions stops receiving them; showing the state and
/// the reason is what makes it worth submitting a second time.
class MySubmissionsScreen extends ConsumerWidget {
  const MySubmissionsScreen({super.key});

  static String statusLabel(AppLocalizations l10n, SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.draft:
        return l10n.statusDraft;
      case SubmissionStatus.pending:
        return l10n.statusPending;
      case SubmissionStatus.approved:
        return l10n.statusApproved;
      case SubmissionStatus.rejected:
        return l10n.statusRejected;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final submissions = ref.watch(mySubmissionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mySubmissionsTitle)),
      body: submissions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.authErrorNetwork, textAlign: TextAlign.center),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.mySubmissionsEmpty))
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(mySubmissionsProvider),
                child: ContentPane.list(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final submission = items[index];
                      final theme = Theme.of(context);

                      return ListTile(
                        title: Text(submission.song.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(statusLabel(l10n, submission.status)),
                            // The reason is the point of the whole screen, so it
                            // gets the error colour and its own line rather than
                            // being tucked into a tooltip.
                            if (submission.isRejected &&
                                submission.rejectionReason != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  submission.rejectionReason!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: submission.isRejected,
                        trailing: submission.isPending
                            ? _WithdrawButton(submission: submission)
                            : null,
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

class _WithdrawButton extends ConsumerWidget {
  final Submission submission;

  const _WithdrawButton({required this.submission});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(submissionRepositoryProvider);

    return TextButton(
      onPressed: repository == null
          ? null
          : () async {
              // Only undecided submissions can be withdrawn, and the delete
              // policy enforces that server-side too — once a song is in the
              // shared songbook it is not the contributor's alone to remove.
              await repository.withdraw(submission.id);
              ref.invalidate(mySubmissionsProvider);
            },
      child: Text(l10n.withdraw),
    );
  }
}
