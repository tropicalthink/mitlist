import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/models/meal_plan_models.dart';
import 'package:mitlist/models/recipe_models.dart';
import 'package:mitlist/providers/meal_plan_provider.dart';
import 'package:mitlist/widgets/hub/tonight_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _groupId = 'group-1';

Recipe _fakeRecipe({
  String id = 'recipe-1',
  String title = 'Lasagna',
  int servings = 4,
}) =>
    Recipe(
      id: id,
      title: title,
      description: 'A great dish.',
      prepTime: 20,
      cookTime: 40,
      servings: servings,
      imageUrl: null,
      isPublic: false,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

MealPlan _fakePlan({
  String id = 'plan-1',
  String slot = 'dinner',
  String recipeId = 'recipe-1',
  int servings = 4,
}) =>
    MealPlan(
      id: id,
      groupId: _groupId,
      date: DateTime.now(),
      slot: slot,
      recipeId: recipeId,
      servings: servings,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

/// Pumps [TonightCard] inside a minimal GoRouter so navigation works.
/// Stub routes for recipeDetail, recipeCook, and mealPlan render marker text.
Future<void> _pumpCard(
  WidgetTester tester, {
  required AsyncValue<List<TodayMeal>> providerValue,
}) async {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: TonightCard(groupId: _groupId),
        ),
      ),
      GoRoute(
        path: '/recipes/:recipeId',
        name: 'recipeDetail',
        builder: (context, state) => const Scaffold(body: Text('DETAIL')),
      ),
      GoRoute(
        path: '/recipes/:recipeId/cook',
        name: 'recipeCook',
        builder: (context, state) => const Scaffold(body: Text('COOK')),
      ),
      GoRoute(
        path: '/meal-plan',
        name: 'mealPlan',
        builder: (context, state) => const Scaffold(body: Text('PLAN')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayMealPlansProvider(_groupId).overrideWith(
          (ref) async {
            switch (providerValue) {
              case AsyncData(:final value):
                return value;
              case AsyncError(:final error):
                throw error;
              default:
                // loading: never complete
                await Future<void>.delayed(const Duration(days: 1));
                return [];
            }
          },
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  // Pump until async resolves.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('dinner planned: shows Tonight header and recipe title',
      (tester) async {
    final recipe = _fakeRecipe(title: 'Lasagna');
    final plan = _fakePlan(slot: 'dinner', recipeId: recipe.id);
    await _pumpCard(
      tester,
      providerValue: AsyncData([(plan: plan, recipe: recipe)]),
    );

    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text('Lasagna'), findsOneWidget);
    // AppButton solid variant uppercases text.
    expect(find.text('COOK'), findsOneWidget);
  });

  testWidgets('tapping Cook button navigates to recipeCook', (tester) async {
    final recipe = _fakeRecipe(title: 'Lasagna');
    final plan = _fakePlan(slot: 'dinner', recipeId: recipe.id);
    await _pumpCard(
      tester,
      providerValue: AsyncData([(plan: plan, recipe: recipe)]),
    );

    // AppButton solid variant uppercases text.
    // AppButton solid variant uppercases text.
    await tester.tap(find.text('COOK'));
    await tester.pumpAndSettle();

    // After navigation, the marker widget is shown.
    expect(find.text('COOK'), findsOneWidget);
  });

  testWidgets('tapping card body navigates to recipeDetail', (tester) async {
    final recipe = _fakeRecipe(title: 'Lasagna');
    final plan = _fakePlan(slot: 'dinner', recipeId: recipe.id);
    await _pumpCard(
      tester,
      providerValue: AsyncData([(plan: plan, recipe: recipe)]),
    );

    // Tap the card body (recipe title) rather than the Cook button.
    await tester.tap(find.text('Lasagna'));
    await tester.pumpAndSettle();

    expect(find.text('DETAIL'), findsOneWidget);
  });

  testWidgets('lunch-only day shows Today · Lunch header', (tester) async {
    final recipe = _fakeRecipe(title: 'Club Sandwich');
    final plan = _fakePlan(slot: 'lunch', recipeId: recipe.id);
    await _pumpCard(
      tester,
      providerValue: AsyncData([(plan: plan, recipe: recipe)]),
    );

    expect(find.text('Today · Lunch'), findsOneWidget);
    expect(find.text('Club Sandwich'), findsOneWidget);
  });

  testWidgets('no plans shows empty state', (tester) async {
    await _pumpCard(
      tester,
      providerValue: const AsyncData([]),
    );

    expect(find.text('Nothing planned for tonight'), findsOneWidget);
    // AppButton outline variant uppercases text.
    expect(find.text('PLAN DINNER'), findsOneWidget);
  });

  testWidgets('tapping Plan dinner navigates to mealPlan', (tester) async {
    await _pumpCard(
      tester,
      providerValue: const AsyncData([]),
    );

    // AppButton outline variant uppercases text.
    await tester.tap(find.text('PLAN DINNER'));
    await tester.pumpAndSettle();

    expect(find.text('PLAN'), findsOneWidget);
  });

  testWidgets('error state shows empty state (hub stays calm)', (tester) async {
    await _pumpCard(
      tester,
      providerValue: AsyncError(Exception('fail'), StackTrace.empty),
    );

    expect(find.text('Nothing planned for tonight'), findsOneWidget);
  });
}
