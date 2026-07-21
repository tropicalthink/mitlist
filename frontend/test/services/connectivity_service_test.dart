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
        cacheTtl: Duration.zero,
      );
      addTearDown(svc.dispose);

      await svc.isOnline();
      expect(await svc.isOnline(), isFalse);
    });

    test('a single probe failure does not flip to offline', () async {
      final svc = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        reachabilityProbe: () async => false,
        cacheTtl: Duration.zero,
      );
      addTearDown(svc.dispose);

      expect(await svc.isOnline(), isTrue,
          reason: 'one failed probe is soft evidence — a cold radio or a '
              'backgrounded app fails it just as readily as a dead uplink');
    });

    test('one success clears a pending failure streak', () async {
      var reachable = false;
      final svc = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        reachabilityProbe: () async => reachable,
        cacheTtl: Duration.zero,
      );
      addTearDown(svc.dispose);

      await svc.isOnline(); // failure 1 of 2
      reachable = true;
      expect(await svc.isOnline(), isTrue);

      // Streak was cleared, so the next failure starts counting from zero.
      reachable = false;
      expect(await svc.isOnline(), isTrue);
    });

    test('reset() clears a verdict reached while backgrounded', () async {
      var reachable = false;
      final svc = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.wifi]),
        reachabilityProbe: () async => reachable,
        cacheTtl: const Duration(seconds: 60),
        failureThreshold: 1,
      );
      addTearDown(svc.dispose);

      expect(await svc.isOnline(), isFalse);

      // The network is fine again. This is the resume case: without reset()
      // the cached false is replayed for the rest of the TTL, which is what
      // painted a stale offline bar over a working app.
      reachable = true;
      svc.reset();
      expect(await svc.isOnline(), isTrue);
    });

    test('no interface reads as offline immediately, without damping',
        () async {
      final svc = ConnectivityService(
        connectivity: _FakeConnectivity([ConnectivityResult.none]),
        reachabilityProbe: () async => true,
      );
      addTearDown(svc.dispose);

      expect(await svc.isOnline(), isFalse,
          reason: 'interface state is hard evidence from the OS — airplane '
              'mode should show the banner on the first observation');
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
