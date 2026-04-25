class Recipe {
  final String id;
  final String title;
  final String description;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String? imageUrl;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Recipe({
    required this.id, required this.title, required this.description,
    required this.prepTime, required this.cookTime, required this.servings,
    this.imageUrl, required this.isPublic,
    required this.createdAt, required this.updatedAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    prepTime: json['prep_time'] as int? ?? 0,
    cookTime: json['cook_time'] as int? ?? 0,
    servings: json['servings'] as int? ?? 1,
    imageUrl: json['image_url'] as String?,
    isPublic: json['is_public'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'prep_time': prepTime, 'cook_time': cookTime, 'servings': servings,
    'image_url': imageUrl, 'is_public': isPublic,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };
}

class RecipeCollection {
  final String id;
  final String name;
  final int recipeCount;
  final DateTime createdAt;

  const RecipeCollection({
    required this.id, required this.name,
    required this.recipeCount, required this.createdAt,
  });

  factory RecipeCollection.fromJson(Map<String, dynamic> json) => RecipeCollection(
    id: json['id'] as String,
    name: json['name'] as String,
    recipeCount: json['recipe_count'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class CreateRecipeRequest {
  final String title;
  final String description;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String? imageUrl;
  final bool isPublic;
  const CreateRecipeRequest({
    required this.title, this.description = '', this.prepTime = 0,
    this.cookTime = 0, this.servings = 1, this.imageUrl, this.isPublic = false,
  });
  Map<String, dynamic> toJson() => {
    'title': title, 'description': description, 'prep_time': prepTime,
    'cook_time': cookTime, 'servings': servings, 'image_url': imageUrl, 'is_public': isPublic,
  };
}

class CreateCollectionRequest {
  final String name;
  const CreateCollectionRequest({required this.name});
  Map<String, dynamic> toJson() => {'name': name};
}

class ShareRecipeRequest {
  final String sharedWithUserId;
  final String permission;
  const ShareRecipeRequest({required this.sharedWithUserId, required this.permission});
  Map<String, dynamic> toJson() => {'shared_with_user_id': sharedWithUserId, 'permission': permission};
}
