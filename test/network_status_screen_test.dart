import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/network_status_service.dart';
import 'package:jlpt_practice/shared/network_status_screen.dart';

void main() {
  testWidgets(
    'shows the disconnected screen and restores the app on reconnect',
    (tester) async {
      final source = _FakeNetworkStatusSource(
        NetworkConnectionStatus.disconnected,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NetworkStatusGate(
            source: source,
            child: const Text('App content'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No internet connection'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('App content'), findsNothing);

      source.emit(NetworkConnectionStatus.connected);
      await tester.pump();

      expect(find.text('No internet connection'), findsNothing);
      expect(find.text('App content'), findsOneWidget);

      await source.close();
    },
  );

  testWidgets('retry checks the latest connection state', (tester) async {
    final source = _FakeNetworkStatusSource(
      NetworkConnectionStatus.disconnected,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NetworkStatusGate(
          source: source,
          child: const Text('App content'),
        ),
      ),
    );
    await tester.pump();

    source.current = NetworkConnectionStatus.connected;
    await tester.tap(find.byKey(const Key('network-retry-button')));
    await tester.pump();

    expect(find.text('App content'), findsOneWidget);

    await source.close();
  });
}

class _FakeNetworkStatusSource implements NetworkStatusSource {
  _FakeNetworkStatusSource(this.current);

  NetworkConnectionStatus current;
  final _controller = StreamController<NetworkConnectionStatus>.broadcast();

  @override
  Future<NetworkConnectionStatus> check() async => current;

  @override
  Stream<NetworkConnectionStatus> get changes => _controller.stream;

  void emit(NetworkConnectionStatus status) {
    current = status;
    _controller.add(status);
  }

  Future<void> close() => _controller.close();
}
