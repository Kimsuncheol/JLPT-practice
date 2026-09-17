import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_controller.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

class OfflineAiScreen extends ConsumerWidget {
  const OfflineAiScreen({super.key});

  String _size(int bytes) => '${(bytes / 1000000000).toStringAsFixed(2)} GB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(offlineAiProvider);
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings('offlineAi'))),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final capacity = controller.capacity;
          final selected = controller.selected;
          final installed = controller.installed.contains(selected.id);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Icon(
                Icons.offline_bolt_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                strings('offlineIntro'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(strings('offlinePrivacy')),
              const SizedBox(height: 20),
              if (capacity != null) ...[
                Text(
                  '${strings('offlineRam')}: ${_size(capacity.totalRam)} · '
                  '${strings('offlineStorage')}: ${_size(capacity.freeStorage)}',
                ),
                const SizedBox(height: 12),
              ],
              for (final model in OfflineAiModel.catalog)
                Card(
                  child: ListTile(
                    enabled:
                        !controller.busy &&
                        capacity != null &&
                        capacity.supports(model),
                    leading: Icon(
                      model.id == selected.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: Text(model.name),
                    subtitle: Text(
                      [
                        '${_size(model.bytes)} · Q4_K_M',
                        strings(
                          model == OfflineAiModel.catalog.first
                              ? 'offlineSmallModel'
                              : 'offlineLargeModel',
                        ),
                        if (controller.installed.contains(model.id))
                          strings('offlineInstalled'),
                        if ((controller.partialBytes[model.id] ?? 0) > 0)
                          '${strings('offlinePartial')}: ${_size(controller.partialBytes[model.id]!)}',
                        if (capacity != null && !capacity.supports(model))
                          strings('offlineUnsupported'),
                      ].join('\n'),
                    ),
                    onTap: () => controller.select(model),
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(strings('offlineWifiOnly')),
                value: controller.wifiOnly,
                onChanged: controller.phase == OfflineAiPhase.checking
                    ? null
                    : controller.setWifiOnly,
              ),
              Text(
                strings('offlineQualityNote'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (controller.busy) ...[
                LinearProgressIndicator(
                  value: controller.phase == OfflineAiPhase.downloading
                      ? (controller.received / selected.bytes).clamp(0, 1)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  strings(switch (controller.phase) {
                    OfflineAiPhase.downloading => 'offlineDownloading',
                    OfflineAiPhase.verifying => 'offlineVerifying',
                    OfflineAiPhase.loading => 'offlineLoading',
                    OfflineAiPhase.generating => 'offlineEvaluating',
                    _ => 'offlineChecking',
                  }),
                ),
                if (controller.phase == OfflineAiPhase.downloading) ...[
                  Text(
                    '${_size(controller.received)} / ${_size(selected.bytes)}',
                  ),
                  TextButton(
                    onPressed: controller.pause,
                    child: Text(strings('offlinePause')),
                  ),
                ],
              ],
              if (controller.errorKey case final key?) ...[
                const SizedBox(height: 12),
                Text(
                  strings(key),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed:
                    controller.busy ||
                        capacity == null ||
                        !capacity.supports(selected)
                    ? null
                    : () async {
                        if (installed) {
                          await controller.prepare();
                        } else {
                          await controller.download();
                        }
                      },
                icon: Icon(
                  installed ? Icons.play_arrow_rounded : Icons.download_rounded,
                ),
                label: Text(
                  strings(
                    installed
                        ? 'offlineTestModel'
                        : (controller.partialBytes[selected.id] ?? 0) > 0
                        ? 'offlineResumeDownload'
                        : 'offlineDownload',
                  ),
                ),
              ),
              if (controller.ready) ...[
                const SizedBox(height: 8),
                Text(strings('offlineReady')),
              ],
              if (installed || (controller.partialBytes[selected.id] ?? 0) > 0)
                TextButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => _delete(context, controller, selected),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(strings('offlineDelete')),
                ),
              TextButton(
                onPressed: () async {
                  final license = await rootBundle.loadString(
                    'assets/offline_ai/LLAMA_LICENSE.txt',
                  );
                  final notice = await rootBundle.loadString(
                    'assets/offline_ai/NOTICE.txt',
                  );
                  if (!context.mounted) return;
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Built with Llama'),
                      content: SingleChildScrollView(
                        child: SelectableText('$notice\n\n$license'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(strings('ok')),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(strings('offlineLicense')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    OfflineAiController controller,
    OfflineAiModel model,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings('offlineDelete')),
        content: Text(context.strings('offlineDeleteBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings('offlineDelete')),
          ),
        ],
      ),
    );
    if (accepted == true) await controller.remove(model);
  }
}
