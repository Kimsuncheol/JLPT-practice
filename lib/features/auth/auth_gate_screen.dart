import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/account_service.dart';
import 'package:jlpt_practice/core/services/notification_service.dart';
import 'package:jlpt_practice/features/auth/auth_form.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_providers.dart';

/// The mandatory sign-in gate shown before onboarding/home whenever there is
/// no signed-in user. Guest/anonymous use is not supported.
class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
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
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AuthForm(
        title: context.strings(
          _createAccount ? 'createAccountTitle' : 'welcomeSignInTitle',
        ),
        body: context.strings('welcomeSignInBody'),
        formKey: _formKey,
        emailController: _emailController,
        passwordController: _passwordController,
        confirmPasswordController: _confirmPasswordController,
        createAccount: _createAccount,
        busy: _busy,
        hidePassword: _hidePassword,
        onTogglePassword: () => setState(() => _hidePassword = !_hidePassword),
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
    final onboardingComplete =
        ref.read(appControllerProvider).value?.onboardingComplete ?? false;
    final initialRoute = NotificationService.instance.takeInitialRoute();
    context.go(onboardingComplete ? initialRoute ?? '/home' : '/onboarding');
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
