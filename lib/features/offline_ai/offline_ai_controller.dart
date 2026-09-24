import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jlpt_practice/features/offline_ai/device_ai_capacity.dart';
import 'package:jlpt_practice/features/offline_ai/local_inference.dart';
import 'package:jlpt_practice/features/offline_ai/model_download.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_model.dart';

final offlineAiProvider = Provider<OfflineAiController>((ref) {
  final controller = OfflineAiController();
  ref.onDispose(controller.dispose);
  return controller;
});

enum OfflineAiPhase {
  checking,
  idle,
  downloading,
  verifying,
  loading,
  ready,
  generating,
}

class OfflineAiController extends ChangeNotifier with WidgetsBindingObserver {
  OfflineAiController({
    DeviceAiProbe? probe,
    LocalInference? engine,
    ModelDownload? downloader,
    this.models = OfflineAiModel.catalog,
  }) : probe = probe ?? DeviceAiProbe(),
       engine = engine ?? GemmaLocalInference(),
       downloader = downloader ?? ModelDownload() {
    selected = models.first;
    WidgetsBinding.instance.addObserver(this);
    DeviceAiProbe.channel.setMethodCallHandler((call) async {
      if (call.method == 'pressure') {
        interrupt(
          call.arguments == 'thermal' ? 'offlineTooHot' : 'offlineLowMemory',
        );
      }
    });
    _network = Connectivity().onConnectivityChanged.listen((connections) {
      if (wifiOnly &&
          phase == OfflineAiPhase.downloading &&
          !_unmetered(connections)) {
        pause('offlineWifiRequired');
      }
    });
    initialized = _initialize();
  }

  final DeviceAiProbe probe;
  final LocalInference engine;
  final ModelDownload downloader;
  final List<OfflineAiModel> models;
  late final Future<void> initialized;
  late SharedPreferences _preferences;
  StreamSubscription<List<ConnectivityResult>>? _network;
  DeviceAiCapacity? capacity;
  OfflineAiPhase phase = OfflineAiPhase.checking;
  String? errorKey;
  late OfflineAiModel selected;
  final Set<String> installed = {};
  final Map<String, int> partialBytes = {};
  bool wifiOnly = true;
  int received = 0;
  String? _loadedId;
  bool _disposed = false;
  int _epoch = 0;
  Future<void>? _release;

  bool get busy => switch (phase) {
    OfflineAiPhase.checking ||
    OfflineAiPhase.downloading ||
    OfflineAiPhase.verifying ||
    OfflineAiPhase.loading ||
    OfflineAiPhase.generating => true,
    _ => false,
  };
  bool get ready => _loadedId == selected.id && phase == OfflineAiPhase.ready;
  String modelPath(OfflineAiModel model) =>
      '${capacity!.directory}/${model.filename}';
  bool _unmetered(List<ConnectivityResult> values) =>
      values.contains(ConnectivityResult.wifi) ||
      values.contains(ConnectivityResult.ethernet);

  Future<void> _initialize() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      wifiOnly = _preferences.getBool('offlineAiWifiOnly') ?? true;
      capacity = await probe.read();
      final saved = _preferences.getString('offlineAiModel');
      selected =
          models.where((m) => m.id == saved).firstOrNull ??
          models.where((m) => capacity!.supports(m)).lastOrNull ??
          selected;
      await _scan();
    } on Object catch (error) {
      errorKey = error is OfflineAiException ? error.key : 'offlineUnsupported';
    }
    phase = OfflineAiPhase.idle;
    _notify();
  }

  Future<void> _scan() async {
    if (capacity == null) return;
    installed.clear();
    partialBytes.clear();
    for (final model in models) {
      final file = File(modelPath(model));
      if (await file.exists() && await file.length() == model.bytes) {
        installed.add(model.id);
      }
      final partial = File('${file.path}.part');
      if (await partial.exists()) {
        partialBytes[model.id] = await partial.length();
      }
    }
  }

  Future<void> select(OfflineAiModel model) async {
    if (busy) return;
    phase = OfflineAiPhase.checking;
    _notify();
    await _unload();
    selected = model;
    await _preferences.setString('offlineAiModel', model.id);
    errorKey = null;
    phase = OfflineAiPhase.idle;
    _notify();
  }

  Future<void> setWifiOnly(bool value) async {
    wifiOnly = value;
    await _preferences.setBool('offlineAiWifiOnly', value);
    if (value &&
        phase == OfflineAiPhase.downloading &&
        !_unmetered(await Connectivity().checkConnectivity())) {
      pause('offlineWifiRequired');
    }
    _notify();
  }

  Future<void> download() async {
    await initialized;
    if (busy) return;
    final epoch = ++_epoch;
    phase = OfflineAiPhase.checking;
    errorKey = null;
    _notify();
    try {
      await _unload();
      capacity = await probe.read();
      if (!capacity!.supports(selected)) {
        throw const OfflineAiException('offlineUnsupported');
      }
      if (wifiOnly && !_unmetered(await Connectivity().checkConnectivity())) {
        throw const OfflineAiException('offlineWifiRequired');
      }
      if (epoch != _epoch) throw const OfflineAiException('offlinePaused');
      phase = OfflineAiPhase.downloading;
      await downloader.download(
        selected,
        Directory(capacity!.directory),
        freeStorage: () async => (await probe.read()).freeStorage,
        onProgress: (bytes) {
          received = bytes;
          _notify();
        },
        onVerifying: () {
          phase = OfflineAiPhase.verifying;
          _notify();
        },
      );
      await _scan();
      if (epoch != _epoch) throw const OfflineAiException('offlinePaused');
      await _prepare(epoch);
    } on Object catch (error) {
      await _unload();
      errorKey ??= error is OfflineAiException
          ? error.key
          : 'offlineDownloadError';
      phase = OfflineAiPhase.idle;
    } finally {
      await _scan();
      _notify();
    }
  }

  Future<bool> prepare() async {
    await initialized;
    if (ready) return true;
    if (busy) return false;
    final epoch = ++_epoch;
    errorKey = null;
    phase = OfflineAiPhase.checking;
    _notify();
    try {
      await _prepare(epoch);
      return true;
    } on Object catch (error) {
      await _unload();
      errorKey ??= error is OfflineAiException
          ? error.key
          : 'offlineInferenceError';
      phase = OfflineAiPhase.idle;
      _notify();
      return false;
    }
  }

  Future<void> _prepare(int epoch) async {
    await _unload();
    capacity = await probe.read();
    capacity!.checkLoad(selected);
    if (!installed.contains(selected.id)) {
      throw const OfflineAiException('offlineSetupRequired');
    }
    phase = OfflineAiPhase.verifying;
    _notify();
    if (!await verifyModelFile(
      modelPath(selected),
      selected.bytes,
      selected.sha256,
    )) {
      installed.remove(selected.id);
      throw const OfflineAiException('offlineIntegrityError');
    }
    if (epoch != _epoch) throw const OfflineAiException('offlinePaused');
    capacity = await probe.read();
    capacity!.checkLoad(selected);
    phase = OfflineAiPhase.loading;
    _notify();
    await engine.load(modelPath(selected));
    // A load alone may not touch every memory-mapped page. Exercise one token.
    await engine.generate('Reply briefly.', 'Say OK.');
    if (epoch != _epoch) throw const OfflineAiException('offlinePaused');
    _loadedId = selected.id;
    phase = OfflineAiPhase.ready;
    _notify();
  }

  Future<String> generate(String system, String input) async {
    if (busy) throw const OfflineAiException('offlineBusy');
    if (!ready && !await prepare()) {
      throw OfflineAiException(errorKey ?? 'offlineSetupRequired');
    }
    final epoch = _epoch;
    phase = OfflineAiPhase.generating;
    _notify();
    try {
      capacity = await probe.read();
      if (capacity!.hot) throw const OfflineAiException('offlineTooHot');
      if (capacity!.availableRam < 256 * 1024 * 1024) {
        throw const OfflineAiException('offlineLowMemory');
      }
      final output = await engine.generate(system, input);
      if (epoch != _epoch) {
        throw OfflineAiException(errorKey ?? 'offlinePaused');
      }
      phase = OfflineAiPhase.ready;
      return output;
    } catch (_) {
      await _unload();
      phase = OfflineAiPhase.idle;
      rethrow;
    } finally {
      _notify();
    }
  }

  Stream<String> generateStream(String system, String input) async* {
    if (busy) throw const OfflineAiException('offlineBusy');
    if (!ready && !await prepare()) {
      throw OfflineAiException(errorKey ?? 'offlineSetupRequired');
    }
    final epoch = _epoch;
    phase = OfflineAiPhase.generating;
    _notify();
    try {
      capacity = await probe.read();
      if (capacity!.hot) throw const OfflineAiException('offlineTooHot');
      if (capacity!.availableRam < 256 * 1024 * 1024) {
        throw const OfflineAiException('offlineLowMemory');
      }
      await for (final chunk in engine.generateStream(system, input)) {
        if (epoch != _epoch) {
          throw OfflineAiException(errorKey ?? 'offlinePaused');
        }
        yield chunk;
      }
      if (epoch != _epoch) {
        throw OfflineAiException(errorKey ?? 'offlinePaused');
      }
      phase = OfflineAiPhase.ready;
    } catch (_) {
      await _unload();
      phase = OfflineAiPhase.idle;
      rethrow;
    } finally {
      _notify();
    }
  }

  void pause([String reason = 'offlinePaused']) {
    ++_epoch;
    errorKey = reason;
    downloader.cancel();
    _notify();
  }

  void interrupt(String reason) {
    pause(reason);
    unawaited(
      _unload().then((_) {
        if (!busy) phase = OfflineAiPhase.idle;
        _notify();
      }),
    );
  }

  Future<void> _unload() async {
    _loadedId = null;
    final pending = _release;
    if (pending != null) return pending;
    final release = engine.unload();
    _release = release;
    try {
      await release;
    } finally {
      _release = null;
    }
  }

  Future<void> remove(OfflineAiModel model) async {
    if (busy || capacity == null) return;
    phase = OfflineAiPhase.checking;
    _notify();
    try {
      await _unload();
      for (final suffix in ['', '.part']) {
        final file = File('${modelPath(model)}$suffix');
        if (await file.exists()) await file.delete();
      }
      await _scan();
      capacity = await probe.read();
      errorKey = null;
    } on Object {
      errorKey = 'offlineStorageError';
    }
    phase = OfflineAiPhase.idle;
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      interrupt('offlinePaused');
    }
  }

  @override
  void didHaveMemoryPressure() => interrupt('offlineLowMemory');

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    downloader.cancel();
    unawaited(_network?.cancel());
    unawaited(_unload());
    DeviceAiProbe.channel.setMethodCallHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
