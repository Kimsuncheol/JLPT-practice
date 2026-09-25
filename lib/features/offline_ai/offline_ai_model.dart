const gib = 1024 * 1024 * 1024;

class OfflineAiModel {
  const OfflineAiModel({
    required this.id,
    required this.name,
    required this.url,
    required this.bytes,
    required this.sha256,
    required this.minimumRam,
    required this.loadBudget,
  });

  final String id;
  final String name;
  final String url;
  final int bytes;
  final String sha256;
  final int minimumRam;
  final int loadBudget;
  String get filename => '$id.litertlm';

  // Immutable Hugging Face revisions and LFS SHA-256 values, verified 2026-09-24.
  // Memory limits are eligibility heuristics, not guarantees.
  static const catalog = [
    OfflineAiModel(
      id: 'gemma4-e2b-litertlm-v1',
      name: 'Gemma 4 E2B Instruct',
      url:
          'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1/gemma-4-E2B-it.litertlm',
      bytes: 2588147712,
      sha256:
          '181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c',
      minimumRam: 4 * gib,
      loadBudget: 2 * gib,
    ),
    OfflineAiModel(
      id: 'gemma4-e4b-litertlm-v1',
      name: 'Gemma 4 E4B Instruct',
      url:
          'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/2eee7ac325f20eb8c9ac1d0e972f7c84663062da/gemma-4-E4B-it.litertlm',
      bytes: 3659530240,
      sha256:
          '0b2a8980ce155fd97673d8e820b4d29d9c7d99b8fa6806f425d969b145bd52e0',
      minimumRam: 6 * gib,
      loadBudget: 3 * gib,
    ),
  ];
}

class OfflineAiException implements Exception {
  const OfflineAiException(this.key);
  final String key;
  @override
  String toString() => key;
}

class DeviceAiCapacity {
  const DeviceAiCapacity({
    required this.totalRam,
    required this.availableRam,
    required this.freeStorage,
    required this.is64Bit,
    required this.hot,
    required this.directory,
  });
  final int totalRam;

  /// Android: available system memory minus the OS low-memory threshold.
  /// iOS: os_proc_available_memory, the current process's additional allowance.
  final int availableRam;
  final int freeStorage;
  final bool is64Bit;
  final bool hot;
  final String directory;

  bool supports(OfflineAiModel model) =>
      is64Bit && totalRam >= model.minimumRam;
  void checkLoad(OfflineAiModel model) {
    if (!supports(model)) throw const OfflineAiException('offlineUnsupported');
    if (hot) throw const OfflineAiException('offlineTooHot');
    if (availableRam < model.loadBudget) {
      throw const OfflineAiException('offlineLowMemory');
    }
  }
}
