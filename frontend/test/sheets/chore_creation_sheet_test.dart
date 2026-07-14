import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show grocerySeedProvider;
import 'package:mitlist/services/chore_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/sheets/chore_creation_sheet.dart';

import '../support/grocery_seed_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';
  final group = Group(
    id: groupId,
    name: 'Test Household',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets('adds grocery-aware supplies to the create request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final groceryDb = memoryDb();
    addTearDown(groceryDb.close);
    final chores = _FakeChoreService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider.overrideWith((ref) async => [group]),
          groupServiceProviderAsync.overrideWith(
            (ref) async => _FakeGroupService(),
          ),
          choreServiceProviderAsync.overrideWith((ref) async => chores),
          grocerySeedProvider.overrideWith((ref) async {}),
          grocerySuggestionServiceProvider.overrideWithValue(
            GrocerySuggestionService(groceryDb),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: ChoreCreationSheet()),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.enterText(find.byType(TextField).first, 'Clean kitchen');
    await tester.tap(find.text('More options'));
    await tester.pump(const Duration(milliseconds: 250));
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(1), 'Dish soap');
    await tester.ensureVisible(find.text('ADD'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('ADD'));
    await tester.pump();
    expect(find.text('Dish soap'), findsOneWidget);

    await tester.ensureVisible(find.text('ADD CHORE'));
    await tester.pump();
    await tester.tap(find.text('ADD CHORE'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(chores.lastCreate?.supplies, ['Dish soap']);
  });
}

class _FakeGroupService implements GroupService {
  @override
  Future<List<GroupMemberProfile>> listMembers(String groupId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeChoreService implements ChoreService {
  CreateChoreRequest? lastCreate;

  @override
  Future<Chore> createChore(CreateChoreRequest req) async {
    lastCreate = req;
    return Chore(
      id: '22222222-2222-2222-2222-222222222222',
      groupId: req.groupId,
      name: req.name,
      rotationType: req.rotationType,
      frequency: req.frequency,
      isActive: true,
      supplies: req.supplies,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
