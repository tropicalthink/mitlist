import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/finance_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/widgets/hub/onboarding_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';

  final household = Group(
    id: groupId,
    name: 'Flat 4B',
    isPersonal: false,
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget host(List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HubQuickStart(groupId: groupId),
          ),
        ),
      ),
    );
  }

  group('HubQuickStart', () {
    testWidgets('stamps items done from real household state', (tester) async {
      await tester.pumpWidget(host([
        cachedGroupsProvider.overrideWith((ref) async => [household]),
        cachedListsByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <ItemList>[])),
        cachedCurrentChoresByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <CurrentChore>[])),
        cachedExpensesByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <Expense>[])),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Get the house going'), findsOneWidget);
      expect(find.text('Invite flatmates'), findsOneWidget);
      expect(find.text('Create a list'), findsOneWidget);
      expect(find.text('Add a chore'), findsOneWidget);
      expect(find.text('Track an expense'), findsOneWidget);

      // memberCount 2 → the invite item is already done; nothing else is.
      // Exactly one DONE stamp is scaled into view.
      expect(find.text('1 of 4 done'), findsOneWidget);
      // Every note carries a stamp widget; only the done one is scaled in.
      // (The other AnimatedScale ancestors are the press affordances, always
      // at 1.0, so the discriminating count is the hidden stamps.)
      final stamps = tester.widgetList<AnimatedScale>(
        find.ancestor(
          of: find.text('DONE'),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(stamps.where((s) => s.scale == 0.0).length, 3);
    });

    testWidgets('renders nothing until the local caches have answered',
        (tester) async {
      final pending = StreamController<List<ItemList>>();
      addTearDown(pending.close);

      await tester.pumpWidget(host([
        cachedGroupsProvider.overrideWith((ref) async => [household]),
        cachedListsByGroupProvider.overrideWith((ref, id) => pending.stream),
        cachedCurrentChoresByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <CurrentChore>[])),
        cachedExpensesByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <Expense>[])),
      ]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Get the house going'), findsNothing);
    });
  });
}
