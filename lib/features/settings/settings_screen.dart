import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/account_service.dart';
import 'package:jlpt_practice/shared/session_actions.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return SafeArea(
      child: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final controller = ref.read(appControllerProvider.notifier);
          final strings = context.strings;
          final user = ref.watch(firebaseUserProvider).value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              Text(
                strings('settings'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 18),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: Icon(
                      user != null
                          ? Icons.cloud_done_outlined
                          : Icons.person_add_alt_1_outlined,
                    ),
                    title: Text(strings('account')),
                    subtitle: Text(
                      user != null
                          ? user.email ?? strings('syncActive')
                          : strings('protectProgress'),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/account'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.translate_rounded),
                    title: Text(strings('languages')),
                    subtitle: Text(switch (state.languageCode) {
                      'en' => 'English',
                      'ko' => '한국어',
                      _ => strings('system'),
                    }),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/languages'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.school_rounded),
                    title: Text(strings('levels')),
                    subtitle: Text(state.selectedLevel),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/levels'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsGroup(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.subtitles_rounded),
                    title: Text(strings('showFurigana')),
                    value: state.showFurigana,
                    onChanged: controller.setShowFurigana,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up_rounded),
                    title: Text(strings('autoAudio')),
                    value: state.autoPlayAudio,
                    onChanged: controller.setAutoPlayAudio,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(strings('notifications')),
                    subtitle: Text(
                      TimeOfDay(
                        hour: state.reminderHour,
                        minute: state.reminderMinute,
                      ).format(context),
                    ),
                    value: state.notificationsEnabled,
                    onChanged: (value) async {
                      final enabled = await controller.setNotifications(value);
                      if (context.mounted && value && !enabled) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              strings('notificationPermissionDenied'),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    enabled: state.notificationsEnabled,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(strings('reminderTime')),
                    trailing: Text(
                      TimeOfDay(
                        hour: state.reminderHour,
                        minute: state.reminderMinute,
                      ).format(context),
                    ),
                    onTap: state.notificationsEnabled
                        ? () async {
                            final selected = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: state.reminderHour,
                                minute: state.reminderMinute,
                              ),
                            );
                            if (selected != null) {
                              await controller.setReminderTime(selected);
                            }
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: const Icon(Icons.brightness_6_rounded),
                    title: Text(strings('appearance')),
                    subtitle: Text(strings(state.themeMode.name)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings/appearance'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SettingsGroup(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(strings('privacy')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      if (AdService.enabled) {
                        AdService.showPrivacyOptions();
                      } else {
                        _showInfo(
                          context,
                          strings('privacy'),
                          strings('privacyBody'),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.source_outlined),
                    title: Text(strings('attribution')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _showInfo(
                      context,
                      strings('attribution'),
                      strings('attributionBody'),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      strings('resetProgress'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    onTap: () => _confirmReset(context, ref),
                  ),
                ],
              ),
              if (user != null) ...[
                const SizedBox(height: 14),
                _SettingsGroup(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: Text(strings('signOut')),
                      onTap: () => confirmAndSignOut(context, ref),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              Text(
                user != null
                    ? strings('syncActiveBody')
                    : strings('anonymousBody'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showInfo(BuildContext context, String title, String body) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings('resetProgress')),
        content: Text(context.strings('resetConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.strings('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.strings('reset')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appControllerProvider.notifier).resetLearningProgress();
    }
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
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
