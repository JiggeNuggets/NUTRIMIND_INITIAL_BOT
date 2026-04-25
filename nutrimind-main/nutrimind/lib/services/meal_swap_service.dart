import '../data/meal_planner_food_data.dart';
import '../models/meal_model.dart';

enum MealSwapOptionType {
  cheaper,
  higherProtein,
  lowerCalorie,
}

extension MealSwapOptionTypeX on MealSwapOptionType {
  String get label => switch (this) {
        MealSwapOptionType.cheaper => 'Cheaper Option',
        MealSwapOptionType.higherProtein => 'Higher Protein Option',
        MealSwapOptionType.lowerCalorie => 'Lower Calorie Option',
      };
}

class MealSwapOption {
  const MealSwapOption({
    required this.type,
    required this.reason,
    this.food,
  });

  final MealSwapOptionType type;
  final String reason;
  final LocalMealPlannerFood? food;

  bool get isAvailable => food != null;
}

class MealSwapService {
  MealSwapService._();

  static List<MealSwapOption> buildOptions(
    MealModel meal, {
    String? userGoal,
  }) {
    final candidates = MealPlannerFoodData.getFoodsByMealType(meal.type.name)
        .where((food) => _isUsableCandidate(food, meal))
        .toList(growable: false);
    final usedFoodIds = <String>{};

    final cheaper = _cheaperOption(meal, candidates, usedFoodIds);
    if (cheaper.food != null) usedFoodIds.add(cheaper.food!.id);

    final higherProtein = _higherProteinOption(meal, candidates, usedFoodIds);
    if (higherProtein.food != null) usedFoodIds.add(higherProtein.food!.id);

    final lowerCalorie =
        _lowerCalorieOption(meal, candidates, usedFoodIds, userGoal);

    return [cheaper, higherProtein, lowerCalorie];
  }

  static String replacementNotes(MealModel original, MealSwapOption option) {
    final food = option.food;
    final lines = [
      'Swapped from "${original.name}" using NutriMind Meal Swap.',
      'Reason: ${option.reason}',
      'Dataset disclosure: local prices and macros are prototype estimates, not live market prices.',
      if (food != null && food.source.trim().isNotEmpty)
        'Source: ${food.source}',
      if (food != null && food.sourceType.trim().isNotEmpty)
        'Source type: ${food.sourceType}',
      if (food != null && food.lastVerifiedDate != null)
        'Last verified: ${food.lastVerifiedDate}',
      if (food != null && food.healthNote.trim().isNotEmpty)
        'Note: ${food.healthNote}',
    ];
    return lines.join('\n');
  }

  static bool _isUsableCandidate(LocalMealPlannerFood food, MealModel meal) {
    if (food.mealType != meal.type.name) return false;
    if (food.estimatedPricePhp <= 0 || food.calories <= 0) return false;
    return _normalize(food.name) != _normalize(meal.name);
  }

  static MealSwapOption _cheaperOption(
    MealModel meal,
    List<LocalMealPlannerFood> candidates,
    Set<String> usedFoodIds,
  ) {
    if (meal.price <= 0) {
      return const MealSwapOption(
        type: MealSwapOptionType.cheaper,
        reason: 'Current meal has no price to compare.',
      );
    }

    final matches = candidates
        .where(
          (food) =>
              !usedFoodIds.contains(food.id) &&
              food.estimatedPricePhp < meal.price,
        )
        .toList()
      ..sort((a, b) => a.estimatedPricePhp.compareTo(b.estimatedPricePhp));

    if (matches.isEmpty) {
      return const MealSwapOption(
        type: MealSwapOptionType.cheaper,
        reason: 'No cheaper dataset option found for this meal type.',
      );
    }

    final food = matches.first;
    final savings = meal.price - food.estimatedPricePhp;
    return MealSwapOption(
      type: MealSwapOptionType.cheaper,
      food: food,
      reason: 'PHP ${savings.toStringAsFixed(0)} cheaper',
    );
  }

  static MealSwapOption _higherProteinOption(
    MealModel meal,
    List<LocalMealPlannerFood> candidates,
    Set<String> usedFoodIds,
  ) {
    final matches = candidates
        .where((food) =>
            !usedFoodIds.contains(food.id) &&
            food.protein > 0 &&
            (meal.protein <= 0 || food.protein > meal.protein))
        .toList()
      ..sort((a, b) {
        final proteinCompare = b.protein.compareTo(a.protein);
        if (proteinCompare != 0) return proteinCompare;
        return a.estimatedPricePhp.compareTo(b.estimatedPricePhp);
      });

    if (matches.isEmpty) {
      return const MealSwapOption(
        type: MealSwapOptionType.higherProtein,
        reason: 'No higher-protein dataset option found for this meal type.',
      );
    }

    final food = matches.first;
    final reason = meal.protein > 0
        ? 'Higher protein (+${food.protein - meal.protein}g)'
        : 'Estimated ${food.protein}g protein';
    return MealSwapOption(
      type: MealSwapOptionType.higherProtein,
      food: food,
      reason: reason,
    );
  }

  static MealSwapOption _lowerCalorieOption(
    MealModel meal,
    List<LocalMealPlannerFood> candidates,
    Set<String> usedFoodIds,
    String? userGoal,
  ) {
    if (meal.calories <= 0) {
      return const MealSwapOption(
        type: MealSwapOptionType.lowerCalorie,
        reason: 'Current meal has no calories to compare.',
      );
    }

    final matches = candidates
        .where(
          (food) =>
              !usedFoodIds.contains(food.id) && food.calories < meal.calories,
        )
        .toList()
      ..sort((a, b) => a.calories.compareTo(b.calories));

    if (matches.isEmpty) {
      return const MealSwapOption(
        type: MealSwapOptionType.lowerCalorie,
        reason: 'No lower-calorie dataset option found for this meal type.',
      );
    }

    final food = matches.first;
    final calorieDrop = meal.calories - food.calories;
    final goalText = (userGoal ?? '').toLowerCase();
    final isWeightLossGoal =
        goalText.contains('loss') || goalText.contains('lose');
    return MealSwapOption(
      type: MealSwapOptionType.lowerCalorie,
      food: food,
      reason: isWeightLossGoal
          ? 'Better for weight loss goal ($calorieDrop kcal lower)'
          : '$calorieDrop kcal lower',
    );
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }
}
