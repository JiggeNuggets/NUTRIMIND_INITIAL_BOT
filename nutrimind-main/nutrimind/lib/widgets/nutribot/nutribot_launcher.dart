import 'package:flutter/material.dart';

import '../../models/meal_model.dart';
import '../../models/nutribot_models.dart';
import '../../models/recipe_model.dart';
import '../../models/user_model.dart';
import '../../screens/main/nutribot_screen.dart';
import '../../theme/modern_app_theme.dart';

class NutribotLauncher {
  const NutribotLauncher._();

  static Future<T?> open<T>(
    BuildContext context, {
    NutribotContext? nutribotContext,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => NutribotScreen(nutribotContext: nutribotContext),
      ),
    );
  }
}

class NutribotFab extends StatelessWidget {
  const NutribotFab({
    super.key,
    this.nutribotContext,
    this.onPressed,
    this.heroTag = 'nutribot_fab',
    this.tooltip = 'Ask NutriBot',
    this.mini = false,
  });

  final NutribotContext? nutribotContext;
  final VoidCallback? onPressed;
  final Object heroTag;
  final String tooltip;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed ??
          () => NutribotLauncher.open(
                context,
                nutribotContext: nutribotContext,
              ),
      backgroundColor: ModernAppTheme.primaryGreen,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      elevation: 8,
      tooltip: tooltip,
      mini: mini,
      child: Icon(Icons.smart_toy_outlined, size: mini ? 22 : 26),
    );
  }
}

class NutribotAppBarAction extends StatelessWidget {
  const NutribotAppBarAction({
    super.key,
    this.nutribotContext,
    this.onPressed,
    this.tooltip = 'Ask NutriBot',
  });

  final NutribotContext? nutribotContext;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.smart_toy_outlined),
      onPressed: onPressed ??
          () => NutribotLauncher.open(
                context,
                nutribotContext: nutribotContext,
              ),
    );
  }
}

class NutribotPayloads {
  const NutribotPayloads._();

  static Map<String, dynamic> meal(MealModel meal) {
    return {
      'id': meal.id,
      'name': meal.name,
      'type': meal.typeLabel,
      'status': meal.statusLabel,
      'pricePhp': meal.price,
      'calories': meal.calories,
      'protein': meal.protein,
      'carbs': meal.carbs,
      'fat': meal.fat,
      if (meal.ingredients.isNotEmpty) 'ingredients': meal.ingredients,
      if (meal.notes?.trim().isNotEmpty ?? false) 'notes': meal.notes!.trim(),
      if (meal.recipe?.trim().isNotEmpty ?? false)
        'recipe': meal.recipe!.trim(),
      if (meal.cookingSteps.isNotEmpty) 'cookingSteps': meal.cookingSteps,
      'date': _dateOnly(meal.date),
    };
  }

  static Map<String, dynamic> mealLogSummary({
    required DateTime selectedDate,
    required List<MealModel> meals,
  }) {
    return {
      'selectedDate': _dateOnly(selectedDate),
      'mealCount': meals.length,
      'loggedCount':
          meals.where((meal) => meal.status == MealStatus.logged).length,
      'totalCalories': meals.fold<int>(0, (sum, meal) => sum + meal.calories),
      'totalSpentPhp': meals.fold<double>(0, (sum, meal) => sum + meal.price),
      if (meals.isNotEmpty) 'meals': meals.take(4).map(meal).toList(),
    };
  }

  static Map<String, dynamic> recipe(RecipeModel recipe) {
    return {
      'id': recipe.id,
      'name': recipe.name,
      'mealType': recipe.mealTypeLabel,
      'calories': recipe.calories,
      if (recipe.hasPriceEstimate)
        'estimatedPricePhp': recipe.estimatedPricePhp,
      if (recipe.protein > 0) 'protein': recipe.protein,
      if (recipe.carbs > 0) 'carbs': recipe.carbs,
      if (recipe.fat > 0) 'fat': recipe.fat,
      if (recipe.dataNotice.trim().isNotEmpty)
        'dataNotice': recipe.dataNotice.trim(),
      if (recipe.description.trim().isNotEmpty)
        'description': recipe.description.trim(),
      if (recipe.ingredients.isNotEmpty) 'ingredients': recipe.ingredients,
      if (recipe.dietLabels.isNotEmpty) 'dietLabels': recipe.dietLabels,
      if (recipe.healthLabels.isNotEmpty) 'healthLabels': recipe.healthLabels,
      if (recipe.source.trim().isNotEmpty) 'source': recipe.source.trim(),
    };
  }

  static Map<String, dynamic> profile(UserModel user) {
    return {
      'name': user.name,
      'goal': user.goal,
      'location': user.location,
      'dailyBudgetPhp': user.dailyBudget,
      'budgetBufferPct': user.budgetBuffer,
      'allowNonLocal': user.allowNonLocal,
      'heightCm': user.height,
      'weightKg': user.weight,
      'age': user.age,
      'gender': user.gender,
    };
  }

  static Map<String, dynamic> communityDraft({
    required String category,
    String? content,
    List<String> tags = const [],
  }) {
    return {
      'category': category,
      if (content != null && content.trim().isNotEmpty)
        'draftContent': content.trim(),
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  static String _dateOnly(DateTime value) =>
      value.toIso8601String().split('T').first;
}
