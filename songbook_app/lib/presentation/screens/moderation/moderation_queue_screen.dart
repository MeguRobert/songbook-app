import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/submission.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import '../../widgets/content_pane.dart';

/// The moderation queue: submissions awaiting a decision.
///
/// Reaching this screen grants nothing. Every approve and turn-down is an UPDATE
/// that RLS and the status trigger re-check server-side, so a non-admin who
/// navigated here would see an empty list (that is all RLS shows them) and would
/// be refused by Postgres if they somehow issued a decision anyway. The admin
/// check here decides what to *draw*, not what is *allowed*.
class ModerationQueueScreen extends ConsumerWidget {
  const ModerationQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.watch(moderationQueueProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moderationQueueTitle)),
      body: queue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Offline is not an error worth a stack trace in the UI. The queue is
        // simply unavailable until the connection is.
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.authErrorNetwork, textAlign: TextAlign.center),
          ),
        ),
        data: (submissions) => submissions.isEmpty
            ? Center(child: Text(l10n.moderationQueueEmpty))
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(moderationQueueProvider),
                child: ContentPane.list(
                  child: ListView.separated(
                    itemCount: submissions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _QueueRow(
                      submission: submissions[index],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _QueueRow extends ConsumerStatefulWidget {
  final Submission submission;

  const _QueueRow({required this.submission});

  @override
  ConsumerState<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends ConsumerState<_QueueRow> {
  bool _busy = false;

  Future<void> _decide(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      // Re-read rather than mutate a local list: the server is the authority on
      // what is still pending, and another moderator may have acted meanwhile.
      ref.invalidate(moderationQueueProvider);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.moderationDecided)),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.authErrorNetwork)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptReject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectDialog(),
    );

    if (reason == null || !mounted) return;

    final repository = ref.read(submissionRepositoryProvider);
    if (repository == null) return;
    await _decide(() => repository.reject(widget.submission.id, reason));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final song = widget.submission.song;
    final repository = ref.read(submissionRepositoryProvider);

    // Who submitted it, shown at the moment of the decision rather than after
    // it. This is the whole reason attribution exists: a moderator deciding on a
    // song should be able to see whose it is without leaving the queue.
    final credited = widget.submission.submittedByName;
    final attribution = credited == null
        ? null
        : widget.submission.ownerGone
            ? l10n.submittedByFormerMember(credited)
            : l10n.submittedBy(credited);

    return ListTile(
      isThreeLine: attribution != null,
      title: Text(song.title),
      subtitle: Text([
        '${song.number} · ${song.book ?? ''}'.trim(),
        if (attribution != null) attribution,
      ].join('\n')),
      trailing: _busy
          ? const SizedBox(
              height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: repository == null ? null : _promptReject,
                  child: Text(l10n.reject),
                ),
                FilledButton(
                  onPressed: repository == null
                      ? null
                      : () => _decide(
                          () => repository.approve(widget.submission.id)),
                  child: Text(l10n.approve),
                ),
              ],
            ),
    );
  }
}

/// Asking why a song is being turned down.
///
/// Its own `StatefulWidget` because it owns a `TextEditingController`, and a
/// controller has to outlive the dialog's exit animation. Built inline first and
/// disposed the moment `showDialog` returned: the route was popped but still
/// transitioning out, the next frame rebuilt the `TextFormField`, `EditableText`
/// re-subscribed, and the framework threw *A TextEditingController was used
/// after being disposed* on every dismissal — Cancel included. In release the
/// assertion is compiled out and what is left is a listener on a disposed
/// `ChangeNotifier`. Same shape as `_TokenDialog` in `import_song_screen.dart`,
/// for the same reason.
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.reject),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: l10n.rejectReasonLabel),
          // A rejection with no reason is also refused by a database check;
          // validating here just gives a better message than a Postgres error.
          validator: (value) => (value == null || value.trim().isEmpty)
              ? l10n.rejectReasonRequired
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: Text(l10n.reject),
        ),
      ],
    );
  }
}
