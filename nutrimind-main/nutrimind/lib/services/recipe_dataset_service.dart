import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/recipe_model.dart';

/// Loads the local Hugging Face recipe sample dataset from bundled assets.
///
/// Source dataset reference: datahiveai/recipes-with-nutrition on Hugging Face,
/// licensed CC BY-NC 4.0. NutriMind uses this local sample for academic
/// prototype / non-commercial use only.
class RecipeDatasetService {
  RecipeDatasetService({this.assetPath = _defaultAssetPath});

  static const String _defaultAssetPath =
      'assets/data/recipes_nutrition_sample.json';
  static const String prototypeDisclosure =
      'Prototype recipe dataset: academic/non-production sample data. '
      'Use a verified recipe API or Firestore recipes collection for production.';

  final String assetPath;

  List<RecipeModel>? _cache;
  String? _lastError;

  String? get lastError => _lastError;

  void clearCache() {
    _cache = null;
    _lastError = null;
  }

  Future<List<RecipeModel>> getAllRecipes() => _loadRecipes();

  Future<List<RecipeModel>> getRecipesByMealType(String mealType) async {
    final normalized = mealType.toLowerCase().trim();
    final recipes = await _loadRecipes();
    if (normalized.isEmpty || normalized == 'all') return recipes;
    return recipes
        .where((recipe) => recipe.mealType.toLowerCase() == normalized)
        .toList(growable: false);
  }

  Future<List<RecipeModel>> getRecipesUnderCalories(num maxCalories) async {
    final recipes = await _loadRecipes();
    return recipes
        .where((recipe) => recipe.calories <= maxCalories)
        .toList(growable: false);
  }

  Future<List<RecipeModel>> getBudgetFriendlyRecipes(num maxPricePhp) async {
    final recipes = await _loadRecipes();
    return recipes
        .where((recipe) => recipe.estimatedPricePhp <= maxPricePhp)
        .toList(growable: false);
  }

  Future<List<RecipeModel>> searchRecipes(String query) async {
    final normalized = query.toLowerCase().trim();
    final recipes = await _loadRecipes();
    if (normalized.isEmpty) return recipes;

    return recipes.where((recipe) {
      final searchable = [
        recipe.name,
        recipe.description,
        recipe.mealType,
        ...recipe.ingredients,
        ...recipe.dietLabels,
        ...recipe.healthLabels,
      ].join(' ').toLowerCase();
      return searchable.contains(normalized);
    }).toList(growable: false);
  }

  Future<List<RecipeModel>> getHighProteinRecipes() async {
    final recipes = await _loadRecipes();
    return recipes
        .where((recipe) => recipe.protein >= 20)
        .toList(growable: false);
  }

  Future<List<RecipeModel>> filterRecipes({
    String mealType = 'all',
    num? maxCalories,
    num? maxPricePhp,
    String query = '',
    Set<String> dietLabels = const {},
    Set<String> healthLabels = const {},
  }) async {
    final normalizedMealType = mealType.toLowerCase().trim();
    final normalizedQuery = query.toLowerCase().trim();
    final normalizedDietLabels =
        dietLabels.map((label) => label.toLowerCase()).toSet();
    final normalizedHealthLabels =
        healthLabels.map((label) => label.toLowerCase()).toSet();

    final recipes = await _loadRecipes();
    return recipes.where((recipe) {
      if (normalizedMealType.isNotEmpty &&
          normalizedMealType != 'all' &&
          recipe.mealType.toLowerCase() != normalizedMealType) {
        return false;
      }

      if (maxCalories != null && recipe.calories > maxCalories) return false;
      if (maxPricePhp != null && recipe.estimatedPricePhp > maxPricePhp) {
        return false;
      }

      final recipeDietLabels =
          recipe.dietLabels.map((label) => label.toLowerCase()).toSet();
      final recipeHealthLabels =
          recipe.healthLabels.map((label) => label.toLowerCase()).toSet();

      if (normalizedDietLabels.isNotEmpty &&
          !normalizedDietLabels.every(recipeDietLabels.contains)) {
        return false;
      }
      if (normalizedHealthLabels.isNotEmpty &&
          !normalizedHealthLabels.every(recipeHealthLabels.contains)) {
        return false;
      }

      if (normalizedQuery.isEmpty) return true;

      final searchable = [
        recipe.name,
        recipe.description,
        recipe.mealType,
        ...recipe.ingredients,
        ...recipe.dietLabels,
        ...recipe.healthLabels,
      ].join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList(growable: false);
  }

  Future<List<RecipeModel>> _loadRecipes() async {
    final cached = _cache;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      final rows = switch (decoded) {
        final List<dynamic> list => list,
        final Map<String, dynamic> map when map['recipes'] is List<dynamic> =>
          map['recipes'] as List<dynamic>,
        _ => null,
      };

      if (rows == null) {
        _lastError = 'Recipe dataset format is not recognized.';
        _cache = const <RecipeModel>[];
        return _cache!;
      }

      final recipes = <RecipeModel>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        try {
          recipes.add(RecipeModel.fromJson(row));
        } catch (_) {
          // Skip malformed rows so one bad entry does not break the app.
        }
      }

      _lastError = rows.isNotEmpty && recipes.isEmpty
          ? 'Recipe dataset loaded, but no valid recipes were found.'
          : null;
      _cache = List<RecipeModel>.unmodifiable(recipes);
      return _cache!;
    } catch (e) {
      _lastError =
          'Recipe dataset could not be loaded. Please check the bundled asset.';
      _cache = const <RecipeModel>[];
      return _cache!;
    }
  }
}
