import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/firestore_service.dart';
import '../services/engagement_service.dart';
import '../services/meal_swap_service.dart';
import '../models/meal_model.dart';
import '../models/recipe_model.dart';

class MealProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final EngagementService _engagementService = EngagementService();
  final _uuid = const Uuid();

  StreamSubscription<List<MealModel>>? _mealsSubscription;

  List<MealModel> _meals = [];
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  String? _error;

  List<MealModel> get meals => _meals;
  DateTime get selectedDate => _selectedDate;
  bool get loading => _loading;
  String? get error => _error;

  double get totalSpent => _meals.fold(
      0, (sum, m) => sum + (m.status == MealStatus.logged ? m.price : 0));
  int get totalCalories => _meals.fold(
      0, (sum, m) => sum + (m.status == MealStatus.logged ? m.calories : 0));
  int get loggedCount =>
      _meals.where((m) => m.status == MealStatus.logged).length;

  void listenToMeals(String uid) {
    _mealsSubscription?.cancel();
    _loading = true;
    _error = null;
    notifyListeners();
    _mealsSubscription =
        _firestoreService.mealsStream(uid, _selectedDate).listen((meals) {
      _meals = meals;
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object error) {
      _loading = false;
      _error = 'Could not load meals. Please try again.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _mealsSubscription?.cancel();
    super.dispose();
  }

  Future<void> selectDate(String uid, DateTime date) async {
    _selectedDate = date;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final meals = await _firestoreService.getMealsForDate(uid, date);
      _meals = meals;
    } catch (e) {
      _error = 'Could not load meals for this date. Please try again.';
      rethrow;
    } finally {
      _loading = false;
    }
    notifyListeners();
  }

  Future<List<MealModel>> getMealsForWeek(
    String uid,
    DateTime anchorDate,
  ) async {
    if (uid.isEmpty) return const <MealModel>[];

    final weekStart = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
    ).subtract(Duration(days: anchorDate.weekday - 1));
    final weeklyMeals = <MealModel>[];

    try {
      for (var i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final meals = await _firestoreService.getMealsForDate(uid, day);
        weeklyMeals.addAll(meals);
      }
      weeklyMeals.sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.type.index.compareTo(b.type.index);
      });
      return weeklyMeals;
    } catch (e) {
      _error = 'Could not load weekly meals. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logMeal(
    String uid,
    String mealId, {
    String displayName = '',
    String? photoUrl,
    double dailyBudget = 150,
  }) async {
    try {
      await _firestoreService.logMeal(uid, mealId);
      final idx = _meals.indexWhere((m) => m.id == mealId);
      MealModel? loggedMeal;
      if (idx != -1) {
        _meals[idx] = _meals[idx].copyWith(
          status: MealStatus.logged,
          loggedAt: DateTime.now(),
        );
        loggedMeal = _meals[idx];
        notifyListeners();
      }
      await _tryRecordActivity(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        actionType: WeeklyStatAction.mealLogged,
        occurredAt: loggedMeal?.date ?? _selectedDate,
        dailyBudget: dailyBudget,
      );
      if (loggedMeal != null &&
          _isBudgetFriendlyMeal(loggedMeal.price, dailyBudget)) {
        await _tryRecordActivity(
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.budgetFriendlyMeal,
          occurredAt: loggedMeal.date,
          dailyBudget: dailyBudget,
        );
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<MealModel> addManualMeal({
    required String uid,
    required String name,
    required MealType type,
    required double price,
    required int calories,
    int protein = 0,
    int carbs = 0,
    int fat = 0,
    List<String> ingredients = const [],
    String? notes,
    MealStatus status = MealStatus.logged,
    String displayName = '',
    String? photoUrl,
    double dailyBudget = 150,
    bool isScannedMeal = false,
  }) async {
    try {
      final meal = MealModel(
        id: _uuid.v4(),
        userId: uid,
        name: name,
        type: type,
        price: price,
        calories: calories,
        date: _selectedDate,
        status: status,
        loggedAt: status == MealStatus.logged ? DateTime.now() : null,
        notes: notes,
        protein: protein,
        carbs: carbs,
        fat: fat,
        ingredients: ingredients,
      );
      await _firestoreService.addMeal(meal);
      _meals.add(meal);
      _meals.sort((a, b) => a.type.index.compareTo(b.type.index));
      _error = null;
      notifyListeners();
      if (status == MealStatus.logged) {
        await _tryRecordActivity(
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.mealLogged,
          occurredAt: meal.date,
          dailyBudget: dailyBudget,
        );
      }
      if (isScannedMeal) {
        await _tryRecordActivity(
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.scannedMeal,
          occurredAt: meal.date,
          dailyBudget: dailyBudget,
        );
      }
      if (_isBudgetFriendlyMeal(meal.price, dailyBudget)) {
        await _tryRecordActivity(
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.budgetFriendlyMeal,
          occurredAt: meal.date,
          dailyBudget: dailyBudget,
        );
      }
      return meal;
    } catch (e) {
      _error = 'Could not save meal. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<MealModel> addPlannedMeal({
    required String uid,
    required String name,
    required MealType type,
    required double price,
    required int calories,
    int protein = 0,
    int carbs = 0,
    int fat = 0,
    List<String> ingredients = const [],
    String? notes,
    MealStatus status = MealStatus.ready,
    String displayName = '',
    String? photoUrl,
    double dailyBudget = 150,
  }) async {
    try {
      final meal = MealModel(
        id: _uuid.v4(),
        userId: uid,
        name: name,
        type: type,
        price: price,
        calories: calories,
        date: _selectedDate,
        status: status,
        loggedAt: status == MealStatus.logged ? DateTime.now() : null,
        notes: notes,
        protein: protein,
        carbs: carbs,
        fat: fat,
        ingredients: ingredients,
      );
      await _firestoreService.addMeal(meal);
      _meals.add(meal);
      _meals.sort((a, b) => a.type.index.compareTo(b.type.index));
      _error = null;
      notifyListeners();
      await _tryRecordActivity(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        actionType: WeeklyStatAction.plannedMealSaved,
        occurredAt: meal.date,
        dailyBudget: dailyBudget,
      );
      if (_isBudgetFriendlyMeal(meal.price, dailyBudget)) {
        await _tryRecordActivity(
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.budgetFriendlyMeal,
          occurredAt: meal.date,
          dailyBudget: dailyBudget,
        );
      }
      return meal;
    } catch (e) {
      _error = 'Could not save planned meal. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<MealModel> addRecipeMeal({
    required String uid,
    required RecipeModel recipe,
    MealStatus status = MealStatus.ready,
    String displayName = '',
    String? photoUrl,
    double dailyBudget = 150,
  }) async {
    try {
      final meal = MealModel(
        id: _uuid.v4(),
        userId: uid,
        name: recipe.name,
        type: _mealTypeFromRecipe(recipe.mealType),
        price: recipe.estimatedPricePhp,
        calories: recipe.calories,
        date: _selectedDate,
        status: status,
        loggedAt: status == MealStatus.logged ? DateTime.now() : null,
        notes: _recipeNotes(recipe),
        protein: recipe.protein,
        carbs: recipe.carbs,
        fat: recipe.fat,
        ingredients: recipe.ingredients,
        recipe: recipe.description.isEmpty ? null : recipe.description,
        cookingSteps: recipe.cookingSteps,
      );
      await _firestoreService.addMeal(meal);
      _meals.add(meal);
      _meals.sort((a, b) => a.type.index.compareTo(b.type.index));
      _error = null;
      notifyListeners();
      await _tryRecordActivity(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        actionType: WeeklyStatAction.recipeSaved,
        occurredAt: meal.date,
        dailyBudget: dailyBudget,
      );
      return meal;
    } catch (e) {
      _error = 'Could not save recipe to Meal Log. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  MealType _mealTypeFromRecipe(String mealType) {
    return MealType.values.firstWhere(
      (type) => type.name == mealType.toLowerCase().trim(),
      orElse: () => MealType.lunch,
    );
  }

  String? _recipeNotes(RecipeModel recipe) {
    final labels = [
      ...recipe.dietLabels,
      ...recipe.healthLabels,
    ];
    final parts = <String>[
      if (recipe.description.trim().isNotEmpty) recipe.description.trim(),
      if (labels.isNotEmpty) 'Labels: ${labels.take(6).join(', ')}',
      if (recipe.source.trim().isNotEmpty) recipe.source.trim(),
    ];
    return parts.isEmpty ? null : parts.join('\n');
  }

  Future<void> deleteMeal(String uid, String mealId) async {
    try {
      await _firestoreService.deleteMeal(uid, mealId);
      _meals.removeWhere((m) => m.id == mealId);
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Could not delete meal. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateMealRecipe(
    String uid,
    String mealId,
    String recipe,
    List<String> cookingSteps, {
    String displayName = '',
    String? photoUrl,
    double dailyBudget = 150,
  }) async {
    try {
      final idx = _meals.indexWhere((m) => m.id == mealId);
      final hadRecipe = idx != -1 &&
          (_meals[idx].recipe != null && _meals[idx].recipe!.isNotEmpty);
      await _firestoreService.updateMeal(uid, mealId, {
        'recipe': recipe,
        'cookingSteps': cookingSteps,
      });
      if (idx != -1) {
        _meals[idx] = _meals[idx].copyWith(
          recipe: recipe,
          cookingSteps: cookingSteps,
        );
        notifyListeners();
      }
      if (!hadRecipe) {
        await _tryRecordActivity(
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.recipeSaved,
          occurredAt: idx == -1 ? _selectedDate : _meals[idx].date,
          dailyBudget: dailyBudget,
        );
      }
    } catch (e) {
      _error = 'Could not save recipe. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  Future<MealModel> replaceMealWithSwap({
    required String uid,
    required String mealId,
    required MealSwapOption option,
    String displayName = '',
    String? photoUrl,
    double dailyBudget = 150,
  }) async {
    final food = option.food;
    if (food == null) {
      throw ArgumentError('A swap option must include a replacement food.');
    }

    try {
      final idx = _meals.indexWhere((meal) => meal.id == mealId);
      if (idx == -1) {
        throw StateError('Meal not found.');
      }

      final original = _meals[idx];
      final notes = MealSwapService.replacementNotes(original, option);
      final updateData = {
        'name': food.name,
        'price': food.estimatedPricePhp,
        'calories': food.calories,
        'notes': notes,
        'ingredients': food.ingredients,
        'protein': food.protein,
        'carbs': food.carbs,
        'fat': food.fat,
        'recipe': null,
        'cookingSteps': <String>[],
      };

      await _firestoreService.updateMeal(uid, mealId, updateData);

      final swappedMeal = MealModel(
        id: original.id,
        userId: original.userId,
        name: food.name,
        type: original.type,
        price: food.estimatedPricePhp,
        calories: food.calories,
        status: original.status,
        date: original.date,
        loggedAt: original.loggedAt,
        notes: notes,
        ingredients: food.ingredients,
        protein: food.protein,
        carbs: food.carbs,
        fat: food.fat,
        recipe: null,
        cookingSteps: const [],
      );

      _meals[idx] = swappedMeal;
      _meals.sort((a, b) => a.type.index.compareTo(b.type.index));
      _error = null;
      notifyListeners();

      if (_isBudgetFriendlyMeal(swappedMeal.price, dailyBudget)) {
        await _tryRecordActivity(
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.budgetFriendlyMeal,
          occurredAt: swappedMeal.date,
          dailyBudget: dailyBudget,
        );
      }

      return swappedMeal;
    } catch (e) {
      _error = 'Could not swap meal. Please try again.';
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  bool _isBudgetFriendlyMeal(double price, double dailyBudget) {
    if (dailyBudget <= 0 || price <= 0) return false;
    return price <= dailyBudget / 4;
  }

  Future<void> _tryRecordActivity({
    required String uid,
    required String displayName,
    String? photoUrl,
    required WeeklyStatAction actionType,
    DateTime? occurredAt,
    double? dailyBudget,
  }) async {
    try {
      await _engagementService.updateWeeklyStatsForAction(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        actionType: actionType,
        occurredAt: occurredAt,
        dailyBudget: dailyBudget,
      );
    } catch (_) {
      // Stats and badges are best-effort so meal logging remains reliable.
    }
  }
}
