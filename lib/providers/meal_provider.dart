import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/firestore_service.dart';
import '../models/meal_model.dart';

class MealProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
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
    _mealsSubscription =
        _firestoreService.mealsStream(uid, _selectedDate).listen((meals) {
      _meals = meals;
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
    notifyListeners();
    final meals = await _firestoreService.getMealsForDate(uid, date);
    _meals = meals;
    notifyListeners();
  }

  Future<void> logMeal(String uid, String mealId) async {
    try {
      await _firestoreService.logMeal(uid, mealId);
      final idx = _meals.indexWhere((m) => m.id == mealId);
      if (idx != -1) {
        _meals[idx] = _meals[idx].copyWith(
          status: MealStatus.logged,
          loggedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> addManualMeal({
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
  }) async {
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
    notifyListeners();
  }

  Future<void> deleteMeal(String uid, String mealId) async {
    await _firestoreService.deleteMeal(uid, mealId);
    _meals.removeWhere((m) => m.id == mealId);
    notifyListeners();
  }

  Future<void> generateWeekPlan(String uid) async {
    _loading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      await _firestoreService.generateWeekMealPlan(uid, weekStart);
      await selectDate(uid, _selectedDate);
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> updateMealRecipe(
    String uid,
    String mealId,
    String recipe,
    List<String> cookingSteps,
  ) async {
    await _firestoreService.updateMeal(uid, mealId, {
      'recipe': recipe,
      'cookingSteps': cookingSteps,
    });
    final idx = _meals.indexWhere((m) => m.id == mealId);
    if (idx != -1) {
      _meals[idx] = _meals[idx].copyWith(
        recipe: recipe,
        cookingSteps: cookingSteps,
      );
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
