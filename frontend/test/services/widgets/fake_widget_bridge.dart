import 'package:mitlist/services/widgets/widget_bridge.dart';

/// In-memory stand-in for the native side of the `me.mitlist/widgets`
/// channel.
class FakeWidgetBridge extends WidgetBridge {
  FakeWidgetBridge({List<String>? queue}) : super(isSupported: true) {
    if (queue != null) this.queue.addAll(queue);
  }

  final List<String> queue = [];
  final List<List<String>> acks = [];
  final List<String> snapshots = [];
  Map<String, Object?>? credential;
  bool authFailed = false;
  bool cleared = false;
  int refreshRequests = 0;

  @override
  Future<List<String>> readPendingOps() async => List.of(queue);

  @override
  Future<void> ackPendingOps(List<String> opIds) async {
    acks.add(List.of(opIds));
    queue.removeWhere((line) => opIds.any((id) => line.contains('"$id"')));
  }

  @override
  Future<void> setCredential(Map<String, Object?> credential) async =>
      this.credential = credential;

  @override
  Future<bool> hasCredential() async => credential != null;

  @override
  Future<bool> consumeAuthFailure() async {
    final failed = authFailed;
    authFailed = false;
    return failed;
  }

  @override
  Future<void> writeSnapshot(String json) async => snapshots.add(json);

  @override
  Future<void> clearAll() async {
    cleared = true;
    credential = null;
    queue.clear();
  }

  @override
  Future<void> requestRefresh() async => refreshRequests++;
}
