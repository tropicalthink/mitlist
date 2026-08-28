import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/recipe_models.dart';

Map<String, dynamic> _recipeJson(Map<String, dynamic> overrides) => {
      'id': '11111111-1111-1111-1111-111111111111',
      'title': 'Cake',
      'description': '',
      'prep_time': 10,
      'cook_time': 20,
      'servings': 4,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-02T00:00:00Z',
      ...overrides,
    };

void main() {
  group('Recipe visibility', () {
    test('a household recipe with a group is shared', () {
      final recipe = Recipe.fromJson(_recipeJson({
        'visibility': 'household',
        'group_id': '22222222-2222-2222-2222-222222222222',
      }));

      expect(recipe.visibility, RecipeVisibility.household);
      expect(recipe.isSharedWithHousehold, isTrue);
    });

    test('a household recipe whose group is gone is not shared', () {
      // The server's FK is ON DELETE SET NULL, so deleting a household leaves
      // visibility reading 'household' with no group. Treating that as shared
      // would show a badge claiming housemates can see a recipe nobody can.
      final recipe = Recipe.fromJson(_recipeJson({
        'visibility': 'household',
        'group_id': null,
      }));

      expect(recipe.isSharedWithHousehold, isFalse);
    });

    test('visibility defaults to private when the server omits it', () {
      final recipe = Recipe.fromJson(_recipeJson({}));

      expect(recipe.visibility, RecipeVisibility.private);
      expect(recipe.isSharedWithHousehold, isFalse);
    });

    test('a private recipe is never shared even with a group set', () {
      final recipe = Recipe.fromJson(_recipeJson({
        'visibility': 'private',
        'group_id': '22222222-2222-2222-2222-222222222222',
      }));

      expect(recipe.isSharedWithHousehold, isFalse);
    });
  });

  group('CreateRecipeRequest', () {
    test('sends visibility and omits group_id when private', () {
      final json = const CreateRecipeRequest(
        title: 'Cake',
        description: '',
        prepTime: 0,
        cookTime: 0,
        servings: 1,
      ).toJson();

      expect(json['visibility'], RecipeVisibility.private);
      expect(json.containsKey('group_id'), isFalse);
    });

    test('sends the household when sharing', () {
      final json = const CreateRecipeRequest(
        title: 'Cake',
        description: '',
        prepTime: 0,
        cookTime: 0,
        servings: 1,
        visibility: RecipeVisibility.household,
        groupId: '22222222-2222-2222-2222-222222222222',
      ).toJson();

      expect(json['visibility'], RecipeVisibility.household);
      expect(json['group_id'], '22222222-2222-2222-2222-222222222222');
    });
  });

  group('SharedRecipe', () {
    test('parses the recipe with its ingredients and steps', () {
      const tags = <String>['dessert'];
      final recipe = _recipeJson({'tags': tags});
      final shared = SharedRecipe.fromJson({
        'recipe': recipe,
        'ingredients': [
          {
            'id': '33333333-3333-3333-3333-333333333333',
            'recipe_id': '11111111-1111-1111-1111-111111111111',
            'name': 'flour',
            'raw_text': '200g flour',
          },
        ],
        'steps': [
          {
            'id': '44444444-4444-4444-4444-444444444444',
            'recipe_id': '11111111-1111-1111-1111-111111111111',
            'description': 'Mix.',
          },
        ],
      });

      expect(shared.recipe.title, 'Cake');
      expect(shared.recipe.tags, ['dessert']);
      expect(shared.ingredients.single.rawText, '200g flour');
      expect(shared.steps.single.description, 'Mix.');
    });

    test('survives a payload with no ingredients or steps', () {
      final shared = SharedRecipe.fromJson({'recipe': _recipeJson({})});

      expect(shared.ingredients, isEmpty);
      expect(shared.steps, isEmpty);
    });
  });
}
