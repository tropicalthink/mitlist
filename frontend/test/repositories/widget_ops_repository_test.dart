import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/repositories/chore_repository.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/repositories/widget_ops_repository.dart';
import 'package:mitlist/storage/app_database.dart';

import '../services/widgets/fake_widget_bridge.dart';
import '../support/fakes.dart';

const _household = '11111111-1111-4111-8111-111111111111';
const _list = '22222222-2222-4222-8222-222222222222';
const _milk = '33333333-3333-4333-8333-333333333331';
const _checkOp = '77777777-7777-4777-8777-777777777771';
const _addOp = '77777777-7777-4777-8777-777777777772';
const _deliveredAddOp = '77777777-7777-4777-8777-777777777773';
const _choreOp = '77777777-7777-4777-8777-777777777774';
const _failedOp = '77777777-7777-4777-8777-777777777775';

/// Records each request's exact bytes and answers from [respond].
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.respond);

  final ResponseBody Function(RequestOptions options, String body) respond;
  final requests = <({RequestOptions options, String body})>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final body = utf8.decode(bytes);
    requests.add((options: options, body: body));
    return respond(options, body);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, Object?> _serverItem(String id, String name,
        {bool checked = false}) =>
    {
      'id': id,
      'list_id': _list,
      'name': name,
      'quantity': 1,
      'unit': '',
      'checked': checked,
      'position': 7,
      'created_at': '2026-10-02T09:10:00Z',
      'updated_at': '2026-10-02T09:10:00Z',
    };

void main() {
  late AppDatabase db;
  late ListRepository lists;
  late ChoreRepository chores;
  late List<String> fixture;

  setUp(() async {
    db = AppDatabase(drift.DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    // Repositories that never drain on their own: the widget repository is
    // the only thing sending here.
    lists = ListRepository(db: db, remote: FakeListService(), autoSync: false);
    chores = ChoreRepository(db: db, remote: FakeChoreService());
    await db.upsertListsRows([
      ListsTableCompanion(
        id: const drift.Value(_list),
        groupId: const drift.Value(_household),
        name: const drift.Value('Groceries'),
        type: const drift.Value('shopping'),
        createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
        updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
      ),
    ]);
    await db.upsertListItemsRows([
      ListItemsTableCompanion(
        id: const drift.Value(_milk),
        listId: const drift.Value(_list),
        name: const drift.Value('Oat milk'),
        quantity: const drift.Value(2.0),
        unit: const drift.Value('l'),
        checked: const drift.Value(false),
        position: const drift.Value(0),
        createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
        updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
      ),
    ]);
    fixture = File('../contracts/widgets/pending_ops_v1.jsonl')
        .readAsLinesSync()
        .where((l) => l.trim().isNotEmpty)
        .toList();
  });

  tearDown(() => db.close());

  WidgetOpsRepository repo(FakeWidgetBridge bridge, _RecordingAdapter adapter,
      {void Function()? onLocalWrite}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    return WidgetOpsRepository(
      db: db,
      bridge: bridge,
      dio: dio,
      listRepo: lists,
      choreRepo: chores,
      onLocalWrite: onLocalWrite,
    );
  }

  Future<ListItemsTableData?> item(String id) =>
      (db.select(db.listItemsTable)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  test('imports the queue: pending ops replay, delivered ones update the cache',
      () async {
    final bridge =
        FakeWidgetBridge(queue: [...fixture, '{"op_id":"broken-1"}']);
    final adapter = _RecordingAdapter((_, __) => _json(500, {}));
    var localWrites = 0;
    final widgets = repo(bridge, adapter, onLocalWrite: () => localWrites++);

    expect(await widgets.importPending(), 6);

    // Everything was taken over, including the failed and the broken line.
    expect(bridge.acks.single.toSet(), {
      _checkOp,
      _addOp,
      _deliveredAddOp,
      _choreOp,
      _failedOp,
      'broken-1',
    });
    expect(adapter.requests, isEmpty, reason: 'importing never sends');
    expect(localWrites, 1);

    // Pending ops became outbox ops carrying the widget's exact request.
    final ops = await db.getOutboxOpsByType(WidgetOpsRepository.outboxType);
    expect(ops.map((o) => o.id).toSet(), {_checkOp, _addOp, _choreOp});
    final check = ops.firstWhere((o) => o.id == _checkOp);
    expect(check.idempotencyKey, _checkOp);
    expect(check.entityType, 'listItem');
    expect(check.entityId, _milk);
    final payload = jsonDecode(check.payloadJson) as Map<String, dynamic>;
    expect(payload['method'], 'PATCH');
    expect(payload['path'], '/lists/$_list/items/$_milk');
    expect(payload['body'], '{"checked":true}');
    expect(payload['householdId'], _household);

    // The cache shows the widget's changes at once.
    expect((await item(_milk))!.checked, isTrue);
    expect((await item(_addOp))!.name, 'Butter');
    // The delivered add is stored under the server's id, not resent.
    expect((await item('88888888-8888-4888-8888-888888888888'))!.name, 'Eggs');
  });

  test('importing the same lines twice queues each op once', () async {
    final bridge = FakeWidgetBridge(queue: [fixture.first]);
    final widgets = repo(bridge, _RecordingAdapter((_, __) => _json(500, {})));
    await widgets.importPending();
    bridge.queue.add(fixture.first); // the app died before the ack
    await widgets.importPending();
    expect(await db.getOutboxOpsByType(WidgetOpsRepository.outboxType),
        hasLength(1));
  });

  test('replays the exact bytes with the op id as idempotency key', () async {
    final bridge = FakeWidgetBridge(queue: [fixture[1]]); // add "Butter"
    final adapter = _RecordingAdapter((options, body) => _json(
        201, _serverItem('99999999-9999-4999-8999-999999999999', 'Butter')));
    final widgets = repo(bridge, adapter);
    await widgets.importPending();
    await widgets.drainOutboxOnce();

    final sent = adapter.requests.single;
    expect(sent.options.method, 'POST');
    expect(sent.options.uri.toString(),
        'https://api.example.test/api/v1/lists/$_list/items');
    expect(sent.body, '{"name":"Butter"}');
    expect(sent.options.headers['Idempotency-Key'], _addOp);
    expect(sent.options.headers['X-Mitlist-Group-ID'], _household);

    // The optimistic row now carries the server id, and the op is gone.
    expect(await item(_addOp), isNull);
    expect(
        (await item('99999999-9999-4999-8999-999999999999'))!.name, 'Butter');
    expect(await db.outboxCount(), 0);
  });

  test('a refused replay is dropped and its optimistic row removed', () async {
    final bridge = FakeWidgetBridge(queue: [fixture[1]]);
    final widgets = repo(bridge,
        _RecordingAdapter((_, __) => _json(403, {'error': 'not a member'})));
    await widgets.importPending();
    expect(await item(_addOp), isNotNull);
    await widgets.drainOutboxOnce();
    expect(await db.outboxCount(), 0);
    expect(await item(_addOp), isNull);
  });

  test('an unreachable server keeps the op for later', () async {
    final bridge = FakeWidgetBridge(queue: [fixture.first]);
    final widgets = repo(
        bridge,
        _RecordingAdapter((options, _) => throw DioException.connectionError(
            requestOptions: options, reason: 'offline')));
    await widgets.importPending();
    await widgets.drainOutboxOnce();
    final ops = await db.getOutboxOpsByType(WidgetOpsRepository.outboxType);
    expect(ops, hasLength(1));
    expect(ops.single.attemptCount, 0, reason: 'offline is not the op’s fault');
  });

  test('an in-flight idempotent request is retried, not dropped', () async {
    final bridge = FakeWidgetBridge(queue: [fixture.first]);
    final widgets = repo(
        bridge,
        _RecordingAdapter((_, __) => ResponseBody.fromString(
              'request with this idempotency key is still processing',
              409,
              headers: {
                'retry-after': ['2']
              },
            )));
    await widgets.importPending();
    await widgets.drainOutboxOnce();
    expect(await db.getOutboxOpsByType(WidgetOpsRepository.outboxType),
        hasLength(1));
  });
}
