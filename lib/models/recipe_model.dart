/// Recipe data model loaded from assets/data/recipes_nutrition_sample.json.
///
/// Dataset: datahiveai/recipes-with-nutrition (Hugging Face, CC BY-NC 4.0).
/// For academic / prototype use only. Official nutrition reference: USDA FoodData Central.
class RecipeModel {
  const RecipeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.mealType,
    required this.calories,
    required this.estimatedPricePhp,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
    required this.dietLabels,
    required this.healthLabels,
    required this.cookingSteps,
    this.imageUrl,
    this.source = '',
  });

  final String id;
  final String name;
  final String description;

  /// One of: breakfast, lunch, dinner, snack
  final String mealType;

  final int calories;
  final double estimatedPricePhp;
  final int protein;
  final int carbs;
  final int fat;

  final List<String> ingredients;
  final List<String> dietLabels;
  final List<String> healthLabels;
  final List<String> cookingSteps;

  final String? imageUrl;
  final String source;

  factory RecipeModel.fromJson(Map<String, dynamic> json) => RecipeModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        mealType: (json['mealType'] as String? ?? 'lunch').toLowerCase(),
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        estimatedPricePhp:
            (json['estimatedPricePhp'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
        fat: (json['fat'] as num?)?.toInt() ?? 0,
        ingredients:
            List<String>.from(json['ingredients'] as List? ?? []),
        dietLabels:
            List<String>.from(json['dietLabels'] as List? ?? []),
        healthLabels:
            List<String>.from(json['healthLabels'] as List? ?? []),
        cookingSteps:
            List<String>.from(json['cookingSteps'] as List? ?? []),
        imageUrl: json['imageUrl'] as String?,
        source: json['source'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'mealType': mealType,
        'calories': calories,
        'estimatedPricePhp': estimatedPricePhp,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'ingredients': ingredients,
        'dietLabels': dietLabels,
        'healthLabels': healthLabels,
        'cookingSteps': cookingSteps,
        'imageUrl': imageUrl,
        'source': source,
      };

  String get mealTypeLabel {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return mealType;
    }
  }

  String get mealEmoji {
    switch (mealType) {
      case 'breakfast':
        return '🌅';
      case 'lunch':
        return '🍱';
      case 'dinner':
        return '🍽️';
      case 'snack':
        return '🍌';
      default:
        return '🍽️';
    }
  }
}
