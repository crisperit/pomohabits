import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../auth_controller.dart';

enum _AuthMode { signIn, signUp, awaitingConfirmation }

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    // Intentionally resets AsyncValue to clear any inline error on mode change.
    // Safe because the router listens to authStateChangesProvider, not authControllerProvider.
    ref.invalidate(authControllerProvider);
    _formKey.currentState?.reset();
    setState(() {
      _mode = _mode == _AuthMode.signIn ? _AuthMode.signUp : _AuthMode.signIn;
    });
  }

  void _goBackToSignIn() {
    // Intentionally resets AsyncValue to clear any inline error on mode change.
    // Safe because the router listens to authStateChangesProvider, not authControllerProvider.
    ref.invalidate(authControllerProvider);
    setState(() {
      _mode = _AuthMode.signIn;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final notifier = ref.read(authControllerProvider.notifier);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_mode == _AuthMode.signIn) {
      await notifier.signIn(email: email, password: password);
      if (!mounted) return;
    } else {
      final name = _nameController.text.trim();
      final outcome = await notifier.signUp(
        name: name,
        email: email,
        password: password,
      );
      if (!mounted) return;
      if (outcome == AuthSignUpOutcome.awaitingConfirmation) {
        setState(() {
          _mode = _AuthMode.awaitingConfirmation;
        });
      }
      // signedIn: a session now exists; the router redirect (F-01) moves us
      // to /home, so no action here.
    }
  }

  Future<void> _resend() async {
    final email = _emailController.text.trim();
    await ref
        .read(authControllerProvider.notifier)
        .resendConfirmation(email: email);
    if (!mounted) return;
    // Failure path: the _ErrorSlot in _AwaitingConfirmationBody surfaces any
    // error from authControllerProvider automatically; no extra handling needed.
    final authState = ref.read(authControllerProvider);
    if (!authState.hasError) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authResendSuccess)),
      );
    }
  }

  String? _errorMessage(AppLocalizations l10n, AsyncValue<void> state) {
    if (!state.hasError) return null;
    final err = state.error;
    if (err is AuthException) return err.message;
    return l10n.authErrorUnexpected;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    final errorMsg = _errorMessage(l10n, authState);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _mode == _AuthMode.awaitingConfirmation
                  ? _AwaitingConfirmationBody(
                      email: _emailController.text.trim(),
                      isLoading: isLoading,
                      errorMsg: errorMsg,
                      onResend: _resend,
                      onBack: _goBackToSignIn,
                    )
                  : _AuthFormBody(
                      formKey: _formKey,
                      nameController: _nameController,
                      emailController: _emailController,
                      passwordController: _passwordController,
                      confirmPasswordController: _confirmPasswordController,
                      mode: _mode,
                      isLoading: isLoading,
                      errorMsg: errorMsg,
                      onSubmit: _submit,
                      onToggle: _toggleMode,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth form (sign-in / sign-up)
// ---------------------------------------------------------------------------

class _AuthFormBody extends StatelessWidget {
  const _AuthFormBody({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.mode,
    required this.isLoading,
    required this.errorMsg,
    required this.onSubmit,
    required this.onToggle,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final _AuthMode mode;
  final bool isLoading;
  final String? errorMsg;
  final VoidCallback onSubmit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSignUp = mode == _AuthMode.signUp;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isSignUp) ...[
            TextFormField(
              key: const ValueKey('authNameField'),
              controller: nameController,
              decoration: InputDecoration(labelText: l10n.authNameLabel),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.authErrorNameRequired : null,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            key: const ValueKey('authEmailField'),
            controller: emailController,
            decoration: InputDecoration(labelText: l10n.authEmailLabel),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.authErrorEmailRequired;
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
                return l10n.authErrorEmailInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('authPasswordField'),
            controller: passwordController,
            decoration: InputDecoration(labelText: l10n.authPasswordLabel),
            obscureText: true,
            textInputAction:
                isSignUp ? TextInputAction.next : TextInputAction.done,
            validator: (v) => (v == null || v.length < 6)
                ? l10n.authErrorPasswordTooShort
                : null,
          ),
          if (isSignUp) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('authConfirmPasswordField'),
              controller: confirmPasswordController,
              decoration:
                  InputDecoration(labelText: l10n.authConfirmPasswordLabel),
              obscureText: true,
              textInputAction: TextInputAction.done,
              validator: (v) => v != passwordController.text
                  ? l10n.authErrorPasswordMismatch
                  : null,
            ),
          ],
          // Fixed-height error slot: always present so layout does not jump.
          const SizedBox(height: 8),
          _ErrorSlot(message: errorMsg),
          const SizedBox(height: 8),
          ElevatedButton(
            key: const ValueKey('authSubmitButton'),
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    isSignUp ? l10n.authSignUpButton : l10n.authSignInButton,
                  ),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('authToggleButton'),
            onPressed: isLoading ? null : onToggle,
            child: Text(
              isSignUp ? l10n.authToggleToSignIn : l10n.authToggleToSignUp,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Awaiting confirmation screen
// ---------------------------------------------------------------------------

class _AwaitingConfirmationBody extends StatelessWidget {
  const _AwaitingConfirmationBody({
    required this.email,
    required this.isLoading,
    required this.errorMsg,
    required this.onResend,
    required this.onBack,
  });

  final String email;
  final bool isLoading;
  final String? errorMsg;
  final VoidCallback onResend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.authCheckEmailTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.authCheckEmailBody(email),
          textAlign: TextAlign.center,
        ),
        // Fixed-height error slot.
        const SizedBox(height: 8),
        _ErrorSlot(message: errorMsg),
        const SizedBox(height: 8),
        ElevatedButton(
          key: const ValueKey('authResendButton'),
          onPressed: isLoading ? null : onResend,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.authResendButton),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isLoading ? null : onBack,
          child: Text(l10n.authBackToSignIn),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fixed-height error slot
// ---------------------------------------------------------------------------

class _ErrorSlot extends StatelessWidget {
  const _ErrorSlot({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: message != null
          ? Text(
              message!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
    );
  }
}
