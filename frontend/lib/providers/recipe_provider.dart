import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recipe_service.dart';
import '../models/recipe_models.dart';

final recipeServiceProviderAsync = FutureProvider<RecipeService>((ref) async {
  return await RecipeService.create(ref);
});

final recipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final service = await ref.read(recipeServiceProviderAsync.future);
  return service.listRecipes();
});
