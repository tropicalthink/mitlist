import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/recipe_models.dart';
import 'package:mitlist/screens/recipes/cook_mode_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Recipe _fakeRecipe({int servings = 4}) => Recipe(
      id: 'r1',
      title: 'Test Recipe',
      description: '',
      author: '',
      sourceUrl: '',
      videoUrl: '',
      imageUrl: null,
      prepTime: 10,
      cookTime: 20,
      servings: servings,
      nutritionJson: '',
      equipmentJson: '',
      imageOptions: const [],
      tags: const [],
      isPublic: false,
      ratingValue: 0,
      ratingCount: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

RecipeIngredient _fakeIngredient(String id, String name,
        {double qty = 100, String unit = 'g'}) =>
    RecipeIngredient(
      id: id,
      recipeId: 'r1',
      name: name,
      quantity: qty,
      unit: unit,
      rawText: '',
    );

RecipeStep _fakeStep(String id, String desc, int pos) => RecipeStep(
      id: id,
      recipeId: 'r1',
      description: desc,
      position: pos,
    );

final _ingredients = [
  _fakeIngredient('i1', 'flour', qty: 300, unit: 'g'),
  _fakeIngredient('i2', 'sugar', qty: 100, unit: 'g'),
  _fakeIngredient('i3', 'butter', qty: 50, unit: 'g'),
];

final _steps = [
  _fakeStep('s1', 'Mix the flour and sugar together.', 0),
  _fakeStep('s2', 'Add butter and mix until crumbly.', 1),
  _fakeStep('s3', 'Bake for 25 min.', 2),
];

Widget _buildScreen({
  Recipe? recipe,
  List<RecipeIngredient>? ingredients,
  List<RecipeStep>? steps,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CookModeScreen(
        recipeId: 'r1',
        recipe: recipe ?? _fakeRecipe(),
        ingredients: ingredients ?? _ingredients,
        steps: steps ?? _steps,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Phase A — mise en place
  // -------------------------------------------------------------------------
  group('mise en place', () {
    testWidgets('shows recipe title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      expect(find.text('Test Recipe'), findsOneWidget);
    });

    testWidgets('shows Start cooking button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // AppButton with solid variant uppercases text.
      expect(find.text('START COOKING'), findsOneWidget);
    });

    testWidgets('ingredients listed in mise en place', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      // scaledLabel for flour at scale 1.0 includes "flour".
      expect(find.textContaining('flour'), findsAtLeastNWidgets(1));
    });

    testWidgets('servings stepper shows default servings', (tester) async {
      await tester.pumpWidget(_buildScreen(recipe: _fakeRecipe(servings: 4)));
      await tester.pump();
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('tapping + increases servings', (tester) async {
      await tester.pumpWidget(_buildScreen(recipe: _fakeRecipe(servings: 4)));
      await tester.pump();
      // Find plus button via Semantics widget wrapping it.
      final plusWidgets = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Increase servings');
      expect(plusWidgets, findsOneWidget);
      await tester.tap(plusWidgets);
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('scaled quantity updates after tapping stepper',
        (tester) async {
      await tester.pumpWidget(_buildScreen(recipe: _fakeRecipe(servings: 4)));
      await tester.pump();
      // At 4 servings, flour is 300g.
      expect(find.textContaining('300'), findsAtLeastNWidgets(1));
      // Tap + to 5 servings: 300 * (5/4) = 375.
      final plusWidgets = find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Increase servings');
      await tester.tap(plusWidgets);
      await tester.pump();
      expect(find.textContaining('375'), findsAtLeastNWidgets(1));
    });
  });

  // -------------------------------------------------------------------------
  // Phase B — cook flow
  // -------------------------------------------------------------------------
  group('cook flow', () {
    Future<void> startCooking(WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.tap(find.text('START COOKING'));
      await tester.pump();
    }

    testWidgets('Start cooking reveals step 1 as current', (tester) async {
      await startCooking(tester);
      // Glance bar shows "Step 1 of 3".
      expect(find.text('Step 1 of 3'), findsOneWidget);
    });

    testWidgets('tapping Done advances to step 2', (tester) async {
      await startCooking(tester);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      // Done zone shows "Done →" text.
      expect(find.text('Done →'), findsOneWidget);
      await tester.tap(find.text('Done →'));
      await tester.pump();
      expect(find.text('Step 2 of 3'), findsOneWidget);
    });

    testWidgets('tapping a later step jumps current to it', (tester) async {
      await startCooking(tester);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      // Step 3's description text is visible as upcoming; tap it.
      await tester.tap(find.text('Bake for 25 min.').first);
      await tester.pump();
      expect(find.text('Step 3 of 3'), findsOneWidget);
    });

    testWidgets('finishing last step shows finished state', (tester) async {
      await startCooking(tester);
      // Advance through steps 1 and 2.
      await tester.tap(find.text('Done →'));
      await tester.pump();
      await tester.tap(find.text('Done →'));
      await tester.pump();
      // Now on last step (step 3), button shows "Finish".
      // On last step, the Done zone shows "Finish".
      expect(find.text('Finish'), findsOneWidget);
      await tester.tap(find.text('Finish'));
      await tester.pump();
      expect(find.text('Finished — nice work'), findsOneWidget);
    });

    testWidgets('Ingredients handle is visible during cook flow',
        (tester) async {
      await startCooking(tester);
      // The ingredients handle shows "Ingredients" label text.
      expect(find.text('Ingredients'), findsOneWidget);
    });

    testWidgets('current step shows large step label', (tester) async {
      await startCooking(tester);
      expect(find.text('Step 1'), findsOneWidget);
    });

    testWidgets('advancing through all steps reaches finished state',
        (tester) async {
      await startCooking(tester);
      for (int i = 0; i < _steps.length - 1; i++) {
        expect(find.text('Done →'), findsOneWidget);
        await tester.tap(find.text('Done →'));
        await tester.pump();
      }
      // On last step, Done zone shows "Finish".
      expect(find.text('Finish'), findsOneWidget);
      await tester.tap(find.text('Finish'));
      await tester.pump();
      expect(find.text('Finished — nice work'), findsOneWidget);
    });
  });
}
