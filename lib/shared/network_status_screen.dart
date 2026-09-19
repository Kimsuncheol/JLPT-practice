import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/network_status_service.dart';

class NetworkStatusGate extends StatefulWidget {
  const NetworkStatusGate({required this.child, this.source, super.key});

  final Widget child;
  final NetworkStatusSource? source;

  @override
  State<NetworkStatusGate> createState() => _NetworkStatusGateState();
}

class _NetworkStatusGateState extends State<NetworkStatusGate> {
  late NetworkStatusSource _source;
  StreamSubscription<NetworkConnectionStatus>? _subscription;
  NetworkConnectionStatus? _status;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void didUpdateWidget(NetworkStatusGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _subscription?.cancel();
      _status = null;
      _startListening();
    }
  }

  void _startListening() {
    _source = widget.source ?? ConnectivityNetworkStatusSource();
    _subscription = _source.changes.listen(_updateStatus, onError: (_) {});
    unawaited(_refreshStatus());
  }

  Future<void> _refreshStatus() async {
    try {
      _updateStatus(await _source.check());
    } catch (_) {
      // Keep the last known state if the platform cannot perform a check.
    }
  }

  void _updateStatus(NetworkConnectionStatus status) {
    if (!mounted || status == _status) return;
    setState(() => _status = status);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == NetworkConnectionStatus.disconnected) {
      return NetworkDisconnectedScreen(onRetry: _refreshStatus);
    }
    return widget.child;
  }
}

class NetworkDisconnectedScreen extends StatelessWidget {
  const NetworkDisconnectedScreen({required this.onRetry, super.key});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: AppTheme.mint.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: AppTheme.mint,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  context.strings('networkDisconnectedTitle'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.strings('networkDisconnectedBody'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  key: const Key('network-retry-button'),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.strings('networkRetry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
