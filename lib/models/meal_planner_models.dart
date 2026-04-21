/// Models for the AI Meal Planner (ported from Streamlit + Python optimizers).

enum MealPlannerAlgorithm {
  /// Dynamic-programming knapsack (default in original app).
  knapsack,

  /// Random greedy selection until near target (original `generate_items_list`).
  randomGreedy,
}

enum PlannerMealSlot {
  breakfast,
  lunch,
  dinner,
}

extension PlannerMealSlotX on PlannerMealSlot {
  String get label => switch (this) {
        PlannerMealSlot.breakfast => 'Breakfast',
        PlannerMealSlot.lunch => 'Lunch',
        PlannerMealSlot.dinner => 'Dinner',
      };

  double calorieFractionOfBmr() => switch (this) {
        PlannerMealSlot.breakfast => 0.5,
        PlannerMealSlot.lunch => 1 / 3,
        PlannerMealSlot.dinner => 1 / 6,
      };
}

/// One meal basket: list of food keys + achieved calories vs target.
class MealBasket {
  const MealBasket({
    required this.slot,
    required this.items,
    required this.totalCalories,
    required this.targetCalories,
  });

  final PlannerMealSlot slot;
  final List<String> items;
  final int totalCalories;
  final double targetCalories;
}

/// Full day plan from BMR split (50% / 33⅓% / 16⅔%).
class DailyMealPlan {
  const DailyMealPlan({
    required this.bmr,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
  });

  final double bmr;
  final MealBasket breakfast;
  final MealBasket lunch;
  final MealBasket dinner;

  int get totalPlanCalories =>
      breakfast.totalCalories + lunch.totalCalories + dinner.totalCalories;
}

/// Input for planner (profile + filters). Metric internally: kg, cm.
class MealPlannerInput {
  const MealPlannerInput({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.isMale,
    this.preferredBreakfastGroups = const [],
    this.excludedGroups = const [],
    this.algorithm = MealPlannerAlgorithm.knapsack,
  });

  final double weightKg;
  final double heightCm;
  final int age;
  final bool isMale;

  /// If non-empty, breakfast selection only uses these groups (Streamlit-style prefs on group keys).
  final List<String> preferredBreakfastGroups;

  /// Group keys to remove from all meals (allergy / restriction).
  final List<String> excludedGroups;

  final MealPlannerAlgorithm algorithm;
}
