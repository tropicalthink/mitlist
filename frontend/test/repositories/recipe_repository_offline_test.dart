import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/recipe_models.dart';
import 'package:mitlist/repositories/recipe_repository.dart';
import 'package:mitlist/services/recipe_service.dart';
import 'package:mitlist/storage/app_database.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

DioException _offline() => DioException(
      requestOptions: RequestOptions(path: '/recipes'),
      type: DioExceptionType.connectionError,
    );

Recipe _recipe(String id, String title, {String? groupId}) => Recipe(
      id: id,
      title: title,
      description: '',
      prepTime: 0,
      cookTime: 0,
      servings: 2,
      visibility: groupId == null
          ? RecipeVisibility.private
          : RecipeVisibility.household,
      groupId: groupId,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

class _FakeRecipeService implements RecipeService {
  bool offline = false;
  List<Recipe> recipes = [];
  List<RecipeCollection> collections = [];
  final List<({Map<String, dynamic> body, String? key})> creates = [];
  final List<String> deletes = [];
  final List<Map<String, dynamic>> collectionCreates = [];
  final List<({String collectionId, String recipeId})> filings = [];
  int _next = 0;

  void _check() {
    if (offline) throw _offline();
  }

  @override
  Future<List<Recipe>> listRecipes({
    int limit = 50,
    int offset = 0,
    String? groupId,
    List<String> tags = const [],
    String? search,
  }) async {
    _check();
    return recipes.skip(offset).take(limit).toList();
  }

  @override
  Future<Recipe> getRecipe(String id) async {
    _check();
    return recipes.firstWhere((r) => r.id == id);
  }

  @override
  Future<Recipe> createRecipeRaw(Map<String, dynamic> body,
      {String? idempotencyKey}) async {
    _check();
    creates.add((body: body, key: idempotencyKey));
    final created = _recipe('server-${_next++}', body['title'] as String);
    recipes.add(created);
    return created;
  }

  @override
  Future<void> deleteRecipe(String id, {String? idempotencyKey}) async {
    _check();
    deletes.add(id);
  }

  @override
  Future<List<RecipeCollection>> listCollections(
      {int limit = 50, int offset = 0, String? groupId}) async {
    _check();
    return collections;
  }

  @override
  Future<RecipeCollection> createCollectionRaw(Map<String, dynamic> body,
      {String? idempotencyKey}) async {
    _check();
    collectionCreates.add(body);
    return RecipeCollection(
      id: 'cookbook-${_next++}',
      name: body['name'] as String,
      recipeCount: 0,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<void> addRecipeToCollectionRaw(String collectionId, String recipeId,
      {String? idempotencyKey}) async {
    _check();
    filings.add((collectionId: collectionId, recipeId: recipeId));
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('unexpected: ${i.memberName}');
}

void main() {
  late AppDatabase db;
  late _FakeRecipeService remote;
  late RecipeRepository repo;

  setUp(() {
    db = _memoryDb();
    remote = _FakeRecipeService();
    repo = RecipeRepository(db: db, remote: remote, autoSync: false);
  });

  tearDown(() => db.close());

  Future<void> drainOnline() async {
    remote.offline = false;
    // Clear the 5s backoff an offline attempt stamped.
    await db.customStatement('UPDATE outbox_ops SET last_attempt_at = NULL');
    await repo.drainOutboxOnce();
  }

  const fullRequest = CreateRecipeRequest(
    title: 'Pancakes',
    author: 'Grandma',
    sourceUrl: 'https://example.com/pancakes',
    servings: 4,
    tags: ['breakfast'],
    ingredients: [
      CreateIngredientRequest(name: 'Flour', quantity: '200', unit: 'g'),
      CreateIngredientRequest(name: 'Milk', quantity: '1/2', unit: 'l'),
    ],
    steps: [
      CreateStepRequest(description: 'Mix'),
      CreateStepRequest(description: 'Fry'),
    ],
  );

  group('RecipeRepository offline —', () {
    test('a recipe created offline opens with its ingredients and steps',
        () async {
      remote.offline = true;
      final local = await repo.createRecipeOfflineFirst(fullRequest);

      final recipe = await repo.loadRecipe(local.id);
      expect(recipe.title, 'Pancakes');
      expect(recipe.author, 'Grandma');
      expect(recipe.sourceUrl, 'https://example.com/pancakes');

      final ingredients = await repo.loadIngredients(local.id);
      expect(ingredients.map((i) => i.name), ['Flour', 'Milk']);
      expect(ingredients.last.quantity, 0.5);
      final steps = await repo.loadSteps(local.id);
      expect(steps.map((s) => s.description), ['Mix', 'Fry']);
    });

    test('the sync replays the full request, ingredients included', () async {
      remote.offline = true;
      final local = await repo.createRecipeOfflineFirst(fullRequest);
      await repo.drainOutboxOnce();
      expect(remote.creates, isEmpty);

      await drainOnline();

      final sent = remote.creates.single;
      expect(sent.key, 'createRecipe:${local.id}');
      expect((sent.body['ingredients'] as List), hasLength(2));
      expect((sent.body['steps'] as List), hasLength(2));
      expect(sent.body['author'], 'Grandma');
      // A screen still holding the temp id follows the recipe to its new id.
      expect(repo.resolveRecipeId(local.id), 'server-0');
      expect((await repo.loadRecipe(local.id)).id, 'server-0');
    });

    test('kitchen page: server list plus queued create, minus queued delete',
        () async {
      remote.recipes = [_recipe('a', 'Soup'), _recipe('b', 'Salad')];
      await repo.loadRecipesPage(groupId: 'g1');

      remote.offline = true;
      final local = await repo.createRecipeOfflineFirst(
          const CreateRecipeRequest(title: 'Offline stew'));
      await repo.deleteRecipeOfflineFirst('b');

      // Offline: the cache answers, filtered the same way.
      final offline = await repo.loadRecipesPage(groupId: 'g1');
      expect(offline.fromCache, isTrue);
      expect(offline.hasMore, isFalse);
      expect(offline.recipes.map((r) => r.id).toSet(), {'a', local.id});

      // Online but before the drain: the server still lists 'b' and not the
      // new recipe; the overlay fixes both.
      remote.offline = false;
      final online = await repo.loadRecipesPage(groupId: 'g1');
      expect(online.fromCache, isFalse);
      expect(online.recipes.map((r) => r.id), [local.id, 'a']);
    });

    test('a household recipe of another household is not shown offline',
        () async {
      remote.recipes = [
        _recipe('mine', 'Mine'),
        _recipe('other', 'Other', groupId: 'g2'),
      ];
      await repo.loadRecipesPage(groupId: 'g1');
      remote.offline = true;
      final page = await repo.loadRecipesPage(groupId: 'g1');
      expect(page.recipes.map((r) => r.id), ['mine']);
    });

    test('an empty cache offline is an error, not an empty kitchen', () async {
      remote.offline = true;
      expect(() => repo.loadRecipesPage(), throwsA(isA<DioException>()));
    });

    test('deleting a recipe that never synced does not resurrect it', () async {
      remote.offline = true;
      final local = await repo
          .createRecipeOfflineFirst(const CreateRecipeRequest(title: 'Oops'));
      await repo.deleteRecipeOfflineFirst(local.id);

      await drainOnline();

      expect(remote.creates, hasLength(1));
      expect(remote.deletes, ['server-0']);
      expect(await repo.getRecipesOnce(), isEmpty);
      expect(await db.outboxCount(), 0);
    });
  });

  group('RecipeRepository cookbooks offline —', () {
    test('a cookbook made offline lists, counts and holds its recipe',
        () async {
      remote.recipes = [_recipe('a', 'Soup')];
      await repo.loadRecipesPage();
      remote.offline = true;

      final cookbook = await repo.createCollectionOfflineFirst(
          const CreateCollectionRequest(name: 'Winter'));
      await repo.addRecipeToCollectionOfflineFirst(cookbook.id, 'a');

      final listed = await repo.loadCollections();
      expect(listed.single.name, 'Winter');
      expect(listed.single.recipeCount, 1);
      final recipes = await repo.loadCollectionRecipes(cookbook.id);
      expect(recipes.map((r) => r.title), ['Soup']);

      await drainOnline();
      expect(remote.collectionCreates.single['name'], 'Winter');
      // The filing was pointed at the server id before it replayed.
      expect(
          remote.filings.single, (collectionId: 'cookbook-0', recipeId: 'a'));
      expect(repo.resolveCollectionId(cookbook.id), 'cookbook-0');
    });
  });
}
