/// Recipe data model loaded from prototype assets or the recipe backend API.
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
    this.ingredientLines = const [],
    this.cuisineTypes = const [],
    this.mealTypes = const [],
    this.dishTypes = const [],
    this.servings,
    this.url,
    this.sourceType = '',
    this.isPrototypeDataset = false,
    this.dataNotice = '',
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
  final List<String> ingredientLines;
  final List<String> cuisineTypes;
  final List<String> mealTypes;
  final List<String> dishTypes;
  final int? servings;
  final String? url;
  final String sourceType;
  final bool isPrototypeDataset;
  final String dataNotice;

  factory RecipeModel.fromJson(Map<String, dynamic> json) => RecipeModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        mealType: (json['mealType'] as String? ?? 'lunch').toLowerCase(),
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        estimatedPricePhp: (json['estimatedPricePhp'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
        fat: (json['fat'] as num?)?.toInt() ?? 0,
        ingredients: List<String>.from(json['ingredients'] as List? ?? []),
        dietLabels: List<String>.from(json['dietLabels'] as List? ?? []),
        healthLabels: List<String>.from(json['healthLabels'] as List? ?? []),
        cookingSteps: List<String>.from(json['cookingSteps'] as List? ?? []),
        imageUrl: json['imageUrl'] as String?,
        source: json['source'] as String? ?? '',
        ingredientLines: List<String>.from(json['ingredients'] as List? ?? []),
        mealTypes: [(json['mealType'] as String? ?? 'lunch').toLowerCase()],
        sourceType: json['sourceType'] as String? ?? 'prototype_sample_asset',
        isPrototypeDataset: json['isPrototypeDataset'] as bool? ?? true,
        dataNotice: json['dataNotice'] as String? ??
            'Prototype recipe dataset for academic/non-production use.',
      );

  factory RecipeModel.fromApiJson(Map<String, dynamic> json) {
    final ingredientLines = _stringListFromAny(json['ingredient_lines']);
    final ingredientTexts = _ingredientTextsFromAny(json['ingredients']);
    final mealTypes = _stringListFromAny(json['meal_type']);
    final cuisineTypes = _stringListFromAny(json['cuisine_type']);
    final dishTypes = _stringListFromAny(json['dish_type']);
    final servings = _intFromAnyOrNull(json['servings'] ?? json['yield']);

    return RecipeModel(
      id: (json['recipe_id'] as String? ?? json['id'] as String? ?? '').trim(),
      name: (json['recipe_name'] as String? ??
              json['name'] as String? ??
              'Untitled Recipe')
          .trim(),
      description: '',
      mealType: mealTypes.isNotEmpty ? mealTypes.first : 'lunch',
      calories: _nutritionIntFromApi(
        json,
        directKeys: const ['calories'],
        nutrientKeys: const ['ENERC_KCAL'],
        servings: servings,
      ),
      estimatedPricePhp: _priceFromApi(json, servings),
      protein: _nutritionIntFromApi(
        json,
        directKeys: const ['protein', 'proteinGrams'],
        nutrientKeys: const ['PROCNT'],
        servings: servings,
      ),
      carbs: _nutritionIntFromApi(
        json,
        directKeys: const ['carbs', 'carbohydrates', 'carbsGrams'],
        nutrientKeys: const ['CHOCDF', 'CHOCDF.net'],
        servings: servings,
      ),
      fat: _nutritionIntFromApi(
        json,
        directKeys: const ['fat', 'fatGrams'],
        nutrientKeys: const ['FAT'],
        servings: servings,
      ),
      ingredients:
          ingredientTexts.isNotEmpty ? ingredientTexts : ingredientLines,
      dietLabels: _stringListFromAny(json['diet_labels']),
      healthLabels: _stringListFromAny(json['health_labels']),
      cookingSteps: const [],
      imageUrl: _stringFromAny(json['image']),
      source: _stringFromAny(json['source']) ?? '',
      ingredientLines:
          ingredientLines.isNotEmpty ? ingredientLines : ingredientTexts,
      cuisineTypes: cuisineTypes,
      mealTypes: mealTypes,
      dishTypes: dishTypes,
      servings: servings,
      url: _stringFromAny(json['url']),
      sourceType:
          _stringFromAny(json['sourceType'] ?? json['source_type']) ?? '',
      isPrototypeDataset: json['isPrototypeDataset'] == true ||
          json['is_prototype_dataset'] == true,
      dataNotice:
          _stringFromAny(json['dataNotice'] ?? json['data_notice']) ?? '',
    );
  }

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
        'ingredientLines': ingredientLines,
        'cuisineTypes': cuisineTypes,
        'mealTypes': mealTypes,
        'dishTypes': dishTypes,
        'servings': servings,
        'url': url,
        'sourceType': sourceType,
        'isPrototypeDataset': isPrototypeDataset,
        'dataNotice': dataNotice,
      };

  String get recipeId => id;
  String get recipeName => name;
  String? get image => imageUrl;
  List<String> get displayIngredientLines =>
      ingredientLines.isNotEmpty ? ingredientLines : ingredients;
  bool get hasPriceEstimate => estimatedPricePhp > 0;
  bool get hasMacroData => protein > 0 || carbs > 0 || fat > 0;

  String get mealTypeDisplay {
    if (mealTypes.isNotEmpty) return _labelize(mealTypes.first);
    return mealTypeLabel;
  }

  String get cuisineTypeDisplay =>
      cuisineTypes.isNotEmpty ? _labelize(cuisineTypes.first) : 'Any cuisine';

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
        return _labelize(mealType);
    }
  }

  String get mealEmoji {
    switch (mealType) {
      case 'breakfast':
        return '\u{1F305}';
      case 'lunch':
        return '\u{1F371}';
      case 'dinner':
        return '\u{1F37D}\u{FE0F}';
      case 'snack':
        return '\u{1F34C}';
      default:
        return '\u{1F37D}\u{FE0F}';
    }
  }

  static List<String> _stringListFromAny(dynamic value) {
    if (value is List) {
      return value
          .map(_stringFromAny)
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    final text = _stringFromAny(value);
    return text == null || text.isEmpty ? const [] : [text];
  }

  static List<String> _ingredientTextsFromAny(dynamic value) {
    if (value is! List) return const [];
    final lines = <String>[];
    for (final item in value) {
      if (item is Map<String, dynamic>) {
        final text =
            _stringFromAny(item['text']) ?? _stringFromAny(item['food']) ?? '';
        if (text.isNotEmpty) lines.add(text);
      } else {
        final text = _stringFromAny(item) ?? '';
        if (text.isNotEmpty) lines.add(text);
      }
    }
    return lines;
  }

  static String? _stringFromAny(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double _doubleFromAny(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return num.tryParse(value)?.toDouble() ?? 0;
    return 0;
  }

  static int _nutritionIntFromApi(
    Map<String, dynamic> json, {
    required List<String> directKeys,
    required List<String> nutrientKeys,
    required int? servings,
  }) {
    for (final key in directKeys) {
      final value = _doubleFromAny(json[key]);
      if (value > 0) return _perServing(value, servings).round();
    }

    final nutrients = json['total_nutrients'] ?? json['totalNutrients'];
    if (nutrients is Map) {
      for (final key in nutrientKeys) {
        final value = nutrients[key];
        if (value is Map) {
          final quantity = _doubleFromAny(value['quantity']);
          if (quantity > 0) return _perServing(quantity, servings).round();
        }
      }
    }

    return 0;
  }

  static double _priceFromApi(Map<String, dynamic> json, int? servings) {
    const perServingKeys = [
      'estimatedPricePhpPerServing',
      'estimated_price_php_per_serving',
      'pricePhpPerServing',
    ];
    for (final key in perServingKeys) {
      final value = _doubleFromAny(json[key]);
      if (value > 0) return value;
    }

    const totalKeys = [
      'estimatedPricePhp',
      'estimated_price_php',
      'pricePhp',
      'price_php',
    ];
    for (final key in totalKeys) {
      final value = _doubleFromAny(json[key]);
      if (value > 0) return _perServing(value, servings);
    }
    return 0;
  }

  static double _perServing(double value, int? servings) {
    if (servings == null || servings <= 0) return value;
    return value / servings;
  }

  static int? _intFromAnyOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.round();
    if (value is String) return num.tryParse(value)?.round();
    return null;
  }

  static String _labelize(String raw) {
    if (raw.trim().isEmpty) return raw;
    return raw
        .split('/')
        .map(
          (part) => part
              .trim()
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .map(
                (word) => word.length == 1
                    ? word.toUpperCase()
                    : '${word[0].toUpperCase()}${word.substring(1)}',
              )
              .join(' '),
        )
        .join(' / ');
  }
}
