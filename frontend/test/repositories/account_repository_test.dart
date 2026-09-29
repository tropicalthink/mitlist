import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/repositories/account_repository.dart';
import 'package:mitlist/storage/app_database.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  late AppDatabase db;
  late List<UpdateUserRequest> sent;
  late int localWrites;
  Exception? failWith;

  AccountRepository build() => AccountRepository(
        db: db,
        updateMe: (request) async {
          if (failWith != null) throw failWith!;
          sent.add(request);
        },
        onLocalWrite: () => localWrites++,
      );

  setUp(() {
    db = _memoryDb();
    sent = [];
    localWrites = 0;
    failWith = null;
  });

  tearDown(() => db.close());

  test('a language change is queued, not sent', () async {
    await build().queueLanguage('de');

    expect(sent, isEmpty, reason: 'nothing leaves the device until a drain');
    expect(localWrites, 1, reason: 'the write opens a sync session');
    final ops = await db.getOutboxOpsByType(AccountRepository.setLanguageOp);
    expect(ops, hasLength(1));
    expect(jsonDecode(ops.single.payloadJson), {'language': 'de'});
    expect(ops.single.entityType, 'account');
  });

  test('only the newest queued language survives', () async {
    final repo = build();
    await repo.queueLanguage('de');
    await repo.queueLanguage('fr');
    await repo.queueLanguage('nl');

    final ops = await db.getOutboxOpsByType(AccountRepository.setLanguageOp);
    expect(ops, hasLength(1));
    expect(jsonDecode(ops.single.payloadJson), {'language': 'nl'});
  });

  test('draining sends the language and clears the op', () async {
    final repo = build();
    await repo.queueLanguage('es');
    await repo.drainOutboxOnce();

    expect(sent.map((r) => r.toJson()), [
      {'language': 'es'},
    ]);
    expect(await db.outboxCount(), 0);
  });

  test('offline, the op stays queued for the next drain', () async {
    final repo = build();
    await repo.queueLanguage('fr');
    failWith = DioException(
      requestOptions: RequestOptions(path: '/auth/me'),
      type: DioExceptionType.connectionError,
    );
    await repo.drainOutboxOnce();

    expect(sent, isEmpty);
    final ops = await db.getOutboxOpsByType(AccountRepository.setLanguageOp);
    expect(ops, hasLength(1), reason: 'an unreachable server keeps the op');
  });
}
