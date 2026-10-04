import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/repositories/chore_repository.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/repositories/widget_ops_repository.dart';
import 'package:mitlist/services/widgets/home_widgets_controller.dart';
import 'package:mitlist/services/widgets/widget_credential_provisioner.dart';
import 'package:mitlist/services/widgets/widget_snapshot_sync.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';
import 'fake_widget_bridge.dart';

const _op =
    '{"op_id":"77777777-7777-4777-8777-777777777771","created_at":"2026-10-02T09:01:00Z","source":"ios_widget","type":"list_item.check","household_id":"11111111-1111-4111-8111-111111111111","list_id":"22222222-2222-4222-8222-222222222222","item_id":"33333333-3333-4333-8333-333333333331","method":"PATCH","path":"/lists/22222222-2222-4222-8222-222222222222/items/33333333-3333-4333-8333-333333333331","body":"{\\"checked\\":true}","state":"pending","attempts":0}';

/// Answers the credential request with 401 (a dead restored session) or
/// 201, and records the order of requests.
class _Adapter implements HttpClientAdapter {
  bool sessionAlive = true;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add('${options.method} ${options.path}');
    if (!sessionAlive) return ResponseBody.fromString('{}', 401);
    if (options.path == '/auth/widget-credential') {
      return ResponseBody.fromString(
          '{"token":"ml_int_t","expires_at":"2027-01-01T00:00:00Z"}', 201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          });
    }
    return ResponseBody.fromString('{"version":1,"defaults":{}}', 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late FakeWidgetBridge bridge;
  late _Adapter adapter;
  late bool signedIn;
  late bool remembered;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(drift.DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    bridge = FakeWidgetBridge(queue: [_op]);
    adapter = _Adapter();
    signedIn = true;
    remembered = true;
  });

  tearDown(() => db.close());

  HomeWidgetsController controller() {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    return HomeWidgetsController(
      bridge: bridge,
      provisioner: WidgetCredentialProvisioner(dio: dio, bridge: bridge),
      snapshots: WidgetSnapshotSync(dio: dio, bridge: bridge),
      ops: WidgetOpsRepository(
        db: db,
        bridge: bridge,
        dio: dio,
        listRepo:
            ListRepository(db: db, remote: FakeListService(), autoSync: false),
        choreRepo: ChoreRepository(db: db, remote: FakeChoreService()),
      ),
      currentUserId: () async => 'user-1',
      householdIds: () async => ['h1'],
      isSignedIn: () => signedIn,
      sessionIsRemembered: () async => remembered,
    );
  }

  test('a live session gets a credential first, then takes over the queue',
      () async {
    await controller().start();
    expect(adapter.paths.first, 'POST /auth/widget-credential');
    expect(adapter.paths, contains('GET /widget/snapshot'));
    expect(bridge.queue, isEmpty);
    expect(await db.outboxCount(), 1);
  });

  test('a dead restored session imports nothing', () async {
    adapter.sessionAlive = false;
    await controller().start();
    expect(bridge.queue, hasLength(1));
    expect(await db.outboxCount(), 0);
  });

  test('ops are only taken over for the account the credential was issued to',
      () async {
    // Signed in as user-1, but this install's credential belongs to user-2.
    SharedPreferences.setMockInitialValues({
      WidgetCredentialProvisioner.scopeKey: 'user-2|https://x|h1',
    });
    adapter.sessionAlive = false; // nothing gets re-issued
    final widgets = controller();
    await widgets.start();
    expect(bridge.queue, hasLength(1));

    SharedPreferences.setMockInitialValues({
      WidgetCredentialProvisioner.scopeKey: 'user-1|https://x|h1',
    });
    expect(await widgets.importOps(), 1);
  });

  test('nothing runs once signed out', () async {
    signedIn = false;
    await controller().start();
    controller().onPaused();
    expect(adapter.paths, isEmpty);
    expect(bridge.queue, hasLength(1));
  });

  test('a session that is not remembered gets no widgets at all', () async {
    remembered = false;
    await controller().start();
    expect(adapter.paths, isEmpty, reason: 'no credential is issued');
    expect(bridge.cleared, isTrue);
    expect(bridge.queue, isEmpty);
    expect(await db.outboxCount(), 0);
  });
}
