import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class AuthForm extends StatelessWidget {
  const AuthForm({
    super.key,
    required this.title,
    required this.body,
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

  final String title;
  final String body;
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

  bool doPasswordMatches(String? value) => value == passwordController.text;

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
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
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
            validator: (value) => createAccount
                ? (value != null &&
                          passwordConstraints(
                            context,
                          ).every((constraint) => constraint.isSatisfied(value))
                      ? null
                      : context.strings('passwordRequirement'))
                : (value != null && value.length >= 8
                      ? null
                      : context.strings('passwordRequirement')),
          ),
          if (createAccount) ...[
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: passwordController,
              builder: (context, _) => PasswordConstraintsChecklist(
                password: passwordController.text,
              ),
            ),
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
              validator: (value) => doPasswordMatches(value)
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
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(context.strings('orContinueWith')),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: busy ? null : onGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: Text(
              context.strings(
                createAccount ? 'signUpWithGoogle' : 'signInWithGoogle',
              ),
            ),
          ),
          if (onApple != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : onApple,
              icon: const Icon(Icons.apple_rounded),
              label: Text(context.strings('continueWithApple')),
            ),
          ],
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

typedef PasswordConstraint = ({
  bool Function(String value) isSatisfied,
  String label,
});

List<PasswordConstraint> passwordConstraints(BuildContext context) => [
  (
    isSatisfied: (value) => value.length >= 8,
    label: context.strings('passwordConstraintLength'),
  ),
  (
    isSatisfied: (value) => value.contains(RegExp('[A-Z]')),
    label: context.strings('passwordConstraintUppercase'),
  ),
  (
    isSatisfied: (value) => value.contains(RegExp('[a-z]')),
    label: context.strings('passwordConstraintLowercase'),
  ),
  (
    isSatisfied: (value) => value.contains(RegExp('[0-9]')),
    label: context.strings('passwordConstraintNumber'),
  ),
];

class PasswordConstraintsChecklist extends StatelessWidget {
  const PasswordConstraintsChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final constraint in passwordConstraints(context))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  constraint.isSatisfied(password)
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 16,
                  color: constraint.isSatisfied(password)
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  constraint.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: constraint.isSatisfied(password)
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
