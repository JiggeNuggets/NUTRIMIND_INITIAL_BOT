import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/firestore_service.dart';
import '../services/engagement_service.dart';
import '../services/meal_swap_service.dart';
import '../models/meal_model.dart';
import '../models/recipe_model.dart';
import '../utils/firestore_safety.dart';

class MealProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final EngagementService _engagementService = EngagementService();
  final _uuid = const Uuid();

  StreamSubscription<List<MealModel>>? _mealsSubscription;
  String? _activeMealsUid;
  DateTime? _activeMealsDate;
  int _mealsStreamGeneration = 0;
  bool _disposed = false;

  List<MealModel> _meals = [];
  DateTime _selectedDate = _dateOnly(DateTime.now());
  bool _loading = false;
  String? _error;

  List<MealModel> get meals => _meals;
  DateTime get selectedDate => _selectedDate;
  bool get loading => _loading;
  String? get error => _error;

  double get totalSpent => _meals.fold(
      0, (total, m) => total + (m.status == MealStatus.logged ? m.price : 0));
  int get totalCalories => _meals.fold(0,
      (total, m) => total + (m.status == MealStatus.logged ? m.calories : 0));
  int get loggedCount =>
      _meals.where((m) => m.status == MealStatus.logged).length;
  int get plannedCount =>
      _meals.where((m) => m.status != MealStatus.logged).length;
  int get plannedCalories => _meals.fold(0,
      (total, m) => total + (m.status != MealStatus.logged ? m.calories : 0));
  double get plannedCost => _meals.fold(
      0.0, (total, m) => total + (m.status != MealStatus.logged ? m.price : 0));

  void listenToMeals(String uid) {
    if (uid.isEmpty) return;
    if (_hasActiveMealStream(uid, _selectedDate) &&
        (_loading || _error == null)) {
      return;
    }
    unawaited(_subscribeToSelectedDate(uid));
  }

  Future<void> _subscribeToSelectedDate(String uid) async {
    final targetDate = _dateOnly(_selectedDate);
    final generation = ++_mealsStreamGeneration;
    final previousSubscription = _mealsSubscription;
    _mealsSubscription = null;
    _activeMealsUid = uid;
    _activeMealsDate = targetDate;
    _selectedDate = targetDate;
    _loading = true;
    _error = null;
    notifyListeners();

    await previousSubscription?.cancel();
    if (_disposed || generation != _mealsStreamGeneration) return;

    _mealsSubscription =
        _firestoreService.mealsStream(uid, targetDate).listen((meals) {
      if (_disposed || generation != _mealsStreamGeneration) return;
      _meals = meals;
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object error) {
      if (_disposed || generation != _mealsStreamGeneration) return;
      _loading = false;
      _error = 'Could not load meals. Please try again.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _mealsStreamGeneration++;
    _mealsSubscription?.cancel();
    super.dispose();
  }

  void clearUserScopedState() {
    final previousSubscription = _mealsSubscription;
    _mealsSubscription = null;
    _activeMealsUid = null;
    _activeMealsDate = null;
    _mealsStreamGeneration++;
    unawaited(previousSubscription?.cancel());
    _meals = [];
    _loading = false;
    _error = null;
    _selectedDate = _dateOnly(DateTime.now());
    notifyListeners();
  }

  Future<void> selectDate(String uid, DateTime date) async {
    final normalizedDate = _dateOnly(date);
    final selectedSameDay = _isSameDay(_selectedDate, normalizedDate);
    _selectedDate = normalizedDate;
    if (uid.isEmpty) {
      final previousSubscription = _mealsSubscription;
      _mealsSubscription = null;
      _activeMealsUid = null;
      _activeMealsDate = null;
      _mealsStreamGeneration++;
      await previousSubscription?.cancel();
      _meals = [];
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }
    if (selectedSameDay &&
        _hasActiveMealStream(uid, normalizedDate) &&
        (_loading || _error == null)) {
      return;
    }
    if (!selectedSameDay) {
      _meals = [];
    }
    await _subscribeToSelectedDate(uid);
  }

  bool _hasActiveMealStream(String uid, DateTime date) {
    final activeDate = _activeMealsDate;
    return (_mealsSubscription != null || _loading) &&
        _activeMealsUid == uid &&
        activeDate != null &&
        _isSameDay(activeDate, date);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

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
    } catch (e, st) {
      debugPrint(
        '[MealProvider.getMealsForWeek] failed uid=$uid anchorDate=$anchorDate error=$e',
      );
      debugPrintStack(
        label: '[MealProvider.getMealsForWeek] stack',
        stackTrace: st,
      );
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
    int? calories,
  }) async {
    final safeMealId = mealId.trim();
    if (uid.isEmpty) {
      _error = 'Unable to log meal - not signed in.';
      notifyListeners();
      return;
    }
    if (safeMealId.isEmpty) {
      _error = 'Could not log meal. Please try again.';
      notifyListeners();
      return;
    }
    if (calories != null && calories <= 0) {
      _error = 'Enter calories greater than 0.';
      notifyListeners();
      return;
    }
    try {
      await _firestoreService.logMeal(uid, safeMealId, calories: calories);
      _error = null;
      final idx = _meals.indexWhere((m) => m.id == safeMealId);
      MealModel? loggedMeal;
      if (idx != -1) {
        _meals[idx] = _meals[idx].copyWith(
          status: MealStatus.logged,
          loggedAt: DateTime.now(),
          calories: calories,
        );
        loggedMeal = _meals[idx];
        notifyListeners();
      }
      _recordActivityBestEffort(
        operation: 'logMeal.mealLoggedStats',
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        actionType: WeeklyStatAction.mealLogged,
        occurredAt: loggedMeal?.date ?? _selectedDate,
        dailyBudget: dailyBudget,
      );
      if (loggedMeal != null &&
          _isBudgetFriendlyMeal(loggedMeal.price, dailyBudget)) {
        _recordActivityBestEffort(
          operation: 'logMeal.budgetFriendlyStats',
          uid: uid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.budgetFriendlyMeal,
          occurredAt: loggedMeal.date,
          dailyBudget: dailyBudget,
        );
      }
    } catch (e, st) {
      _logProviderMealFailure(
        operation: 'logMeal',
        uid: uid,
        mealId: safeMealId,
        date: _selectedDate,
        error: e,
        stackTrace: st,
      );
      _error = 'Could not log meal. Please try again.';
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
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      throw ArgumentError('addManualMeal requires non-empty uid');
    }
    try {
      final meal = MealModel(
        id: _uuid.v4(),
        userId: safeUid,
        name: name,
        type: type,
        price: safeDouble(price),
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
        _recordActivityBestEffort(
          operation: 'addManualMeal.mealLoggedStats',
          uid: safeUid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.mealLogged,
          occurredAt: meal.date,
          dailyBudget: dailyBudget,
        );
      }
      if (isScannedMeal) {
        _recordActivityBestEffort(
          operation: 'addManualMeal.scannedMealStats',
          uid: safeUid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.scannedMeal,
          occurredAt: meal.date,
          dailyBudget: dailyBudget,
        );
      }
      if (_isBudgetFriendlyMeal(meal.price, dailyBudget)) {
        _recordActivityBestEffort(
          operation: 'addManualMeal.budgetFriendlyStats',
          uid: safeUid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.budgetFriendlyMeal,
          occurredAt: meal.date,
          dailyBudget: dailyBudget,
        );
      }
      return meal;
    } catch (e, st) {
      _logProviderMealFailure(
        operation: 'addManualMeal',
        uid: safeUid,
        date: _selectedDate,
        error: e,
        stackTrace: st,
      );
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
    String? imageUrl,
    MealStatus status = MealStatus.ready,
    String displayName = '',
    String? photoUrl,
    double dailyBudget = 150,
    DateTime? forDate,
  }) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      throw ArgumentError('addPlannedMeal requires non-empty uid');
    }
    try {
      final mealDate = _dateOnly(forDate ?? _selectedDate);
      final meal = MealModel(
        id: _uuid.v4(),
        userId: safeUid,
        name: name,
        type: type,
        price: safeDouble(price),
        calories: calories,
        date: mealDate,
        status: status,
        loggedAt: status == MealStatus.logged ? DateTime.now() : null,
        notes: notes,
        protein: protein,
        carbs: carbs,
        fat: fat,
        ingredients: ingredients,
        imageUrl: _cleanImageUrl(imageUrl),
      );
      await _firestoreService.addMeal(meal);
      final mealDay = _dateOnly(mealDate);
      final selDay = _dateOnly(_selectedDate);
      if (mealDay == selDay) {
        _meals.add(meal);
        _meals.sort((a, b) => a.type.index.compareTo(b.type.index));
      }
      _error = null;
      notifyListeners();
      _recordActivityBestEffort(
        operation: 'addPlannedMeal.plannedMealStats',
        uid: safeUid,
        displayName: displayName,
        photoUrl: photoUrl,
        actionType: WeeklyStatAction.plannedMealSaved,
        occurredAt: meal.date,
        dailyBudget: dailyBudget,
      );
      if (_isBudgetFriendlyMeal(meal.price, dailyBudget)) {
        _recordActivityBestEffort(
          operation: 'addPlannedMeal.budgetFriendlyStats',
          uid: safeUid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.budgetFriendlyMeal,
          occurredAt: meal.date,
          dailyBudget: dailyBudget,
        );
      }
      return meal;
    } catch (e, st) {
      _logProviderMealFailure(
        operation: 'addPlannedMeal',
        uid: safeUid,
        date: forDate ?? _selectedDate,
        error: e,
        stackTrace: st,
        extra: 'type=${type.name} name=$name',
      );
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
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      throw ArgumentError('addRecipeMeal requires non-empty uid');
    }
    try {
      final meal = MealModel(
        id: _uuid.v4(),
        userId: safeUid,
        name: recipe.name,
        type: _mealTypeFromRecipe(recipe.mealType),
        price: safeDouble(recipe.estimatedPricePhp),
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
        imageUrl: _cleanImageUrl(recipe.imageUrl),
      );
      await _firestoreService.addMeal(meal);
      _meals.add(meal);
      _meals.sort((a, b) => a.type.index.compareTo(b.type.index));
      _error = null;
      notifyListeners();
      _recordActivityBestEffort(
        operation: 'addRecipeMeal.recipeSavedStats',
        uid: safeUid,
        displayName: displayName,
        photoUrl: photoUrl,
        actionType: WeeklyStatAction.recipeSaved,
        occurredAt: meal.date,
        dailyBudget: dailyBudget,
      );
      return meal;
    } catch (e, st) {
      _logProviderMealFailure(
        operation: 'addRecipeMeal',
        uid: safeUid,
        date: _selectedDate,
        error: e,
        stackTrace: st,
      );
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
    final safeUid = uid.trim();
    final safeMealId = mealId.trim();
    if (safeUid.isEmpty || safeMealId.isEmpty) {
      throw ArgumentError('deleteMeal requires non-empty uid and mealId');
    }
    try {
      await _firestoreService.deleteMeal(safeUid, safeMealId);
      _meals.removeWhere((m) => m.id == safeMealId);
      _error = null;
      notifyListeners();
    } catch (e, st) {
      _logProviderMealFailure(
        operation: 'deleteMeal',
        uid: safeUid,
        mealId: safeMealId,
        date: _selectedDate,
        error: e,
        stackTrace: st,
      );
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
    final safeUid = uid.trim();
    final safeMealId = mealId.trim();
    if (safeUid.isEmpty || safeMealId.isEmpty) {
      throw ArgumentError('updateMealRecipe requires non-empty uid and mealId');
    }
    try {
      final idx = _meals.indexWhere((m) => m.id == safeMealId);
      final hadRecipe = idx != -1 &&
          (_meals[idx].recipe != null && _meals[idx].recipe!.isNotEmpty);
      await _firestoreService.updateMeal(safeUid, safeMealId, {
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
        _recordActivityBestEffort(
          operation: 'updateMealRecipe.recipeSavedStats',
          uid: safeUid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.recipeSaved,
          occurredAt: idx == -1 ? _selectedDate : _meals[idx].date,
          dailyBudget: dailyBudget,
        );
      }
    } catch (e, st) {
      _logProviderMealFailure(
        operation: 'updateMealRecipe',
        uid: safeUid,
        mealId: safeMealId,
        date: _selectedDate,
        error: e,
        stackTrace: st,
      );
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
    final safeUid = uid.trim();
    final safeMealId = mealId.trim();
    if (safeUid.isEmpty || safeMealId.isEmpty) {
      throw ArgumentError(
          'replaceMealWithSwap requires non-empty uid and mealId');
    }

    try {
      final idx = _meals.indexWhere((meal) => meal.id == safeMealId);
      if (idx == -1) {
        throw StateError('Meal not found.');
      }

      final original = _meals[idx];
      final notes = MealSwapService.replacementNotes(original, option);
      final replacementImageUrl = _cleanImageUrl(food.imageUrl);
      final updateData = {
        'name': food.name,
        'price': safeDouble(food.estimatedPricePhp),
        'calories': food.calories,
        'notes': notes,
        'ingredients': food.ingredients,
        'protein': food.protein,
        'carbs': food.carbs,
        'fat': food.fat,
        'recipe': null,
        'cookingSteps': <String>[],
        'imageUrl': replacementImageUrl,
      };

      await _firestoreService.updateMeal(safeUid, safeMealId, updateData);

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
        imageUrl: replacementImageUrl,
      );

      _meals[idx] = swappedMeal;
      _meals.sort((a, b) => a.type.index.compareTo(b.type.index));
      _error = null;
      notifyListeners();

      if (_isBudgetFriendlyMeal(swappedMeal.price, dailyBudget)) {
        _recordActivityBestEffort(
          operation: 'replaceMealWithSwap.budgetFriendlyStats',
          uid: safeUid,
          displayName: displayName,
          photoUrl: photoUrl,
          actionType: WeeklyStatAction.budgetFriendlyMeal,
          occurredAt: swappedMeal.date,
          dailyBudget: dailyBudget,
        );
      }

      return swappedMeal;
    } catch (e, st) {
      _logProviderMealFailure(
        operation: 'replaceMealWithSwap',
        uid: safeUid,
        mealId: safeMealId,
        date: _selectedDate,
        error: e,
        stackTrace: st,
      );
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

  String? _cleanImageUrl(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _recordActivityBestEffort({
    required String operation,
    required String uid,
    required String displayName,
    String? photoUrl,
    required WeeklyStatAction actionType,
    DateTime? occurredAt,
    double? dailyBudget,
  }) {
    unawaited(
      _tryRecordActivity(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
        actionType: actionType,
        occurredAt: occurredAt,
        dailyBudget: dailyBudget,
      )
          .timeout(const Duration(seconds: 8))
          .catchError((Object e, StackTrace st) {
        _logProviderMealFailure(
          operation: operation,
          uid: uid,
          date: occurredAt ?? _selectedDate,
          error: e,
          stackTrace: st,
          optional: true,
        );
      }),
    );
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
    } catch (e, st) {
      _logProviderMealFailure(
        operation: 'recordActivity.${actionType.key}',
        uid: uid,
        date: occurredAt ?? _selectedDate,
        error: e,
        stackTrace: st,
        optional: true,
      );
    }
  }

  void _logProviderMealFailure({
    required String operation,
    required String uid,
    String? mealId,
    DateTime? date,
    required Object error,
    StackTrace? stackTrace,
    String? extra,
    bool optional = false,
  }) {
    final firestoreCode =
        error is FirebaseException ? ' code=${error.code}' : '';
    final firestoreMessage =
        error is FirebaseException ? ' message=${error.message}' : '';
    developer.log(
      '[MealProvider] operation=$operation optional=$optional '
      'uid=$uid mealId=${mealId ?? 'n/a'} '
      'selectedDate=${_selectedDate.toIso8601String()} '
      'date=${date?.toIso8601String() ?? 'n/a'} '
      '${extra ?? ''}$firestoreCode$firestoreMessage',
      error: error,
      stackTrace: stackTrace,
      level: optional ? 900 : 1000,
    );
  }
}
