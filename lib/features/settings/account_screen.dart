import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/account_service.dart';
import 'package:jlpt_practice/shared/session_actions.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('account'))),
      body: SafeArea(
        child: user != null
            ? _AccountDetails(user: user)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AccountDetails extends ConsumerWidget {
  const _AccountDetails({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = accountDisplayLabel(
      displayName: user.displayName,
      email: user.email,
      fallback: context.strings('account'),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        CircleAvatar(
          radius: 36,
          child: Text(
            accountAvatarInitial(
              displayName: user.displayName,
              email: user.email,
            ),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
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
          onPressed: () => confirmAndSignOut(context, ref),
          icon: const Icon(Icons.logout_rounded),
          label: Text(context.strings('signOut')),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => confirmAndDeleteAccount(context, ref),
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
  }

  Future<void> _resendVerification(BuildContext context, WidgetRef ref) async {
    await ref.read(accountServiceProvider).resendVerification();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings('verificationSent'))),
      );
    }
  }
}

String accountDisplayLabel({
  required String? displayName,
  required String? email,
  required String fallback,
}) {
  final normalizedName = displayName?.trim() ?? '';
  if (normalizedName.isNotEmpty) return normalizedName;
  final normalizedEmail = email?.trim() ?? '';
  if (normalizedEmail.isNotEmpty) return normalizedEmail;
  return fallback;
}

String accountAvatarInitial({String? displayName, String? email}) {
  final label = accountDisplayLabel(
    displayName: displayName,
    email: email,
    fallback: 'A',
  );
  return label.characters.isEmpty ? 'A' : label.characters.first.toUpperCase();
}
