import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/providers.dart';
import 'auth_messages.dart';

/// Sign in, or create an account.
///
/// Reachable only from Settings, and nothing in the app redirects here. Songbook
/// works signed-out — an account exists to *contribute* songs, not to read them
/// — so this screen is a destination the user chooses, never a gate they hit.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Runs [action], turning any [AuthFailure] into a localized message.
  ///
  /// Every path through this screen goes through here so no server string can
  /// reach the UI by accident.
  Future<void> _run(Future<void> Function() action, {String? successNotice}) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });

    try {
      await action();
      if (!mounted) return;
      setState(() => _notice = successNotice);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = authFailureMessage(l10n, failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  AuthRepository? get _auth => ref.read(authRepositoryProvider);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = _auth;
    if (auth == null) return;

    final email = _email.text;
    final password = _password.text;

    if (_registering) {
      await _run(
        () => auth.signUp(email: email, password: password),
      );
    } else {
      await _run(() => auth.signIn(email: email, password: password));
      // A successful sign-in leaves this screen; the settings entry reflects it.
      if (mounted && _error == null && ref.read(isSignedInProvider)) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _resetPassword() async {
    final auth = _auth;
    if (auth == null) return;
    final l10n = AppLocalizations.of(context);
    // Reset needs only the address, so do not make a blank password block it.
    if (_email.text.trim().isEmpty) {
      setState(() => _error = l10n.authErrorInvalidEmail);
      return;
    }
    await _run(
      () => auth.sendPasswordReset(_email.text),
      successNotice: l10n.passwordResetSent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = ref.watch(authAvailableProvider);
    final title = _registering ? l10n.signUp : l10n.signIn;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: !available
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.accountsUnavailable,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Says up front that this is optional. Nobody should feel
                      // they must register to use a songbook.
                      Text(
                        l10n.accountOptional,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        decoration: InputDecoration(labelText: l10n.emailLabel),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        enabled: !_busy,
                        validator: (value) => (value == null || !value.contains('@'))
                            ? l10n.authErrorInvalidEmail
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration:
                            InputDecoration(labelText: l10n.passwordLabel),
                        obscureText: true,
                        enabled: !_busy,
                        autofillHints: const [AutofillHints.password],
                        // 6 is Supabase's own minimum; validating it here saves a
                        // round trip to be told the same thing.
                        validator: (value) => (value == null || value.length < 6)
                            ? l10n.authErrorWeakPassword
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (_notice != null) ...[
                        const SizedBox(height: 16),
                        Text(_notice!),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(title),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _registering = !_registering;
                                  _error = null;
                                  _notice = null;
                                }),
                        child: Text(_registering
                            ? l10n.haveAccountPrompt
                            : l10n.needAccountPrompt),
                      ),
                      if (!_registering)
                        TextButton(
                          onPressed: _busy ? null : _resetPassword,
                          child: Text(l10n.forgotPassword),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
