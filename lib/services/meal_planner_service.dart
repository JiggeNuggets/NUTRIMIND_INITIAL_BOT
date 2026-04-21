import 'dart:math';

import '../data/meal_planner_food_data.dart';
import '../models/meal_planner_models.dart';

/// Core meal planning logic ported from `streamlit_meal_planner.py` + `main.py`.
class MealPlannerService {
  MealPlannerService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Mifflin–St Jeor BMR (same formula as Streamlit). [weightKg], [heightCm], [age].
  static double calculateBmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required bool isMale,
  }) {
    final base = 9.99 * weightKg + 6.25 * heightCm - 4.92 * age;
    return isMale ? base + 5 : base - 161;
  }

  static double lbToKg(double lb) => lb * 0.45359237;

  static double imperialHeightToCm({required int feet, required int inches}) =>
      (feet * 12 + inches) * 2.54;

  /// Build daily plan: breakfast 50%, lunch ⅓, dinner ⅙ of BMR (original split).
  DailyMealPlan buildDailyPlan(MealPlannerInput input) {
    final bmr = calculateBmr(
      weightKg: input.weightKg,
      heightCm: input.heightCm,
      age: input.age,
      isMale: input.isMale,
    );

    final excluded = _normalizeExcludedGroups(input.excludedGroups);

    var breakfastData = _filterGroups(MealPlannerFoodData.breakfast, excluded);
    breakfastData = _applyBreakfastPreferences(
      breakfastData,
      input.preferredBreakfastGroups,
    );
    breakfastData =
        _expandWithFood101(breakfastData, PlannerMealSlot.breakfast);

    final lunchData = _filterGroups(MealPlannerFoodData.lunch, excluded);
    final dinnerData = _filterGroups(MealPlannerFoodData.dinner, excluded);

    final lunchDataExpanded =
        _expandWithFood101(lunchData, PlannerMealSlot.lunch);
    final dinnerDataExpanded =
        _expandWithFood101(dinnerData, PlannerMealSlot.dinner);

    final bTarget = bmr * PlannerMealSlot.breakfast.calorieFractionOfBmr();
    final lTarget = bmr * PlannerMealSlot.lunch.calorieFractionOfBmr();
    final dTarget = bmr * PlannerMealSlot.dinner.calorieFractionOfBmr();

    final bCal = bTarget.round().clamp(1, 100000);
    final lCal = lTarget.round().clamp(1, 100000);
    final dCal = dTarget.round().clamp(1, 100000);

    MealBasket buildBasket(
      PlannerMealSlot slot,
      Map<String, Map<String, int>> data,
      int target,
    ) {
      if (input.algorithm == MealPlannerAlgorithm.randomGreedy) {
        return _randomGreedy(slot, data, target.toDouble());
      }
      final (items, total) = knapsack(target, data);
      return MealBasket(
        slot: slot,
        items: items,
        totalCalories: total,
        targetCalories: switch (slot) {
          PlannerMealSlot.breakfast => bTarget,
          PlannerMealSlot.lunch => lTarget,
          PlannerMealSlot.dinner => dTarget,
        },
      );
    }

    return DailyMealPlan(
      bmr: bmr,
      breakfast: buildBasket(PlannerMealSlot.breakfast, breakfastData, bCal),
      lunch: buildBasket(PlannerMealSlot.lunch, lunchDataExpanded, lCal),
      dinner: buildBasket(PlannerMealSlot.dinner, dinnerDataExpanded, dCal),
    );
  }

  Set<String> _normalizeExcludedGroups(List<String> raw) {
    final s = raw.toSet();
    // Dinner uses `proteins`; breakfast/lunch use `protein` — treat as linked.
    if (s.contains('protein')) s.add('proteins');
    if (s.contains('proteins')) s.add('protein');
    return s;
  }

  Map<String, Map<String, int>> _filterGroups(
    Map<String, Map<String, int>> source,
    Set<String> excluded,
  ) {
    final out = <String, Map<String, int>>{};
    for (final e in source.entries) {
      if (excluded.contains(e.key)) continue;
      if (e.value.isEmpty) continue;
      out[e.key] = Map<String, int>.from(e.value);
    }
    return out;
  }

  Map<String, Map<String, int>> _applyBreakfastPreferences(
    Map<String, Map<String, int>> breakfast,
    List<String> preferred,
  ) {
    if (preferred.isEmpty) return breakfast;
    final out = <String, Map<String, int>>{};
    for (final key in preferred) {
      final m = breakfast[key];
      if (m != null && m.isNotEmpty) out[key] = m;
    }
    return out.isEmpty ? breakfast : out;
  }

  /// Expand meal data with Food-101 categories for more variety
  Map<String, Map<String, int>> _expandWithFood101(
    Map<String, Map<String, int>> mealData,
    PlannerMealSlot slot,
  ) {
    final expanded = Map<String, Map<String, int>>.from(mealData);

    // Add Food-101 categories that are appropriate for each meal slot
    final food101Items = <String, int>{};

    // Categorize Food-101 items by meal appropriateness
    final breakfastFoods = [
      'pancakes',
      'waffles',
      'french_toast',
      'eggs_benedict',
      'breakfast_burrito',
      'huevos_rancheros',
      'oatmeal',
      'cereal',
      'yogurt',
      'fruit',
      'juice'
    ];

    final lunchFoods = [
      'sandwich',
      'salad',
      'soup',
      'wrap',
      'burger',
      'pizza',
      'pasta',
      'rice',
      'noodles',
      'curry',
      'stir_fry',
      'grilled',
      'chicken',
      'fish'
    ];

    final dinnerFoods = [
      'steak',
      'chicken',
      'fish',
      'pasta',
      'rice',
      'curry',
      'soup',
      'roast',
      'grilled',
      'fried',
      'baked',
      'casserole',
      'pie',
      'cake',
      'dessert'
    ];

    // Filter Food-101 items based on meal slot
    final relevantKeywords = switch (slot) {
      PlannerMealSlot.breakfast => breakfastFoods,
      PlannerMealSlot.lunch => lunchFoods,
      PlannerMealSlot.dinner => dinnerFoods,
    };

    for (final entry in MealPlannerFoodData.food101Categories.entries) {
      final foodName = entry.key;
      final calories = entry.value;

      // Check if this food is relevant for the current meal slot
      final isRelevant =
          relevantKeywords.any((keyword) => foodName.contains(keyword));

      if (isRelevant) {
        food101Items[foodName] = calories;
      }
    }

    // Add Food-101 items as a new category
    if (food101Items.isNotEmpty) {
      expanded['food101_specialties'] = food101Items;
    }

    return expanded;
  }

  /// 0/1 knapsack: maximize calories without exceeding [targetCalories].
  /// Returns selected item ids and total calories (same DP as Python).
  (List<String> items, int total) knapsack(
    int targetCalories,
    Map<String, Map<String, int>> foodGroups,
  ) {
    if (targetCalories <= 0) return (<String>[], 0);

    final items = <(int cal, String name)>[];
    for (final foods in foodGroups.values) {
      for (final e in foods.entries) {
        items.add((e.value, e.key));
      }
    }
    if (items.isEmpty) return (<String>[], 0);

    final n = items.length;
    final dp = List.generate(
      n + 1,
      (_) => List<int>.filled(targetCalories + 1, 0),
    );

    for (var i = 1; i <= n; i++) {
      final value = items[i - 1].$1;
      for (var j = 0; j <= targetCalories; j++) {
        if (value > j) {
          dp[i][j] = dp[i - 1][j];
        } else {
          final take = dp[i - 1][j - value] + value;
          dp[i][j] = max(dp[i - 1][j], take);
        }
      }
    }

    final selected = <String>[];
    var j = targetCalories;
    for (var i = n; i > 0; i--) {
      if (dp[i][j] != dp[i - 1][j]) {
        selected.add(items[i - 1].$2);
        j -= items[i - 1].$1;
      }
    }

    return (selected, dp[n][targetCalories]);
  }

  /// Random greedy from `generate_items_list` / `select_breakfast` in Python.
  MealBasket _randomGreedy(
    PlannerMealSlot slot,
    Map<String, Map<String, int>> foodGroups,
    double targetCalories,
  ) {
    var calories = 0;
    final selected = <String>[];
    final totalItems = <String>{};
    for (final foods in foodGroups.values) {
      totalItems.addAll(foods.keys);
    }

    final groupKeys = foodGroups.keys.toList();
    if (groupKeys.isEmpty) {
      return MealBasket(
        slot: slot,
        items: [],
        totalCalories: 0,
        targetCalories: targetCalories,
      );
    }

    var guard = 0;
    while ((calories - targetCalories).abs() >= 10 &&
        selected.length < totalItems.length &&
        guard < 500) {
      guard++;
      final group = groupKeys[_random.nextInt(groupKeys.length)];
      final foods = foodGroups[group]!;
      if (foods.isEmpty) continue;
      final keys = foods.keys.toList();
      final item = keys[_random.nextInt(keys.length)];
      if (selected.contains(item)) continue;
      final cals = foods[item]!;
      if (calories + cals <= targetCalories) {
        selected.add(item);
        calories += cals;
      }
    }

    return MealBasket(
      slot: slot,
      items: selected,
      totalCalories: calories,
      targetCalories: targetCalories,
    );
  }
}
