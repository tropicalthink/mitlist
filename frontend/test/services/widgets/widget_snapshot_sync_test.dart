import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/widgets/widget_snapshot_sync.dart';

import 'fake_widget_bridge.dart';

class _SnapshotAdapter implements HttpClientAdapter {
  _SnapshotAdapter(this.body);
  final String body;
  var calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    expect(options.path, '/widget/snapshot');
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('writes the server snapshot verbatim and publishes its defaults',
      () async {
    final golden =
        File('../contracts/widgets/snapshot_v1.json').readAsStringSync();
    final bridge = FakeWidgetBridge();
    final adapter = _SnapshotAdapter(golden);
    final sync = WidgetSnapshotSync(
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
        ..httpClientAdapter = adapter,
      bridge: bridge,
    );
    final defaults = sync.defaults.first;

    await sync.refreshNow();

    expect(bridge.snapshots.single, golden);
    final d = await defaults;
    expect(d.householdId, '11111111-1111-4111-8111-111111111111');
    expect(d.listId, '22222222-2222-4222-8222-222222222222');
    sync.dispose();
  });

  test('never writes something that is not a snapshot', () async {
    final bridge = FakeWidgetBridge();
    final sync = WidgetSnapshotSync(
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
        ..httpClientAdapter = _SnapshotAdapter('{"error":"maintenance"}'),
      bridge: bridge,
    );
    await sync.refreshNow();
    expect(bridge.snapshots, isEmpty);
    sync.dispose();
  });

  test('coalesces a burst of changes into one fetch', () async {
    final bridge = FakeWidgetBridge();
    final adapter = _SnapshotAdapter(
        File('../contracts/widgets/snapshot_v1.json').readAsStringSync());
    final sync = WidgetSnapshotSync(
      dio: Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
        ..httpClientAdapter = adapter,
      bridge: bridge,
      debounce: const Duration(milliseconds: 20),
    );
    for (var i = 0; i < 5; i++) {
      sync.schedule();
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(adapter.calls, 1);
    sync.dispose();
  });
}
