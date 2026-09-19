import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/account_service.dart';
import 'package:jlpt_practice/shared/session_actions.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseUserProvider).value;
    final selectedLevel = ref.watch(appControllerProvider).value?.selectedLevel;
    final strings = context.strings;

    if (user == null) {
      // Sign-in is mandatory before this tab is reachable at all, so this
      // only shows for an instant mid sign-out; nothing worth animating.
      return const SizedBox.shrink();
    }

    final label = accountDisplayLabel(
      displayName: user.displayName,
      email: user.email,
      fallback: strings('account'),
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Text(
            strings('profile'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 22),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Text(
                      accountAvatarInitial(
                        displayName: user.displayName,
                        email: user.email,
                      ),
                      style: Theme.of(context).textTheme.headlineMedium,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (user.email != null) ...[
            const SizedBox(height: 4),
            Text(
              user.email!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          _ProfileGroup(
            children: [
              ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(strings('authMethod')),
                trailing: Text(_authMethodLabel(context, user)),
              ),
              ListTile(
                leading: const Icon(Icons.school_rounded),
                title: Text(strings('levels')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(selectedLevel ?? '—'),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                onTap: () => context.push('/settings/levels'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => confirmAndSignOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: Text(strings('signOut')),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => confirmAndDeleteAccount(
              context,
              ref,
              confirmTitle: strings('optOut'),
            ),
            icon: Icon(
              Icons.person_remove_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              strings('optOut'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  String _authMethodLabel(BuildContext context, User user) {
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : null;
    return switch (providerId) {
      'google.com' => 'Google',
      'apple.com' => 'Apple',
      _ => context.strings('email'),
    };
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

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(
              height: 1,
              indent: 56,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
        ],
      ],
    ),
  );
}
