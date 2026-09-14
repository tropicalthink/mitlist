import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/connectivity_service.dart';

class _FakeConnectivity implements Connectivity {
  List<ConnectivityResult> result;
  final changes = StreamController<List<ConnectivityResult>>.broadcast();

  _FakeConnectivity(this.result);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => result;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;

  Future<void> close() => changes.close();
}

void main() {
  // The API client reads this synchronously before every GET, so it has to
  // reflect an interface loss immediately (the OS event is hard evidence) and
  // must never claim offline before any evidence exists.
  group('ConnectivityService.isKnownOffline', () {
    test('is false before any verdict', () {
      final svc = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        reachabilityProbe: () async => true,
      );
      addTearDown(svc.dispose);
      expect(svc.isKnownOffline, isFalse);
    });

    test('flips on an interface loss event without a probe', () async {
      final fake = _FakeConnectivity([ConnectivityResult.wifi]);
      addTearDown(fake.close);
      var probes = 0;
      final svc = ConnectivityService(
        connectivity: fake,
        reachabilityProbe: () async {
          probes++;
          return true;
        },
      );
      addTearDown(svc.dispose);

      fake.result = [ConnectivityResult.none];
      fake.changes.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);

      expect(svc.isKnownOffline, isTrue);
      expect(probes, 0);
    });

    test('clears again once a probe succeeds', () async {
      final fake = _FakeConnectivity([ConnectivityResult.none]);
      final svc = ConnectivityService(
        connectivity: fake,
        reachabilityProbe: () async => true,
        cacheTtl: Duration.zero,
      );
      addTearDown(svc.dispose);

      expect(await svc.isOnline(), isFalse);
      expect(svc.isKnownOffline, isTrue);

      fake.result = [ConnectivityResult.wifi];
      expect(await svc.isOnline(), isTrue);
      expect(svc.isKnownOffline, isFalse);
    });

    test('needs the failure threshold before probes alone flip it', () async {
      final fake = _FakeConnectivity([ConnectivityResult.wifi]);
      final svc = ConnectivityService(
        connectivity: fake,
        reachabilityProbe: () async => false,
        cacheTtl: Duration.zero,
        failureThreshold: 2,
      );
      addTearDown(svc.dispose);

      await svc.isOnline();
      expect(svc.isKnownOffline, isFalse, reason: 'one soft failure');
      await svc.isOnline();
      expect(svc.isKnownOffline, isTrue);
    });
  });
}
