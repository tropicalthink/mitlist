import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recipe_service.dart';
import '../models/recipe_models.dart';
import '../providers/list_provider.dart';
import '../repositories/recipe_repository.dart';

final recipeServiceProviderAsync = FutureProvider<RecipeService>((ref) async {
  return await RecipeService.create(ref);
});

final recipeRepositoryProvider = FutureProvider<RecipeRepository>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final service = await ref.read(recipeServiceProviderAsync.future);
  return RecipeRepository(db: db, remote: service);
});

final cachedRecipesProvider = StreamProvider<List<Recipe>>((ref) async* {
  final repo = await ref.watch(recipeRepositoryProvider.future);
  yield* repo.watchRecipes();
});

final recipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final service = await ref.read(recipeServiceProviderAsync.future);
  return service.listRecipes();
});
