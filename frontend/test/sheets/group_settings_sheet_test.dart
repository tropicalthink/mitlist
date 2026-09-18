import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/attachment_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/attachment_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/repositories/group_repository.dart';
import 'package:mitlist/services/attachment_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/sheets/group_settings_sheet.dart';

import '../support/grocery_seed_test_helper.dart';

const _groupId = '11111111-1111-1111-1111-111111111111';
const _adminId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const _memberId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

class _FakeGroupService implements GroupService {
  final List<GroupMemberProfile> members = [
    const GroupMemberProfile(
        userId: _adminId, displayName: 'Ada Admin', role: 'admin'),
    const GroupMemberProfile(
        userId: _memberId, displayName: 'Bob Member', role: 'member'),
  ];
  final List<(String, String)> removeCalls = [];
  int listGroupsCalls = 0;

  Group _group(String groupId) => Group(
        id: groupId,
        name: 'Test Household',
        memberCount: members.where((m) => m.isActive).length,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  @override
  Future<Group> getGroup(String groupId) async => _group(groupId);

  @override
  Future<List<Group>> listGroups({int limit = 50, int offset = 0}) async {
    listGroupsCalls++;
    return [_group(_groupId)];
  }

  @override
  Future<List<GroupMemberProfile>> listMembers(String groupId) async =>
      List.of(members);

  @override
  Future<void> removeMember(String groupId, String userId) async {
    removeCalls.add((groupId, userId));
    // Mirrors the server: removal retires the membership instead of
    // deleting it, so the roster keeps listing the person as former.
    for (var i = 0; i < members.length; i++) {
      if (members[i].userId == userId) {
        members[i] = members[i].copyWith(leftAt: DateTime.utc(2026, 9, 13));
      }
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented on _FakeGroupService');
}

class _FakeAttachmentService implements AttachmentService {
  @override
  Future<StorageUsage> getStorageUsage({required String groupId}) async =>
      throw Exception('storage unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented on _FakeAttachmentService');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'remove member from the settings sheet inside a shell branch calls the API',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final groups = _FakeGroupService();
    final db = memoryDb();
    addTearDown(db.close);

    // Mirror production: the hub lives in a StatefulShellRoute branch and
    // opens the settings sheet on that branch navigator.
    final router = GoRouter(routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => shell,
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(builder: (context) {
                  return TextButton(
                    onPressed: () =>
                        GroupSettingsSheet.show(context, groupId: _groupId),
                    child: const Text('open'),
                  );
                }),
              ),
            ),
          ]),
        ],
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupServiceProviderAsync.overrideWith((ref) async => groups),
          groupRepositoryProvider.overrideWith(
              (ref) async => GroupRepository(db: db, groups: groups)),
          attachmentServiceProviderAsync
              .overrideWith((ref) async => _FakeAttachmentService()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Bob Member'), findsOneWidget);
    expect(find.text('Former members'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Remove Bob Member'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Bob Member'));
    await tester.pumpAndSettle();
    expect(find.text('REMOVE MEMBER'), findsOneWidget);

    await tester.tap(find.text('REMOVE'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(groups.removeCalls, [(_groupId, _memberId)]);
    // Removal is soft: Bob moves to the former members section, keeps his
    // name for the history that mentions him, and cannot be removed twice.
    expect(find.text('Former members'), findsOneWidget);
    expect(find.text('Bob Member'), findsOneWidget);
    expect(find.text('No longer in the household'), findsOneWidget);
    expect(find.byTooltip('Remove Bob Member'), findsNothing);
    expect(find.text('Ada Admin'), findsOneWidget);
    // The hub's household card reads the cached member count, so a removal
    // must refetch the household list rather than leave the stale count.
    expect(groups.listGroupsCalls, greaterThanOrEqualTo(1));
    final cached =
        await GroupRepository(db: db, groups: groups).getGroupsOnce();
    expect(cached.single.memberCount, 1);
  });
}
