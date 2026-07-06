import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/connectivity_service.dart';

class _FakeConnectivity implements Connectivity {
  List<ConnectivityResult> result;
  _FakeConnectivity(this.result);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => result;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

void main() {
  group('ConnectivityService.isOnline', () {
    test('offline when no interface, without probing', () async {
      var probed = false;
      final svc = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.none]),
        reachabilityProbe: () async {
          probed = true;
          return true;
        },
      );
      addTearDown(svc.dispose);

      expect(await svc.isOnline(), isFalse);
      expect(probed, isFalse,
          reason: 'no point probing when the interface is down');
    });

    test(
        'interface up but server unreachable reads as offline '
        '(captive portal)', () async {
      final svc = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        reachabilityProbe: () async => false,
      );
      addTearDown(svc.dispose);

      expect(await svc.isOnline(), isFalse);
    });

    test('interface up and server reachable reads as online', () async {
      final svc = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        reachabilityProbe: () async => true,
      );
      addTearDown(svc.dispose);

      expect(await svc.isOnline(), isTrue);
    });

    test('probe result is cached within the TTL (one ping for rapid callers)',
        () async {
      var probeCount = 0;
      final svc = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        reachabilityProbe: () async {
          probeCount++;
          return true;
        },
        cacheTtl: const Duration(seconds: 60),
      );
      addTearDown(svc.dispose);

      await svc.isOnline();
      await svc.isOnline();
      await svc.isOnline();
      expect(probeCount, 1);

      await svc.isOnline(forceProbe: true);
      expect(probeCount, 2);
    });
  });
}
