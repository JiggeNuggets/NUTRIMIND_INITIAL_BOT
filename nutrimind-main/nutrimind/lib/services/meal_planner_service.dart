import 'dart:math';

import '../data/meal_planner_food_data.dart';
import '../models/meal_planner_models.dart';

/// Core meal planning logic ported from the Python prototype.
///
/// The local Davao foods are prototype estimates, not live market prices.
/// Production planning should load verified Firestore `local_foods` and
/// `market_prices` records with source/date metadata before relying on costs.
class MealPlannerService {
  MealPlannerService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Mifflin-St Jeor BMR. [weightKg], [heightCm], and [age] are metric.
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

  /// Build daily plan: breakfast 35%, lunch 30%, dinner 25%, snack 10% of BMR.
  DailyMealPlan buildDailyPlan(MealPlannerInput input) {
    final bmr = calculateBmr(
      weightKg: input.weightKg,
      heightCm: input.heightCm,
      age: input.age,
      isMale: input.isMale,
    );

    final excluded = _normalizeExcludedGroups(input.excludedGroups);
    if (input.dailyBudgetPhp <= 0) {
      throw ArgumentError('Daily budget must be set before planning meals.');
    }
    final dailyBudget = input.dailyBudgetPhp;
    final budgetMultiplier = 1 + (max(0, input.budgetBufferPct) / 100);

    final targets = {
      PlannerMealSlot.breakfast:
          bmr * PlannerMealSlot.breakfast.calorieFractionOfBmr(),
      PlannerMealSlot.lunch: bmr * PlannerMealSlot.lunch.calorieFractionOfBmr(),
      PlannerMealSlot.dinner:
          bmr * PlannerMealSlot.dinner.calorieFractionOfBmr(),
      PlannerMealSlot.snack: bmr * PlannerMealSlot.snack.calorieFractionOfBmr(),
    };

    MealBasket buildBasket(PlannerMealSlot slot) {
      final target = targets[slot] ?? 0;
      final targetCalories = target.round().clamp(1, 100000).toInt();
      final targetBudget =
          dailyBudget * slot.calorieFractionOfBmr() * budgetMultiplier;
      final localCandidates = _localCandidates(
        slot: slot,
        input: input,
        excluded: excluded,
      );

      final localSelection =
          input.algorithm == MealPlannerAlgorithm.randomGreedy
              ? _randomGreedyCandidates(
                  localCandidates,
                  targetCalories,
                  targetBudget,
                )
              : _budgetAwareKnapsack(
                  localCandidates,
                  targetCalories,
                  targetBudget,
                );

      var selectedItems = List<PlannerFoodItem>.from(localSelection.items);
      final localEnough = localSelection.totalCalories >= targetCalories * 0.72;

      if (!localEnough && input.allowCalorieOnlyFallback) {
        final remainingTarget = (targetCalories - localSelection.totalCalories)
            .clamp(1, 100000)
            .toInt();
        final fallbackSelection = _calorieOnlyFallbackKnapsack(
          _fallbackCandidates(slot, excluded),
          remainingTarget,
          maxItems: localSelection.items.isEmpty ? 3 : 2,
        );
        selectedItems = [
          ...selectedItems,
          ...fallbackSelection.items,
        ];
      }

      return MealBasket(
        slot: slot,
        items: selectedItems,
        totalCalories: _sumCalories(selectedItems),
        targetCalories: target,
      );
    }

    return DailyMealPlan(
      bmr: bmr,
      breakfast: buildBasket(PlannerMealSlot.breakfast),
      lunch: buildBasket(PlannerMealSlot.lunch),
      dinner: buildBasket(PlannerMealSlot.dinner),
      snack: buildBasket(PlannerMealSlot.snack),
    );
  }

  Set<String> _normalizeExcludedGroups(List<String> raw) {
    final s = raw.map(_normalizeKey).toSet();
    // Dinner uses `proteins`; breakfast/lunch use `protein`; treat as linked.
    if (s.contains('protein')) s.add('proteins');
    if (s.contains('proteins')) s.add('protein');
    return s;
  }

  List<PlannerFoodItem> _localCandidates({
    required PlannerMealSlot slot,
    required MealPlannerInput input,
    required Set<String> excluded,
  }) {
    final foods = MealPlannerFoodData.getFoodsByMealType(slot.name)
        .where((food) => !_isExcludedLocalFood(food, excluded))
        .toList();

    final filtered = slot == PlannerMealSlot.breakfast
        ? _applyLocalBreakfastPreferences(
            foods,
            input.preferredBreakfastGroups,
          )
        : foods;

    filtered.sort((a, b) {
      final priceCompare = a.estimatedPricePhp.compareTo(b.estimatedPricePhp);
      if (priceCompare != 0) return priceCompare;
      return b.protein.compareTo(a.protein);
    });

    return filtered.map(_localFoodToPlannerItem).toList(growable: false);
  }

  bool _isExcludedLocalFood(
    LocalMealPlannerFood food,
    Set<String> excluded,
  ) {
    if (excluded.isEmpty) return false;
    final id = _normalizeKey(food.id);
    final category = _normalizeKey(food.category);
    final mealType = _normalizeKey(food.mealType);
    if (excluded.contains(id) ||
        excluded.contains(category) ||
        excluded.contains(mealType)) {
      return true;
    }

    if ((excluded.contains('protein') || excluded.contains('proteins')) &&
        _isProteinCategory(category)) {
      return true;
    }
    if (excluded.contains('whole_grains') &&
        const {'bakery', 'whole_grain', 'rice_meal', 'porridge', 'grain'}
            .contains(category)) {
      return true;
    }
    if (excluded.contains('fruits') && category == 'fruit') return true;
    if (excluded.contains('vegetables') &&
        const {'vegetable', 'soup'}.contains(category)) {
      return true;
    }
    if (excluded.contains('healthy_fats') &&
        const {'nuts', 'street_food'}.contains(category)) {
      return true;
    }
    if (excluded.contains('dairy') && category == 'dairy') return true;

    return false;
  }

  List<LocalMealPlannerFood> _applyLocalBreakfastPreferences(
    List<LocalMealPlannerFood> foods,
    List<String> preferred,
  ) {
    if (preferred.isEmpty) return foods;
    final normalizedPrefs = preferred.map(_normalizeKey).toSet();
    final filtered = foods.where((food) {
      final category = _normalizeKey(food.category);
      if (normalizedPrefs.contains(category)) return true;
      if (normalizedPrefs.contains('local_breakfast_meals')) return true;
      if (normalizedPrefs.contains('protein') && _isProteinCategory(category)) {
        return true;
      }
      if (normalizedPrefs.contains('whole_grains') &&
          const {'bakery', 'whole_grain', 'rice_meal', 'porridge', 'grain'}
              .contains(category)) {
        return true;
      }
      if (normalizedPrefs.contains('fruits') && category == 'fruit') {
        return true;
      }
      if (normalizedPrefs.contains('vegetables') &&
          const {'vegetable', 'soup'}.contains(category)) {
        return true;
      }
      if (normalizedPrefs.contains('healthy_fats') &&
          const {'nuts', 'fruit'}.contains(category)) {
        return true;
      }
      if (normalizedPrefs.contains('dairy') && category == 'dairy') {
        return true;
      }
      return false;
    }).toList(growable: false);

    return filtered.isEmpty ? foods : filtered;
  }

  bool _isProteinCategory(String category) {
    return const {
      'protein',
      'fish',
      'egg',
      'tofu',
      'soy',
      'legume',
      'rice_meal',
      'sandwich',
    }.contains(category);
  }

  PlannerFoodItem _localFoodToPlannerItem(LocalMealPlannerFood food) {
    return PlannerFoodItem(
      id: food.id,
      name: food.name,
      calories: food.calories,
      source: PlannerFoodSource.localDavaoFoods,
      pricePhp: food.estimatedPricePhp,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      ingredients: food.ingredients,
      mealType: food.mealType,
      category: food.category,
      servingSize: food.servingSize,
      dataSource: food.source,
      sourceType: food.sourceType,
      lastVerifiedDate: food.lastVerifiedDate,
      isPrototypeEstimate: food.isPrototypeEstimate,
    );
  }

  _BasketSelection _budgetAwareKnapsack(
    List<PlannerFoodItem> candidates,
    int targetCalories,
    double targetBudget,
  ) {
    if (targetCalories <= 0 || candidates.isEmpty) {
      return const _BasketSelection();
    }

    final budgetCapacity = max(0, targetBudget.round());
    if (budgetCapacity == 0) return const _BasketSelection();

    var states = <String, _BasketSelection>{'0:0': const _BasketSelection()};

    for (final item in candidates) {
      final price = max(1, (item.pricePhp ?? 0).round());
      if (price > budgetCapacity || item.calories > targetCalories) continue;

      final next = Map<String, _BasketSelection>.from(states);
      for (final state in states.values) {
        final newCalories = state.totalCalories + item.calories;
        final newPrice = state.roundedPrice + price;
        if (newCalories > targetCalories || newPrice > budgetCapacity) {
          continue;
        }

        final candidate = state.add(item);
        final key = '$newCalories:$newPrice';
        final existing = next[key];
        if (existing == null || _isBetterSelection(candidate, existing)) {
          next[key] = candidate;
        }
      }
      states = next;
    }

    return states.values.reduce(
      (best, current) => _isBetterSelection(current, best) ? current : best,
    );
  }

  bool _isBetterSelection(_BasketSelection a, _BasketSelection b) {
    if (a.totalCalories != b.totalCalories) {
      return a.totalCalories > b.totalCalories;
    }
    if (a.totalPricePhp != b.totalPricePhp) {
      return a.totalPricePhp < b.totalPricePhp;
    }
    if (a.totalProtein != b.totalProtein) {
      return a.totalProtein > b.totalProtein;
    }
    return a.items.length < b.items.length;
  }

  _BasketSelection _randomGreedyCandidates(
    List<PlannerFoodItem> candidates,
    int targetCalories,
    double targetBudget,
  ) {
    final shuffled = List<PlannerFoodItem>.from(candidates)..shuffle(_random);
    shuffled.sort((a, b) {
      final aValue = a.calories / max(1, a.pricePhp ?? 1);
      final bValue = b.calories / max(1, b.pricePhp ?? 1);
      return bValue.compareTo(aValue);
    });

    var selection = const _BasketSelection();
    for (final item in shuffled) {
      final nextCalories = selection.totalCalories + item.calories;
      final nextPrice = selection.totalPricePhp + (item.pricePhp ?? 0);
      if (nextCalories <= targetCalories && nextPrice <= targetBudget) {
        selection = selection.add(item);
      }
    }
    return selection;
  }

  List<PlannerFoodItem> _fallbackCandidates(
    PlannerMealSlot slot,
    Set<String> excluded,
  ) {
    final rawData = _fallbackGroupsForSlot(slot, excluded);
    final localIds =
        MealPlannerFoodData.getLocalDavaoFoods().map((food) => food.id).toSet();
    final candidates = <PlannerFoodItem>[];

    for (final group in rawData.entries) {
      for (final entry in group.value.entries) {
        if (localIds.contains(entry.key)) continue;
        candidates.add(
          PlannerFoodItem(
            id: entry.key,
            name: _formatFoodName(entry.key),
            calories: entry.value,
            source: PlannerFoodSource.calorieOnlyFallback,
            ingredients: [_formatFoodName(entry.key)],
            mealType: slot.name,
            category: group.key,
            dataSource: 'NutriMind calorie-only fallback maps',
            sourceType: 'calorie_only_fallback',
            isPrototypeEstimate: true,
          ),
        );
      }
    }

    candidates.sort((a, b) => b.calories.compareTo(a.calories));
    return candidates;
  }

  Map<String, Map<String, int>> _fallbackGroupsForSlot(
    PlannerMealSlot slot,
    Set<String> excluded,
  ) {
    final source = switch (slot) {
      PlannerMealSlot.breakfast => MealPlannerFoodData.breakfast,
      PlannerMealSlot.lunch => MealPlannerFoodData.lunch,
      PlannerMealSlot.dinner => MealPlannerFoodData.dinner,
      PlannerMealSlot.snack => MealPlannerFoodData.snack,
    };
    final filtered = _filterGroups(source, excluded);
    return _expandWithFood101(filtered, slot);
  }

  Map<String, Map<String, int>> _filterGroups(
    Map<String, Map<String, int>> source,
    Set<String> excluded,
  ) {
    final out = <String, Map<String, int>>{};
    for (final entry in source.entries) {
      if (excluded.contains(_normalizeKey(entry.key))) continue;
      if (entry.value.isEmpty) continue;
      out[entry.key] = Map<String, int>.from(entry.value);
    }
    return out;
  }

  /// Expand meal data with Food-101 categories for calorie-only fallback variety.
  Map<String, Map<String, int>> _expandWithFood101(
    Map<String, Map<String, int>> mealData,
    PlannerMealSlot slot,
  ) {
    final expanded = Map<String, Map<String, int>>.from(mealData);
    final food101Items = <String, int>{};

    const breakfastFoods = [
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
      'juice',
    ];

    const lunchFoods = [
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
      'fish',
    ];

    const dinnerFoods = [
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
      'dessert',
    ];

    const snackFoods = [
      'fruit',
      'yogurt',
      'smoothie',
      'nuts',
      'salad',
      'soup',
      'bread',
      'toast',
      'cake',
      'macarons',
      'ice_cream',
      'tiramisu',
      'panna_cotta',
      'beignets',
      'baklava',
    ];

    final relevantKeywords = switch (slot) {
      PlannerMealSlot.breakfast => breakfastFoods,
      PlannerMealSlot.lunch => lunchFoods,
      PlannerMealSlot.dinner => dinnerFoods,
      PlannerMealSlot.snack => snackFoods,
    };

    for (final entry in MealPlannerFoodData.food101Categories.entries) {
      final foodName = entry.key;
      final calories = entry.value;
      final isRelevant =
          relevantKeywords.any((keyword) => foodName.contains(keyword));

      if (isRelevant) {
        food101Items[foodName] = calories;
      }
    }

    if (food101Items.isNotEmpty) {
      expanded['food101_calorie_only_fallback'] = food101Items;
    }

    return expanded;
  }

  _BasketSelection _calorieOnlyFallbackKnapsack(
    List<PlannerFoodItem> candidates,
    int targetCalories, {
    required int maxItems,
  }) {
    if (targetCalories <= 0 || candidates.isEmpty || maxItems <= 0) {
      return const _BasketSelection();
    }

    var states = <String, _BasketSelection>{'0:0': const _BasketSelection()};
    for (final item in candidates) {
      final next = Map<String, _BasketSelection>.from(states);
      for (final state in states.values) {
        if (state.items.length >= maxItems) continue;
        final newCalories = state.totalCalories + item.calories;
        if (newCalories > targetCalories) continue;
        final candidate = state.add(item);
        final key = '$newCalories:${candidate.items.length}';
        final existing = next[key];
        if (existing == null || _isBetterSelection(candidate, existing)) {
          next[key] = candidate;
        }
      }
      states = next;
    }

    return states.values.reduce(
      (best, current) => _isBetterSelection(current, best) ? current : best,
    );
  }

  int _sumCalories(List<PlannerFoodItem> items) {
    return items.fold(0, (sum, item) => sum + item.calories);
  }

  String _normalizeKey(String value) {
    return value.toLowerCase().trim().replaceAll(' ', '_');
  }

  String _formatFoodName(String id) {
    return id
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _BasketSelection {
  const _BasketSelection({
    this.items = const [],
    this.totalCalories = 0,
    this.totalPricePhp = 0,
    this.totalProtein = 0,
  });

  final List<PlannerFoodItem> items;
  final int totalCalories;
  final double totalPricePhp;
  final int totalProtein;

  int get roundedPrice => totalPricePhp.round();

  _BasketSelection add(PlannerFoodItem item) {
    return _BasketSelection(
      items: [...items, item],
      totalCalories: totalCalories + item.calories,
      totalPricePhp: totalPricePhp + (item.pricePhp ?? 0),
      totalProtein: totalProtein + item.protein,
    );
  }
}
