import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mitlist/config/api_config.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/models/notification_models.dart';
import 'package:mitlist/repositories/account_repository.dart';
import 'package:mitlist/services/notification_service.dart';
import 'package:mitlist/storage/app_database.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

class _NotificationService implements NotificationService {
  final read = <String>[];
  final deleted = <String>[];
  int readAll = 0;
  final prefs = <Map<String, dynamic>>[];

  @override
  Future<void> markAsRead(String id) async => read.add(id);

  @override
  Future<void> markAllAsRead() async => readAll++;

  @override
  Future<void> deleteNotification(String id) async => deleted.add(id);

  @override
  Future<void> updatePreference(NotificationPreferenceModel pref) async =>
      prefs.add(pref.toPatchJson());

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

NotificationModel _notification(String id,
        {bool isRead = false, int day = 1}) =>
    NotificationModel(
      id: id,
      userId: 'u1',
      type: 'list_item_added',
      title: 'Title',
      body: 'Body',
      data: null,
      isRead: isRead,
      readAt: null,
      createdAt: DateTime.utc(2026, 1, day),
    );

User _user() => User.fromJson({
      'id': 'u1',
      'email': 'ada@example.com',
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'is_active': true,
      'is_verified': true,
      'is_guest': false,
      'tips_emails_enabled': true,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

void main() {
  late AppDatabase db;
  late _NotificationService notifications;
  late List<UpdateUserRequest> sent;
  late AccountRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      ApiConfig.userDataKey: jsonEncode(_user().toJson()),
    });
    db = _memoryDb();
    notifications = _NotificationService();
    sent = [];
    repo = AccountRepository(
      db: db,
      updateMe: (request) async => sent.add(request),
      notifications: notifications,
      // Queue only; the tests drain explicitly.
      onLocalWrite: () {},
    );
  });

  tearDown(() => db.close());

  group('profile —', () {
    test('a rename is queued and shows in the saved profile at once', () async {
      await repo.queueProfileUpdate(firstName: 'Grace', lastName: 'Hopper');

      expect(sent, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final saved = User.fromJson(
          jsonDecode(prefs.getString(ApiConfig.userDataKey)!)
              as Map<String, dynamic>);
      expect(saved.fullName, 'Grace Hopper');
      // A server answer from before the rename is overlaid.
      expect((await repo.withPendingProfile(_user())).fullName, 'Grace Hopper');
    });

    test('profile edits merge into one op and drain as one patch', () async {
      await repo.queueProfileUpdate(firstName: 'Grace', lastName: 'Hopper');
      await repo.queueProfileUpdate(tipsEmailsEnabled: false);

      expect(await db.getOutboxOpsByType(AccountRepository.updateProfileOp),
          hasLength(1));
      await repo.drainOutboxOnce();

      expect(sent.single.toJson(), {
        'first_name': 'Grace',
        'last_name': 'Hopper',
        'tips_emails_enabled': false,
      });
      expect(await db.outboxCount(), 0);
    });
  });

  group('inbox —', () {
    test('queued reads and deletes are laid over a fetched page', () async {
      await repo.markNotificationRead('n1');
      await repo.deleteNotification('n2', wasUnread: true);

      final items = await repo.withPendingNotificationWrites([
        _notification('n1'),
        _notification('n2'),
        _notification('n3'),
      ]);

      expect(items.map((n) => n.id), ['n1', 'n3']);
      expect(items.first.isRead, isTrue);
      expect(items.last.isRead, isFalse);
      expect(await repo.unreadCountWithPending(3), 1);
    });

    test('read-all marks what arrived before it and zeroes the badge',
        () async {
      await repo.markNotificationRead('n1');
      await repo.markAllNotificationsRead();

      // The single read is covered by the read-all.
      expect(
          await db.getOutboxOpsByType(AccountRepository.markNotificationReadOp),
          isEmpty);
      final items = await repo.withPendingNotificationWrites([
        _notification('n1'),
        _notification('n2'),
      ]);
      expect(items.every((n) => n.isRead), isTrue);
      expect(await repo.unreadCountWithPending(5), 0);
    });

    test('the drain sends each inbox write once', () async {
      await repo.markNotificationRead('n1');
      await repo.markNotificationRead('n1');
      await repo.deleteNotification('n2', wasUnread: false);

      await repo.drainOutboxOnce();

      expect(notifications.read, ['n1']);
      expect(notifications.deleted, ['n2']);
      expect(await db.outboxCount(), 0);
    });
  });

  group('preferences —', () {
    const base = NotificationPreferenceModel(
      id: 'p1',
      userId: 'u1',
      groupId: 'g1',
    );

    test('the newest queued set wins and overlays the fetched one', () async {
      await repo.queueNotificationPreference(const NotificationPreferenceModel(
          id: 'p1', userId: 'u1', groupId: 'g1', choreDue: false));
      await repo.queueNotificationPreference(const NotificationPreferenceModel(
          id: 'p1',
          userId: 'u1',
          groupId: 'g1',
          choreDue: false,
          weeklyDigest: false));

      final prefs = await repo.withPendingPreferences([base]);
      expect(prefs.single.id, 'p1');
      expect(prefs.single.choreDue, isFalse);
      expect(prefs.single.weeklyDigest, isFalse);

      await repo.drainOutboxOnce();
      expect(notifications.prefs, hasLength(1));
      expect(notifications.prefs.single['group_id'], 'g1');
      expect(notifications.prefs.single['weekly_digest'], isFalse);
    });
  });

  test('sign-out discards every queued account op', () async {
    await repo.queueLanguage('de');
    await repo.queueProfileUpdate(firstName: 'Grace');
    await repo.markAllNotificationsRead();
    await repo.deleteNotification('n2', wasUnread: true);

    await AccountRepository.discardQueued(db);

    expect(await db.outboxCount(), 0);
  });
}
