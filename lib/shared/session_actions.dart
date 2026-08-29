import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/account_service.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_providers.dart';

/// Confirms with the user, then signs out and returns to the mandatory
/// sign-in gate. Shared by Settings, the account screen, and the profile
/// screen so the flow stays identical everywhere it's triggered.
Future<void> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await _confirm(
    context,
    title: context.strings('signOut'),
    body: context.strings('signOutConfirm'),
  );
  if (!confirmed || !context.mounted) return;
  await ref.read(appControllerProvider.notifier).clearLocalForAccountSwitch();
  await ref.read(accountServiceProvider).signOut();
  ref.invalidate(appControllerProvider);
  ref.invalidate(grammarProgressProvider);
  if (context.mounted) context.go('/sign-in');
}

/// Confirms with the user, then permanently deletes the account and returns
/// to the sign-in gate. [confirmTitle] lets a caller match the dialog title
/// to whatever the triggering button was labeled (e.g. "Opt out").
Future<void> confirmAndDeleteAccount(
  BuildContext context,
  WidgetRef ref, {
  String? confirmTitle,
}) async {
  final confirmed = await _confirm(
    context,
    title: confirmTitle ?? context.strings('deleteAccount'),
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
    if (context.mounted) context.go('/sign-in');
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
