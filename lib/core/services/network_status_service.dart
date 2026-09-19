import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkConnectionStatus { connected, disconnected }

abstract interface class NetworkStatusSource {
  Future<NetworkConnectionStatus> check();

  Stream<NetworkConnectionStatus> get changes;
}

class ConnectivityNetworkStatusSource implements NetworkStatusSource {
  ConnectivityNetworkStatusSource({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<NetworkConnectionStatus> check() async {
    return _statusFromResults(await _connectivity.checkConnectivity());
  }

  @override
  Stream<NetworkConnectionStatus> get changes =>
      _connectivity.onConnectivityChanged.map(_statusFromResults).distinct();

  static NetworkConnectionStatus _statusFromResults(
    List<ConnectivityResult> results,
  ) {
    return results.any((result) => result != ConnectivityResult.none)
        ? NetworkConnectionStatus.connected
        : NetworkConnectionStatus.disconnected;
  }
}
