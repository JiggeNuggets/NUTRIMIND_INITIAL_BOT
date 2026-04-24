// Models for the AI Meal Planner (ported from Streamlit + Python optimizers).

enum MealPlannerAlgorithm {
  /// Dynamic-programming knapsack (default in original app).
  knapsack,

  /// Random greedy selection until near target (original `generate_items_list`).
  randomGreedy,
}

enum PlannerFoodSource {
  localDavaoFoods,
  calorieOnlyFallback,
}

enum PlannerMealSlot {
  breakfast,
  lunch,
  dinner,
  snack,
}

extension PlannerMealSlotX on PlannerMealSlot {
  String get label => switch (this) {
        PlannerMealSlot.breakfast => 'Breakfast',
        PlannerMealSlot.lunch => 'Lunch',
        PlannerMealSlot.dinner => 'Dinner',
        PlannerMealSlot.snack => 'Snack',
      };

  double calorieFractionOfBmr() => switch (this) {
        PlannerMealSlot.breakfast => 0.35,
        PlannerMealSlot.lunch => 0.30,
        PlannerMealSlot.dinner => 0.25,
        PlannerMealSlot.snack => 0.10,
      };
}

class PlannerFoodItem {
  const PlannerFoodItem({
    required this.id,
    required this.name,
    required this.calories,
    required this.source,
    this.pricePhp,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.ingredients = const [],
    this.mealType = '',
    this.category = '',
    this.servingSize = '',
    this.dataSource = '',
    this.sourceType = '',
    this.lastVerifiedDate,
    this.isPrototypeEstimate = false,
  });

  final String id;
  final String name;
  final int calories;
  final PlannerFoodSource source;
  final double? pricePhp;
  final int protein;
  final int carbs;
  final int fat;
  final List<String> ingredients;
  final String mealType;
  final String category;
  final String servingSize;
  final String dataSource;
  final String sourceType;
  final String? lastVerifiedDate;
  final bool isPrototypeEstimate;

  bool get isLocalDavao => source == PlannerFoodSource.localDavaoFoods;
  bool get isCalorieOnlyFallback =>
      source == PlannerFoodSource.calorieOnlyFallback;
  bool get hasPrice => pricePhp != null && pricePhp! > 0;
}

/// One meal basket: structured foods + achieved calories vs target.
class MealBasket {
  const MealBasket({
    required this.slot,
    required this.items,
    required this.totalCalories,
    required this.targetCalories,
  });

  final PlannerMealSlot slot;
  final List<PlannerFoodItem> items;
  final int totalCalories;
  final double targetCalories;

  double get totalPricePhp => items.fold<double>(
        0,
        (sum, item) => sum + (item.pricePhp ?? 0),
      );

  int get totalProtein => items.fold(0, (sum, item) => sum + item.protein);

  int get totalCarbs => items.fold(0, (sum, item) => sum + item.carbs);

  int get totalFat => items.fold(0, (sum, item) => sum + item.fat);

  bool get hasCalorieOnlyFallback =>
      items.any((item) => item.isCalorieOnlyFallback);

  bool get hasOnlyPricedItems => items.every((item) => item.hasPrice);

  List<String> get itemNames => items.map((item) => item.name).toList();
}

/// Full day plan from BMR split (35% / 30% / 25% / 10%).
class DailyMealPlan {
  const DailyMealPlan({
    required this.bmr,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snack,
  });

  final double bmr;
  final MealBasket breakfast;
  final MealBasket lunch;
  final MealBasket dinner;
  final MealBasket snack;

  int get totalPlanCalories =>
      breakfast.totalCalories +
      lunch.totalCalories +
      dinner.totalCalories +
      snack.totalCalories;

  double get totalEstimatedPricePhp =>
      breakfast.totalPricePhp +
      lunch.totalPricePhp +
      dinner.totalPricePhp +
      snack.totalPricePhp;

  int get totalProtein =>
      breakfast.totalProtein +
      lunch.totalProtein +
      dinner.totalProtein +
      snack.totalProtein;

  int get totalCarbs =>
      breakfast.totalCarbs +
      lunch.totalCarbs +
      dinner.totalCarbs +
      snack.totalCarbs;

  int get totalFat =>
      breakfast.totalFat + lunch.totalFat + dinner.totalFat + snack.totalFat;

  List<MealBasket> get baskets => [breakfast, lunch, dinner, snack];
}

/// Input for planner (profile + filters). Metric internally: kg, cm.
class MealPlannerInput {
  const MealPlannerInput({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.isMale,
    required this.dailyBudgetPhp,
    this.budgetBufferPct = 15,
    this.allowCalorieOnlyFallback = true,
    this.preferredBreakfastGroups = const [],
    this.excludedGroups = const [],
    this.algorithm = MealPlannerAlgorithm.knapsack,
  });

  final double weightKg;
  final double heightCm;
  final int age;
  final bool isMale;
  final double dailyBudgetPhp;
  final double budgetBufferPct;
  final bool allowCalorieOnlyFallback;

  /// If non-empty, breakfast selection only uses these groups (Streamlit-style prefs on group keys).
  final List<String> preferredBreakfastGroups;

  /// Group keys to remove from all meals (allergy / restriction).
  final List<String> excludedGroups;

  final MealPlannerAlgorithm algorithm;
}
