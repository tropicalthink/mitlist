import 'dart:convert';

String _normalizeJsonForApi(String value, {String emptyFallback = '{}'}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return emptyFallback;

  // If it already looks like JSON, validate it so we don't send invalid JSON
  // into json/jsonb columns.
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      jsonDecode(trimmed);
      return trimmed;
    } catch (_) {
      // fall through to wrapping as safe JSON
    }
  }

  // For freeform user-entered text, store it as valid JSON.
  return jsonEncode({'text': trimmed});
}

class Recipe {
  final String id;
  final String title;
  final String description;
  final String descriptionShort;
  final String author;
  final double ratingValue;
  final int ratingCount;
  final String nutritionJson;
  final String videoUrl;
  final String equipmentJson;
  final String sourceUrl;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String? imageUrl;
  final List<String> imageOptions;
  final List<String> tags;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    this.descriptionShort = '',
    this.author = '',
    this.ratingValue = 0,
    this.ratingCount = 0,
    this.nutritionJson = '',
    this.videoUrl = '',
    this.equipmentJson = '',
    this.sourceUrl = '',
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    this.imageUrl,
    this.imageOptions = const [],
    this.tags = const [],
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        descriptionShort: json['description_short'] as String? ?? '',
        author: json['author'] as String? ?? '',
        ratingValue: (json['rating_value'] as num?)?.toDouble() ?? 0,
        ratingCount: json['rating_count'] as int? ?? 0,
        nutritionJson: json['nutrition_json'] as String? ?? '',
        videoUrl: json['video_url'] as String? ?? '',
        equipmentJson: json['equipment_json'] as String? ?? '',
        sourceUrl: json['source_url'] as String? ?? '',
        prepTime: json['prep_time'] as int? ?? 0,
        cookTime: json['cook_time'] as int? ?? 0,
        servings: json['servings'] as int? ?? 1,
        imageUrl: json['image_url'] as String?,
        imageOptions: (json['image_options'] is List)
            ? (json['image_options'] as List).whereType<String>().toList()
            : const [],
        tags: (json['tags'] is List)
            ? (json['tags'] as List).whereType<String>().toList()
            : const [],
        isPublic: json['is_public'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'description_short': descriptionShort,
        'author': author,
        'rating_value': ratingValue,
        'rating_count': ratingCount,
        'nutrition_json': nutritionJson,
        'video_url': videoUrl,
        'equipment_json': equipmentJson,
        'source_url': sourceUrl,
        'prep_time': prepTime,
        'cook_time': cookTime,
        'servings': servings,
        'image_url': imageUrl,
        'image_options': imageOptions,
        'tags': tags,
        'is_public': isPublic,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class RecipeCollection {
  final String id;
  final String name;
  final int? recipeCount;
  final DateTime createdAt;

  const RecipeCollection({
    required this.id,
    required this.name,
    this.recipeCount,
    required this.createdAt,
  });

  factory RecipeCollection.fromJson(Map<String, dynamic> json) =>
      RecipeCollection(
        id: json['id'] as String,
        name: json['name'] as String,
        recipeCount: json['recipe_count'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class CreateRecipeRequest {
  final String title;
  final String description;
  final String descriptionShort;
  final String author;
  final double ratingValue;
  final int ratingCount;
  final String nutritionJson;
  final String videoUrl;
  final String equipmentJson;
  final String sourceUrl;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String? imageUrl;
  final List<String> imageOptions;
  final List<String> tags;
  final bool isPublic;
  const CreateRecipeRequest({
    required this.title,
    this.description = '',
    this.descriptionShort = '',
    this.author = '',
    this.ratingValue = 0,
    this.ratingCount = 0,
    this.nutritionJson = '{}',
    this.videoUrl = '',
    this.equipmentJson = '{}',
    this.sourceUrl = '',
    this.prepTime = 0,
    this.cookTime = 0,
    this.servings = 1,
    this.imageUrl,
    this.imageOptions = const [],
    this.tags = const [],
    this.isPublic = false,
  });
  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'description_short': descriptionShort,
        'author': author,
        'rating_value': ratingValue,
        'rating_count': ratingCount,
        'nutrition_json': _normalizeJsonForApi(nutritionJson),
        'video_url': videoUrl,
        'equipment_json': _normalizeJsonForApi(equipmentJson),
        'source_url': sourceUrl,
        'prep_time': prepTime,
        'cook_time': cookTime,
        'servings': servings,
        'image_url': imageUrl,
        'image_options': imageOptions,
        'tags': tags,
        'is_public': isPublic,
      };
}

class UpdateRecipeRequest {
  final String? title;
  final String? description;
  final String? descriptionShort;
  final String? author;
  final double? ratingValue;
  final int? ratingCount;
  final String? nutritionJson;
  final String? videoUrl;
  final String? equipmentJson;
  final String? sourceUrl;
  final int? prepTime;
  final int? cookTime;
  final int? servings;
  final String? imageUrl;
  final List<String>? imageOptions;
  final List<String>? tags;
  final bool? isPublic;

  const UpdateRecipeRequest({
    this.title,
    this.description,
    this.descriptionShort,
    this.author,
    this.ratingValue,
    this.ratingCount,
    this.nutritionJson,
    this.videoUrl,
    this.equipmentJson,
    this.sourceUrl,
    this.prepTime,
    this.cookTime,
    this.servings,
    this.imageUrl,
    this.imageOptions,
    this.tags,
    this.isPublic,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (title != null) m['title'] = title;
    if (description != null) m['description'] = description;
    if (descriptionShort != null) m['description_short'] = descriptionShort;
    if (author != null) m['author'] = author;
    if (ratingValue != null) m['rating_value'] = ratingValue;
    if (ratingCount != null) m['rating_count'] = ratingCount;
    if (nutritionJson != null) {
      m['nutrition_json'] = _normalizeJsonForApi(nutritionJson!);
    }
    if (videoUrl != null) m['video_url'] = videoUrl;
    if (equipmentJson != null) {
      m['equipment_json'] = _normalizeJsonForApi(equipmentJson!);
    }
    if (sourceUrl != null) m['source_url'] = sourceUrl;
    if (prepTime != null) m['prep_time'] = prepTime;
    if (cookTime != null) m['cook_time'] = cookTime;
    if (servings != null) m['servings'] = servings;
    if (imageUrl != null) m['image_url'] = imageUrl;
    if (imageOptions != null) m['image_options'] = imageOptions;
    if (tags != null) m['tags'] = tags;
    if (isPublic != null) m['is_public'] = isPublic;
    return m;
  }
}

class CreateCollectionRequest {
  final String name;
  const CreateCollectionRequest({required this.name});
  Map<String, dynamic> toJson() => {'name': name};
}

class UpdateCollectionRequest {
  final String? name;
  const UpdateCollectionRequest({this.name});
  Map<String, dynamic> toJson() => {if (name != null) 'name': name};
}

class AddRecipeToCollectionRequest {
  final String recipeId;
  const AddRecipeToCollectionRequest({required this.recipeId});
  Map<String, dynamic> toJson() => {'recipe_id': recipeId};
}

class ShareRecipeRequest {
  final String sharedWithUserId;
  final String permission;
  const ShareRecipeRequest(
      {required this.sharedWithUserId, required this.permission});
  Map<String, dynamic> toJson() =>
      {'shared_with_user_id': sharedWithUserId, 'permission': permission};
}

class RecipeClipIngredient {
  final String rawText;
  final String name;
  final double quantity;
  final String unit;
  const RecipeClipIngredient({
    required this.rawText,
    this.name = '',
    this.quantity = 0,
    this.unit = '',
  });

  factory RecipeClipIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeClipIngredient(
        rawText: json['raw_text'] as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
      );
}

class RecipeClipResponse {
  final String title;
  final String sourceUrl;
  final String description;
  final String author;
  final double ratingValue;
  final int ratingCount;
  final Map<String, dynamic>? nutrition;
  final String videoUrl;
  final List<String> equipment;
  final String instructionsMd;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final String? servings;
  final List<RecipeClipIngredient> ingredients;
  final String? imageUrl;
  final List<String> imageOptions;
  final List<String> tags;

  const RecipeClipResponse({
    required this.title,
    required this.sourceUrl,
    this.description = '',
    this.author = '',
    this.ratingValue = 0,
    this.ratingCount = 0,
    this.nutrition,
    this.videoUrl = '',
    this.equipment = const [],
    required this.instructionsMd,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.ingredients,
    required this.imageUrl,
    required this.imageOptions,
    required this.tags,
  });

  factory RecipeClipResponse.fromJson(Map<String, dynamic> json) {
    final ing = json['ingredients'];
    return RecipeClipResponse(
      title: json['title'] as String? ?? 'Untitled Recipe',
      sourceUrl: json['source_url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? '',
      ratingValue: (json['rating_value'] as num?)?.toDouble() ?? 0,
      ratingCount: json['rating_count'] as int? ?? 0,
      nutrition: json['nutrition'] as Map<String, dynamic>?,
      videoUrl: json['video_url'] as String? ?? '',
      equipment: (json['equipment'] is List)
          ? (json['equipment'] as List).whereType<String>().toList()
          : const [],
      instructionsMd: json['instructions_md'] as String? ?? '',
      prepTimeMinutes: json['prep_time_minutes'] as int?,
      cookTimeMinutes: json['cook_time_minutes'] as int?,
      servings: json['servings'] as String?,
      ingredients: (ing is List)
          ? ing
              .whereType<Map>()
              .map((e) => RecipeClipIngredient.fromJson(
                  e.cast<String, dynamic>()))
              .toList()
          : const [],
      imageUrl: json['image_url'] as String?,
      imageOptions: (json['image_options'] is List)
          ? (json['image_options'] as List).whereType<String>().toList()
          : const [],
      tags: (json['tags'] is List)
          ? (json['tags'] as List).whereType<String>().toList()
          : const [],
    );
  }
}

class RecipeIngredient {
  final String id;
  final String recipeId;
  final String name;
  final double quantity;
  final String unit;
  final String rawText;
  final int position;

  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.name,
    this.quantity = 0,
    this.unit = '',
    this.rawText = '',
    this.position = 0,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
        id: json['id'] as String,
        recipeId: json['recipe_id'] as String,
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
        rawText: json['raw_text'] as String? ?? '',
        position: json['position'] as int? ?? 0,
      );
}
