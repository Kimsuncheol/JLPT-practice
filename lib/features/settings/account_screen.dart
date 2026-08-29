import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/account_service.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_providers.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('account'))),
      body: SafeArea(
        child: user?.isAnonymous == false
            ? _AccountDetails(user: user!)
            : _AuthForm(
                formKey: _formKey,
                emailController: _emailController,
                passwordController: _passwordController,
                confirmPasswordController: _confirmPasswordController,
                createAccount: _createAccount,
                busy: _busy,
                hidePassword: _hidePassword,
                onTogglePassword: () =>
                    setState(() => _hidePassword = !_hidePassword),
                onSubmit: _submitEmail,
                onGoogle: _continueWithGoogle,
                onApple:
                    !kIsWeb &&
                        (defaultTargetPlatform == TargetPlatform.iOS ||
                            defaultTargetPlatform == TargetPlatform.macOS)
                    ? _continueWithApple
                    : null,
                onResetPassword: _sendPasswordReset,
                onToggleMode: () => setState(() {
                  _createAccount = !_createAccount;
                  _formKey.currentState?.reset();
                }),
              ),
      ),
    );
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    await _run(() async {
      final service = ref.read(accountServiceProvider);
      if (_createAccount) {
        await service.registerWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await service.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      await _finishAuthentication();
    });
  }

  Future<void> _continueWithGoogle() => _run(() async {
    await ref.read(accountServiceProvider).continueWithGoogle();
    await _finishAuthentication();
  });

  Future<void> _continueWithApple() => _run(() async {
    await ref.read(accountServiceProvider).continueWithApple();
    await _finishAuthentication();
  });

  Future<void> _finishAuthentication() async {
    await ref.read(appControllerProvider.notifier).mergeCurrentAccount();
    ref.invalidate(grammarProgressProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings('progressProtected'))),
    );
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      _showMessage(context.strings('enterValidEmail'));
      return;
    }
    await _run(() async {
      await ref.read(accountServiceProvider).sendPasswordReset(email);
      if (mounted) _showMessage(context.strings('resetEmailSent'));
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } on FirebaseAuthException catch (error) {
      if (mounted) _showMessage(_authError(error.code));
    } on Object catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authError(String code) => switch (code) {
    'email-already-in-use' => context.strings('emailAlreadyInUse'),
    'invalid-email' => context.strings('enterValidEmail'),
    'weak-password' => context.strings('weakPassword'),
    'wrong-password' ||
    'invalid-credential' => context.strings('invalidCredentials'),
    'user-not-found' => context.strings('invalidCredentials'),
    'network-request-failed' => context.strings('networkDisconnectedBody'),
    'too-many-requests' => context.strings('tooManyRequests'),
    _ => context.strings('accountError'),
  };

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.createAccount,
    required this.busy,
    required this.hidePassword,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onGoogle,
    required this.onApple,
    required this.onResetPassword,
    required this.onToggleMode,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool createAccount;
  final bool busy;
  final bool hidePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback? onApple;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
    child: Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            context.strings(
              createAccount ? 'createAccountTitle' : 'protectProgressTitle',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.strings('protectProgressBody'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: busy ? null : onGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: Text(context.strings('continueWithGoogle')),
          ),
          if (onApple != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : onApple,
              icon: const Icon(Icons.apple_rounded),
              label: Text(context.strings('continueWithApple')),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(context.strings('orUseEmail')),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: emailController,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: context.strings('email'),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (value) => value != null && value.trim().contains('@')
                ? null
                : context.strings('enterValidEmail'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            enabled: !busy,
            obscureText: hidePassword,
            autofillHints: createAccount
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: context.strings('password'),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => value != null && value.length >= 8
                ? null
                : context.strings('passwordRequirement'),
          ),
          if (createAccount) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmPasswordController,
              enabled: !busy,
              obscureText: hidePassword,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: context.strings('confirmPassword'),
                prefixIcon: const Icon(Icons.lock_reset_rounded),
              ),
              validator: (value) => value == passwordController.text
                  ? null
                  : context.strings('passwordsDoNotMatch'),
            ),
          ],
          if (!createAccount)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy ? null : onResetPassword,
                child: Text(context.strings('forgotPassword')),
              ),
            )
          else
            const SizedBox(height: 18),
          FilledButton(
            onPressed: busy ? null : onSubmit,
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.strings(createAccount ? 'signUp' : 'signIn')),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: busy ? null : onToggleMode,
            child: Text(
              context.strings(
                createAccount ? 'alreadyHaveAccount' : 'needAccount',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AccountDetails extends ConsumerWidget {
  const _AccountDetails({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
    children: [
      CircleAvatar(
        radius: 36,
        child: Text(
          (user.displayName ?? user.email ?? 'A').characters.first
              .toUpperCase(),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        user.displayName ?? user.email ?? context.strings('account'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (user.email != null) ...[
        const SizedBox(height: 4),
        Text(user.email!, textAlign: TextAlign.center),
      ],
      const SizedBox(height: 28),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_done_outlined),
              title: Text(context.strings('syncActive')),
              subtitle: Text(context.strings('syncActiveBody')),
            ),
            if (user.email != null && !user.emailVerified)
              ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined),
                title: Text(context.strings('emailNotVerified')),
                trailing: TextButton(
                  onPressed: () => _resendVerification(context, ref),
                  child: Text(context.strings('resend')),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () => _signOut(context, ref),
        icon: const Icon(Icons.logout_rounded),
        label: Text(context.strings('signOut')),
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: () => _deleteAccount(context, ref),
        icon: Icon(
          Icons.delete_forever_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        label: Text(
          context.strings('deleteAccount'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ],
  );

  Future<void> _resendVerification(BuildContext context, WidgetRef ref) async {
    await ref.read(accountServiceProvider).resendVerification();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings('verificationSent'))),
      );
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: context.strings('signOut'),
      body: context.strings('signOutConfirm'),
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(appControllerProvider.notifier).clearLocalForAccountSwitch();
    await ref.read(accountServiceProvider).signOutToAnonymous();
    ref.invalidate(appControllerProvider);
    ref.invalidate(grammarProgressProvider);
    if (context.mounted) context.pop();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: context.strings('deleteAccount'),
      body: context.strings('deleteAccountConfirm'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(accountServiceProvider).deleteAccount();
      await ref
          .read(appControllerProvider.notifier)
          .clearLocalForAccountSwitch();
      ref.invalidate(appControllerProvider);
      ref.invalidate(grammarProgressProvider);
      if (context.mounted) context.pop();
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? context.strings('accountError')),
        ),
      );
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.strings('cancel')),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(title),
            ),
          ],
        ),
      ) ??
      false;
}
