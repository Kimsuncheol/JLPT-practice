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
  String get filename => '$id.gguf';

  // Immutable Hugging Face revisions and LFS SHA-256 values, verified 2026-09-17.
  // Memory limits are conservative eligibility heuristics, not guarantees.
  static const catalog = [
    OfflineAiModel(
      id: 'llama32-1b-q4km-v1',
      name: 'Llama 3.2 1B Instruct',
      url:
          'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/067b946cf014b7c697f3654f621d577a3e3afd1c/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      bytes: 807694464,
      sha256:
          '6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83',
      minimumRam: 3758096384,
      loadBudget: 1610612736,
    ),
    OfflineAiModel(
      id: 'llama32-3b-q4km-v1',
      name: 'Llama 3.2 3B Instruct',
      url:
          'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/5ab33fa94d1d04e903623ae72c95d1696f09f9e8/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      bytes: 2019377696,
      sha256:
          '6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff',
      minimumRam: 5905580032,
      loadBudget: 3221225472,
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
