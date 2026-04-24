import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/meal_planner_food_data.dart';
import '../../models/meal_model.dart';
import '../../models/meal_planner_models.dart';
import '../../models/nutribot_models.dart';
import '../../models/recipe_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/groq_meal_narrative_service.dart';
import '../../services/meal_planner_service.dart';
import '../../services/recipe_dataset_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../widgets/nutribot/nutribot_launcher.dart';
import 'profile_screen.dart';

/// AI Meal Planner — ported from Python/Streamlit (`streamlit_meal_planner.py`, `data.py`).
/// Uses BMR + knapsack (or random greedy) + optional Groq narratives (`prompts.py`).
class AiMealPlannerScreen extends StatefulWidget {
  const AiMealPlannerScreen({super.key});

  @override
  State<AiMealPlannerScreen> createState() => _AiMealPlannerScreenState();
}

class _AiMealPlannerScreenState extends State<AiMealPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ageCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _heightFtCtrl;
  late final TextEditingController _heightInCtrl;
  late final TextEditingController _recipeSearchCtrl;
  late final TextEditingController _recipeMaxCaloriesCtrl;
  late final TextEditingController _recipeMaxPriceCtrl;

  bool _useMetric = true;
  bool _isMale = true;
  final Set<String> _preferredBreakfast = {};
  final Set<String> _excludedGroups = {};
  MealPlannerAlgorithm _algorithm = MealPlannerAlgorithm.knapsack;

  DailyMealPlan? _plan;
  bool _building = false;

  String? _aiBreakfast;
  String? _aiLunch;
  String? _aiDinner;
  String? _aiSnack;
  bool _generatingAi = false;
  final Set<PlannerMealSlot> _selectedBasketSlots = {};
  bool _savingSelectedBaskets = false;

  late final RecipeDatasetService _recipeService;
  List<RecipeModel> _recipes = [];
  bool _recipesLoading = true;
  String? _recipesError;
  String _recipeMealTypeFilter = 'all';
  final Set<String> _recipeDietFilters = {};
  final Set<String> _recipeHealthFilters = {};
  final Set<String> _savingRecipeIds = {};

  // Image analysis state
  XFile? _selectedImageFile;
  String? _imageAnalysis;
  bool _analyzingImage = false;
  String? _profileFieldSignature;

  late final GroqMealNarrativeService _groq;

  @override
  void initState() {
    super.initState();
    _ageCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _heightCtrl = TextEditingController();
    _heightFtCtrl = TextEditingController();
    _heightInCtrl = TextEditingController();
    _recipeSearchCtrl = TextEditingController();
    _recipeMaxCaloriesCtrl = TextEditingController();
    _recipeMaxPriceCtrl = TextEditingController();
    _recipeSearchCtrl.addListener(_refreshRecipeFilters);
    _recipeMaxCaloriesCtrl.addListener(_refreshRecipeFilters);
    _recipeMaxPriceCtrl.addListener(_refreshRecipeFilters);
    _groq = GroqMealNarrativeService();
    _recipeService = RecipeDatasetService();
    _loadRecipeDataset();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _heightFtCtrl.dispose();
    _heightInCtrl.dispose();
    _recipeSearchCtrl.dispose();
    _recipeMaxCaloriesCtrl.dispose();
    _recipeMaxPriceCtrl.dispose();
    _groq.dispose();
    super.dispose();
  }

  void _refreshRecipeFilters() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRecipeDataset({bool forceReload = false}) async {
    setState(() {
      _recipesLoading = true;
      _recipesError = null;
    });

    if (forceReload) _recipeService.clearCache();
    final recipes = await _recipeService.getAllRecipes();
    if (!mounted) return;

    setState(() {
      _recipes = recipes;
      _recipesError = _recipeService.lastError;
      _recipesLoading = false;
    });
  }

  List<RecipeModel> get _filteredRecipes {
    final query = _recipeSearchCtrl.text.trim().toLowerCase();
    final maxCalories = num.tryParse(_recipeMaxCaloriesCtrl.text.trim());
    final maxPrice = num.tryParse(_recipeMaxPriceCtrl.text.trim());
    final dietFilters =
        _recipeDietFilters.map((label) => label.toLowerCase()).toSet();
    final healthFilters =
        _recipeHealthFilters.map((label) => label.toLowerCase()).toSet();

    final filtered = _recipes.where((recipe) {
      if (_recipeMealTypeFilter != 'all' &&
          recipe.mealType != _recipeMealTypeFilter) {
        return false;
      }
      if (maxCalories != null && recipe.calories > maxCalories) return false;
      if (maxPrice != null && recipe.estimatedPricePhp > maxPrice) {
        return false;
      }

      final recipeDietLabels =
          recipe.dietLabels.map((label) => label.toLowerCase()).toSet();
      final recipeHealthLabels =
          recipe.healthLabels.map((label) => label.toLowerCase()).toSet();

      if (dietFilters.isNotEmpty &&
          !dietFilters.every(recipeDietLabels.contains)) {
        return false;
      }
      if (healthFilters.isNotEmpty &&
          !healthFilters.every(recipeHealthLabels.contains)) {
        return false;
      }
      if (query.isEmpty) return true;

      final searchable = [
        recipe.name,
        recipe.description,
        recipe.mealType,
        ...recipe.ingredients,
        ...recipe.dietLabels,
        ...recipe.healthLabels,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final priceCompare = a.estimatedPricePhp.compareTo(b.estimatedPricePhp);
      if (priceCompare != 0) return priceCompare;
      return b.protein.compareTo(a.protein);
    });
    return filtered;
  }

  List<String> get _availableDietLabels {
    final labels = <String>{
      for (final recipe in _recipes) ...recipe.dietLabels,
    }.toList()
      ..sort();
    return labels;
  }

  List<String> get _availableHealthLabels {
    final labels = <String>{
      for (final recipe in _recipes) ...recipe.healthLabels,
    }.toList()
      ..sort();
    return labels;
  }

  _PlannerProfileStatus _plannerProfileStatus(UserModel? user) {
    if (user == null) {
      return const _PlannerProfileStatus([
        'sign in',
        'daily budget',
        'age',
        'gender',
        'height',
        'weight',
      ]);
    }

    final missing = <String>[];
    if (!user.budgetConfigured || user.dailyBudget <= 0) {
      missing.add('daily budget');
    }
    if (!user.profileCompleted || user.age <= 0) missing.add('age');
    if (!user.profileCompleted || !_hasPlannerGender(user.gender)) {
      missing.add('gender');
    }
    if (!user.profileCompleted || user.height <= 0) missing.add('height');
    if (!user.profileCompleted || user.weight <= 0) missing.add('weight');
    return _PlannerProfileStatus(missing);
  }

  bool _hasPlannerGender(String gender) {
    final normalized = gender.trim().toLowerCase();
    return normalized == 'male' || normalized == 'female';
  }

  String _profileSignature(UserModel? user, _PlannerProfileStatus status) {
    if (user == null) return 'signed-out:${status.missingFields.join('|')}';
    return [
      user.uid,
      user.profileCompleted,
      user.budgetConfigured,
      user.age,
      user.gender,
      user.height,
      user.weight,
      user.dailyBudget,
      user.budgetBuffer,
      status.missingFields.join('|'),
    ].join(':');
  }

  void _syncPlannerFieldsFromProfile(
    UserModel? user,
    _PlannerProfileStatus status,
  ) {
    final signature = _profileSignature(user, status);
    if (_profileFieldSignature == signature) return;
    _profileFieldSignature = signature;

    if (user == null || !status.isComplete) {
      _ageCtrl.clear();
      _weightCtrl.clear();
      _heightCtrl.clear();
      _heightFtCtrl.clear();
      _heightInCtrl.clear();
      _isMale = true;
      return;
    }

    _ageCtrl.text = user.age.toString();
    _weightCtrl.text = user.weight.toStringAsFixed(
      user.weight % 1 == 0 ? 0 : 1,
    );
    _heightCtrl.text = user.height.toStringAsFixed(
      user.height % 1 == 0 ? 0 : 1,
    );

    final totalInches = (user.height / 2.54).round();
    _heightFtCtrl.text = (totalInches ~/ 12).toString();
    _heightInCtrl.text = (totalInches % 12).toString();
    _isMale = user.gender.trim().toLowerCase() == 'male';
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _showCompleteProfileDialog(
    _PlannerProfileStatus status,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Complete Profile First',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Meal planning needs your ${status.missingLabel}. Update your profile before generating a plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textMid),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openProfile();
            },
            child: const Text('Open Profile'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRecipeToMealLog(RecipeModel recipe) async {
    final user = context.read<AuthProvider>().userModel;
    final uid = user?.uid ?? '';
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in before saving recipes to Meal Log.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _savingRecipeIds.add(recipe.id));
    try {
      final mealProvider = context.read<MealProvider>();
      final notifications = context.read<NotificationProvider>();
      final meal = await mealProvider.addRecipeMeal(
        uid: uid,
        recipe: recipe,
        displayName: user?.name ?? '',
        photoUrl: user?.photoUrl,
        dailyBudget: user!.dailyBudget,
      );
      await notifications.createMealReminderForMeal(uid: uid, meal: meal);
      await notifications.createLogReminderForMeal(uid: uid, meal: meal);
      await notifications.createBudgetWarningIfNeeded(
        uid: uid,
        meals: mealProvider.meals,
        dailyBudget: user.dailyBudget,
        date: mealProvider.selectedDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${recipe.name} saved to Meal Log.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save recipe: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingRecipeIds.remove(recipe.id));
      }
    }
  }

  (double kg, double cm) _metricFromFields() {
    final age = int.tryParse(_ageCtrl.text.trim());
    if (age == null) throw const FormatException('Enter your age.');
    if (age < 1) throw const FormatException('Invalid age');

    if (_useMetric) {
      final w = double.tryParse(_weightCtrl.text.trim());
      final h = double.tryParse(_heightCtrl.text.trim());
      if (w == null || w <= 0) {
        throw const FormatException('Enter your weight.');
      }
      if (h == null || h <= 0) {
        throw const FormatException('Enter your height.');
      }
      return (w, h);
    }

    final lb = double.tryParse(_weightCtrl.text.trim());
    final ft = int.tryParse(_heightFtCtrl.text.trim());
    final inch = int.tryParse(_heightInCtrl.text.trim());
    if (lb == null || lb <= 0) {
      throw const FormatException('Enter your weight.');
    }
    if (ft == null || ft < 0 || inch == null || inch < 0) {
      throw const FormatException('Enter your height.');
    }
    return (
      MealPlannerService.lbToKg(lb),
      MealPlannerService.imperialHeightToCm(feet: ft, inches: inch),
    );
  }

  void _buildPlan() {
    final user = context.read<AuthProvider>().userModel;
    final profileStatus = _plannerProfileStatus(user);
    if (!profileStatus.isComplete) {
      _showCompleteProfileDialog(profileStatus);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _building = true;
      _plan = null;
      _aiBreakfast = _aiLunch = _aiDinner = _aiSnack = null;
      _selectedBasketSlots.clear();
    });

    try {
      final (kg, cm) = _metricFromFields();
      final input = MealPlannerInput(
        weightKg: kg,
        heightCm: cm,
        age: int.parse(_ageCtrl.text.trim()),
        isMale: _isMale,
        dailyBudgetPhp: user!.dailyBudget,
        budgetBufferPct: user.budgetBuffer,
        allowCalorieOnlyFallback: true,
        preferredBreakfastGroups: _preferredBreakfast.toList(),
        excludedGroups: _excludedGroups.toList(),
        algorithm: _algorithm,
      );
      final plan = MealPlannerService().buildDailyPlan(input);
      setState(() {
        _plan = plan;
        _selectedBasketSlots
          ..clear()
          ..addAll(
            plan.baskets
                .where((basket) => basket.items.isNotEmpty)
                .map((basket) => basket.slot),
          );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  Future<void> _generateAiNarratives() async {
    final plan = _plan;
    if (plan == null) return;
    if (!_groq.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set GROQ_API_KEY: flutter run --dart-define=GROQ_API_KEY=your_key',
          ),
        ),
      );
      return;
    }

    final name = context.read<AuthProvider>().userModel?.name ?? 'there';

    setState(() {
      _generatingAi = true;
      _aiBreakfast = _aiLunch = _aiDinner = _aiSnack = null;
    });

    try {
      String? b;
      String? l;
      String? d;
      String? s;
      if (plan.breakfast.items.isNotEmpty) {
        b = await _groq.generateForBasket(
          slot: PlannerMealSlot.breakfast,
          items: plan.breakfast.itemNames,
          userName: name,
        );
      }
      if (plan.lunch.items.isNotEmpty) {
        l = await _groq.generateForBasket(
          slot: PlannerMealSlot.lunch,
          items: plan.lunch.itemNames,
          userName: name,
        );
      }
      if (plan.dinner.items.isNotEmpty) {
        d = await _groq.generateForBasket(
          slot: PlannerMealSlot.dinner,
          items: plan.dinner.itemNames,
          userName: name,
        );
      }
      if (plan.snack.items.isNotEmpty) {
        s = await _groq.generateForBasket(
          slot: PlannerMealSlot.snack,
          items: plan.snack.itemNames,
          userName: name,
        );
      }
      if (mounted) {
        setState(() {
          _aiBreakfast = b;
          _aiLunch = l;
          _aiDinner = d;
          _aiSnack = s;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingAi = false);
    }
  }

  Future<void> _saveSelectedMealsToLog() async {
    final plan = _plan;
    if (plan == null) {
      _showSnack(
        'Create Davao DSS baskets before saving meals.',
        backgroundColor: AppTheme.errorRed,
      );
      return;
    }

    final selectedBaskets = plan.baskets
        .where(
          (basket) =>
              _selectedBasketSlots.contains(basket.slot) &&
              basket.items.isNotEmpty,
        )
        .toList(growable: false);

    if (selectedBaskets.isEmpty) {
      _showSnack(
        'Select at least one basket before saving.',
        backgroundColor: AppTheme.errorRed,
      );
      return;
    }

    final user = context.read<AuthProvider>().userModel;
    final uid = user?.uid ?? '';
    if (uid.isEmpty) {
      _showSnack(
        'Please sign in before saving meals to Log.',
        backgroundColor: AppTheme.errorRed,
      );
      return;
    }

    setState(() => _savingSelectedBaskets = true);

    try {
      final mealProvider = context.read<MealProvider>();
      final notifications = context.read<NotificationProvider>();
      final selectedDate = mealProvider.selectedDate;
      await mealProvider.selectDate(uid, selectedDate);

      var drafts = selectedBaskets.map(_draftFromBasket).toList();
      final duplicateTypes = drafts.map((draft) => draft.type).toSet();
      final duplicateMeals = mealProvider.meals
          .where((meal) => duplicateTypes.contains(meal.type))
          .toList(growable: false);

      if (duplicateMeals.isNotEmpty) {
        if (!mounted) return;
        setState(() => _savingSelectedBaskets = false);
        final action = await _showDuplicateBasketDialog(duplicateMeals);
        if (!mounted || action == null) return;

        if (action == _DuplicateBasketAction.skip) {
          final existingTypes = duplicateMeals.map((meal) => meal.type).toSet();
          drafts = drafts
              .where((draft) => !existingTypes.contains(draft.type))
              .toList(growable: false);
          if (drafts.isEmpty) {
            _showSnack(
              'All selected meal types already exist for ${_formatMealDate(selectedDate)}.',
              backgroundColor: AppTheme.errorRed,
            );
            return;
          }
        } else {
          setState(() => _savingSelectedBaskets = true);
          for (final meal in duplicateMeals) {
            await mealProvider.deleteMeal(uid, meal.id);
          }
        }
      }

      if (mounted) setState(() => _savingSelectedBaskets = true);
      final savedMeals = <MealModel>[];
      for (final draft in drafts) {
        final meal = await mealProvider.addPlannedMeal(
          uid: uid,
          name: draft.name,
          type: draft.type,
          price: draft.price,
          calories: draft.calories,
          protein: draft.protein,
          carbs: draft.carbs,
          fat: draft.fat,
          ingredients: draft.ingredients,
          notes: draft.notes,
          displayName: user?.name ?? '',
          photoUrl: user?.photoUrl,
          dailyBudget: user!.dailyBudget,
        );
        savedMeals.add(meal);
      }

      await notifications.createMealRemindersForMeals(
        uid: uid,
        meals: savedMeals,
      );
      await notifications.createBudgetWarningIfNeeded(
        uid: uid,
        meals: mealProvider.meals,
        dailyBudget: user!.dailyBudget,
        date: selectedDate,
      );
      if (savedMeals.isNotEmpty) {
        await notifications.createPalengkeReminder(
          uid: uid,
          date: selectedDate,
        );
      }

      if (!mounted) return;
      setState(() {
        _selectedBasketSlots.removeAll(drafts.map((draft) => draft.slot));
      });
      _showSnack(
        'Saved ${drafts.length} meal${drafts.length == 1 ? '' : 's'} to Log for ${_formatMealDate(selectedDate)}.',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'Could not save selected meals: $e',
        backgroundColor: AppTheme.errorRed,
      );
    } finally {
      if (mounted) setState(() => _savingSelectedBaskets = false);
    }
  }

  Future<_DuplicateBasketAction?> _showDuplicateBasketDialog(
    List<MealModel> duplicateMeals,
  ) {
    final labels = duplicateMeals.map((meal) => meal.typeLabel).toSet().join(
          ', ',
        );

    return showDialog<_DuplicateBasketAction>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Meal Type Already Exists',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'This date already has: $labels. NutriMind keeps one breakfast, lunch, dinner, and snack per day. Replace existing meals or skip those selected baskets?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textMid),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _DuplicateBasketAction.skip),
            child: const Text('Skip Duplicates'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, _DuplicateBasketAction.replace),
            child: const Text('Replace Existing'),
          ),
        ],
      ),
    );
  }

  NutribotContext _buildNutribotContext() {
    final user = context.read<AuthProvider>().userModel;
    final profileStatus = _plannerProfileStatus(user);

    return NutribotContext(
      source: NutribotSource.mealPlanner,
      contextTitle: 'Meal Planner',
      sourceContext: 'AI Meal Planner',
      initialPrompt:
          'Suggest meals that fit my goal, budget, and current planner settings.',
      userGoal: user?.goal,
      data: {
        if (profileStatus.isComplete && user != null)
          'dailyBudgetPhp': user.dailyBudget,
        if (profileStatus.isComplete && user != null)
          'budgetBufferPct': user.budgetBuffer,
        if (!profileStatus.isComplete)
          'missingPlannerProfileFields': profileStatus.missingFields,
        'algorithm': _algorithm.name,
        'useMetric': _useMetric,
        if (profileStatus.isComplete) 'isMale': _isMale,
        if (_preferredBreakfast.isNotEmpty)
          'preferredBreakfastGroups': _preferredBreakfast.toList(),
        if (_excludedGroups.isNotEmpty)
          'excludedGroups': _excludedGroups.toList(),
        if (_recipeMealTypeFilter != 'all')
          'recipeMealTypeFilter': _recipeMealTypeFilter,
        if (_recipeDietFilters.isNotEmpty)
          'recipeDietFilters': _recipeDietFilters.toList(),
        if (_recipeHealthFilters.isNotEmpty)
          'recipeHealthFilters': _recipeHealthFilters.toList(),
        if (_plan != null)
          'currentPlan': {
            'bmr': _plan!.bmr,
            'totalPlanCalories': _plan!.totalPlanCalories,
            'totalEstimatedPricePhp': _plan!.totalEstimatedPricePhp,
            'totalProtein': _plan!.totalProtein,
            'totalCarbs': _plan!.totalCarbs,
            'totalFat': _plan!.totalFat,
            'baskets': _plan!.baskets
                .where((basket) => basket.items.isNotEmpty)
                .map(
                  (basket) => {
                    'slot': basket.slot.label,
                    'items': basket.itemNames,
                    'calories': basket.totalCalories,
                    'pricePhp': basket.totalPricePhp,
                  },
                )
                .toList(),
          },
      },
    );
  }

  _BasketMealDraft _draftFromBasket(MealBasket basket) {
    final ingredients = <String>[];
    final seenIngredients = <String>{};

    for (final item in basket.items) {
      if (item.ingredients.isEmpty) {
        _addUniqueIngredient(ingredients, seenIngredients, item.name);
      } else {
        for (final ingredient in item.ingredients) {
          _addUniqueIngredient(ingredients, seenIngredients, ingredient);
        }
      }
    }

    final localCount = basket.items.where((item) => item.isLocalDavao).length;
    final fallbackCount =
        basket.items.where((item) => item.isCalorieOnlyFallback).length;
    final hasPriceEstimate = basket.items.any((item) => item.hasPrice);
    final noteLines = [
      'Generated from NutriMind DSS using BMR targets, Davao/local food availability, prototype estimated local prices, and estimated macros. These are not live market prices.',
      'Basket items: ${basket.itemNames.join(', ')}',
      if (localCount > 0)
        '$localCount item${localCount == 1 ? '' : 's'} came from the local Davao prototype dataset.',
      if (fallbackCount > 0)
        '$fallbackCount fallback item${fallbackCount == 1 ? '' : 's'} are calorie-only prototype estimates and were not used for strict budget calculation.',
      if (hasPriceEstimate)
        'Prototype estimated local price: PHP ${basket.totalPricePhp.toStringAsFixed(0)}.'
      else
        'No structured price estimate was available for these basket items.',
    ];

    return _BasketMealDraft(
      slot: basket.slot,
      name: 'AI ${basket.slot.label} Basket',
      type: _mealTypeForSlot(basket.slot),
      price: basket.totalPricePhp,
      calories: basket.totalCalories,
      protein: basket.totalProtein,
      carbs: basket.totalCarbs,
      fat: basket.totalFat,
      ingredients: ingredients.isEmpty ? basket.itemNames : ingredients,
      displayItems: basket.itemNames,
      fallbackItems: basket.items
          .where((item) => item.isCalorieOnlyFallback)
          .map((item) => item.name)
          .toList(growable: false),
      hasPriceEstimate: hasPriceEstimate,
      notes: noteLines.join('\n'),
    );
  }

  List<String> _basketIngredientLabels(MealBasket basket) {
    final ingredients = <String>[];
    final seen = <String>{};
    for (final item in basket.items) {
      if (item.ingredients.isEmpty) {
        _addUniqueIngredient(ingredients, seen, item.name);
      } else {
        for (final ingredient in item.ingredients) {
          _addUniqueIngredient(ingredients, seen, ingredient);
        }
      }
    }
    return ingredients;
  }

  List<String> _basketSourceLabels(MealBasket basket) {
    final labels = <String>[];
    final localCount = basket.items.where((item) => item.isLocalDavao).length;
    final prototypeCount =
        basket.items.where((item) => item.isPrototypeEstimate).length;
    final fallbackCount =
        basket.items.where((item) => item.isCalorieOnlyFallback).length;
    if (localCount > 0) {
      labels.add('$localCount local estimate');
    }
    if (prototypeCount > 0) {
      labels.add('prototype data');
    }
    if (fallbackCount > 0) labels.add('$fallbackCount calorie-only fallback');
    return labels;
  }

  void _addUniqueIngredient(
    List<String> ingredients,
    Set<String> seen,
    String value,
  ) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    if (seen.add(clean.toLowerCase())) {
      ingredients.add(clean);
    }
  }

  MealType _mealTypeForSlot(PlannerMealSlot slot) => switch (slot) {
        PlannerMealSlot.breakfast => MealType.breakfast,
        PlannerMealSlot.lunch => MealType.lunch,
        PlannerMealSlot.dinner => MealType.dinner,
        PlannerMealSlot.snack => MealType.snack,
      };

  String _formatMealDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  void _showSnack(
    String message, {
    Color backgroundColor = AppTheme.primaryGreen,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);

    if (pickedFile == null) return;

    setState(() {
      _selectedImageFile = pickedFile;
      _imageAnalysis = null;
      _analyzingImage = true;
    });

    try {
      final imageBytes = await pickedFile.readAsBytes();
      final analysis = await _groq.analyzeFoodImageBytes(imageBytes);
      if (mounted) {
        setState(() => _imageAnalysis = analysis);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Analysis failed: $e';
        if (e.toString().contains('API key is missing')) {
          errorMessage =
              'Groq API key is missing. Run Flutter with --dart-define=GROQ_API_KEY=your_key';
        } else if (e.toString().contains('permission')) {
          errorMessage =
              'Camera permission was denied. Please allow camera access or upload an image.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorMessage), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _analyzingImage = false);
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndAnalyzeImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndAnalyzeImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteProfileCard(_PlannerProfileStatus status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.assignment_ind_outlined,
              color: AppTheme.warning,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete Profile First',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Meal planning needs your ${status.missingLabel}. NutriMind will not generate a plan from default profile values.',
                  style: const TextStyle(
                    color: AppTheme.textMid,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _openProfile,
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: const Text('Open Profile'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final profileStatus = _plannerProfileStatus(user);
    _syncPlannerFieldsFromProfile(user, profileStatus);
    final breakfastKeys = MealPlannerFoodData.breakfastGroupKeys();
    final allKeys = MealPlannerFoodData.allGroupKeys();

    return Scaffold(
      backgroundColor: ModernAppTheme.backgroundNeutral,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.backgroundNeutral,
        surfaceTintColor: Colors.transparent,
        title: const Text('AI Meal Planner'),
        actions: [
          NutribotAppBarAction(
            nutribotContext: _buildNutribotContext(),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: ModernAppTheme.gradientMint,
                borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
                boxShadow: ModernAppTheme.shadowSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.48),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: ModernAppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Hi ${user?.name.split(' ').first ?? 'there'} - optimize BMR baskets, then generate Groq meal stories when you want extra guidance.',
                      style: const TextStyle(
                        color: ModernAppTheme.textDark,
                        fontSize: 13,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hi ${user?.name.split(' ').first ?? 'there'} — optimize Davao local meals from your BMR, budget, and macro needs, then optionally generate meal blurbs via Groq.',
              style: const TextStyle(
                  color: AppTheme.textMid, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),
            if (!profileStatus.isComplete) ...[
              _buildCompleteProfileCard(profileStatus),
              const SizedBox(height: 16),
            ],
            _sectionTitle('Units'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    label: Text('Metric'),
                    icon: Icon(Icons.straighten)),
                ButtonSegment(
                    value: false,
                    label: Text('Imperial'),
                    icon: Icon(Icons.balance)),
              ],
              selected: {_useMetric},
              onSelectionChanged: (s) => setState(() => _useMetric = s.first),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Profile'),
            TextFormField(
              controller: _ageCtrl,
              enabled: profileStatus.isComplete,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
              validator: (v) {
                final age = int.tryParse(v?.trim() ?? '');
                return age == null || age <= 0 ? 'Enter age' : null;
              },
            ),
            const SizedBox(height: 10),
            if (_useMetric) ...[
              TextFormField(
                controller: _weightCtrl,
                enabled: profileStatus.isComplete,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                validator: (v) {
                  final weight = double.tryParse(v?.trim() ?? '');
                  return weight == null || weight <= 0 ? 'Enter weight' : null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _heightCtrl,
                enabled: profileStatus.isComplete,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Height (cm)'),
                validator: (v) {
                  final height = double.tryParse(v?.trim() ?? '');
                  return height == null || height <= 0 ? 'Enter height' : null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: _weightCtrl,
                enabled: profileStatus.isComplete,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (lb)'),
                validator: (v) {
                  final weight = double.tryParse(v?.trim() ?? '');
                  return weight == null || weight <= 0 ? 'Enter weight' : null;
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightFtCtrl,
                      enabled: profileStatus.isComplete,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Height (ft)'),
                      validator: (v) {
                        final feet = int.tryParse(v?.trim() ?? '');
                        return feet == null || feet < 0 ? 'Enter feet' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heightInCtrl,
                      enabled: profileStatus.isComplete,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Height (in)'),
                      validator: (v) {
                        final inches = int.tryParse(v?.trim() ?? '');
                        return inches == null || inches < 0
                            ? 'Enter inches'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _sectionTitle('Gender'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Male')),
                ButtonSegment(value: false, label: Text('Female')),
              ],
              selected: {_isMale},
              onSelectionChanged: profileStatus.isComplete
                  ? (s) => setState(() => _isMale = s.first)
                  : null,
            ),
            const SizedBox(height: 20),
            _sectionTitle('Breakfast group preferences (optional)'),
            const Text(
              'If you pick none, all breakfast groups are used. Matches Streamlit multiselect on breakfast categories.',
              style: TextStyle(
                  fontSize: 11, color: AppTheme.textLight, height: 1.35),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: breakfastKeys.map((k) {
                final selected = _preferredBreakfast.contains(k);
                return FilterChip(
                  label: Text(k.replaceAll('_', ' ')),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _preferredBreakfast.add(k);
                    } else {
                      _preferredBreakfast.remove(k);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Exclude groups (allergies / avoid)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allKeys.map((k) {
                final selected = _excludedGroups.contains(k);
                return FilterChip(
                  label: Text(k.replaceAll('_', ' ')),
                  selected: selected,
                  selectedColor: AppTheme.errorRed.withValues(alpha: 0.15),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _excludedGroups.add(k);
                    } else {
                      _excludedGroups.remove(k);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Algorithm'),
            SegmentedButton<MealPlannerAlgorithm>(
              segments: const [
                ButtonSegment(
                  value: MealPlannerAlgorithm.knapsack,
                  label: Text('Knapsack'),
                  icon: Icon(Icons.functions),
                ),
                ButtonSegment(
                  value: MealPlannerAlgorithm.randomGreedy,
                  label: Text('Random greedy'),
                  icon: Icon(Icons.shuffle),
                ),
              ],
              selected: {_algorithm},
              onSelectionChanged: (s) => setState(() => _algorithm = s.first),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _building
                  ? null
                  : profileStatus.isComplete
                      ? _buildPlan
                      : () => _showCompleteProfileDialog(profileStatus),
              icon: _building
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.shopping_basket_outlined),
              label: Text(_building ? 'Building...' : 'Create DSS baskets'),
            ),
            const SizedBox(height: 24),
            _buildRecipeDatasetSection(),
            if (_plan != null) ...[
              const SizedBox(height: 24),
              _sectionTitle('Your BMR & targets'),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8, bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ModernAppTheme.white,
                  borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
                  border: Border.all(color: ModernAppTheme.divider),
                  boxShadow: ModernAppTheme.shadowSm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: ModernAppTheme.softGreen,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.local_fire_department_outlined,
                        color: ModernAppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_plan!.bmr.toStringAsFixed(1)} kcal/day target, split across breakfast, lunch, dinner, and snack baskets.',
                        style: const TextStyle(
                          color: ModernAppTheme.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Estimated BMR: ${_plan!.bmr.toStringAsFixed(1)} kcal/day '
                '(breakfast 35%, lunch 30%, dinner 25%, snack 10%). '
                'Estimated local-food cost: PHP ${_plan!.totalEstimatedPricePhp.toStringAsFixed(0)}. '
                'Macros: ${_plan!.totalProtein}g protein, ${_plan!.totalCarbs}g carbs, ${_plan!.totalFat}g fat.',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textMid, height: 1.4),
              ),
              const SizedBox(height: 12),
              _buildBasketSelectionSection(_plan!),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: (_generatingAi ||
                        _plan!.baskets.every((basket) => basket.items.isEmpty))
                    ? null
                    : _generateAiNarratives,
                icon: _generatingAi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(_generatingAi
                    ? 'Calling Groq...'
                    : 'Generate AI meal descriptions (Groq)'),
              ),
              if (!_groq.isConfigured)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Groq is optional. Build with: --dart-define=GROQ_API_KEY=... '
                    'Optional: --dart-define=GROQ_MODEL=llama-3.3-70b-versatile',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textLight, height: 1.35),
                  ),
                ),
              if (_aiBreakfast != null) ...[
                const SizedBox(height: 16),
                _aiBlock('Breakfast story', _aiBreakfast!),
              ],
              if (_aiLunch != null) _aiBlock('Lunch story', _aiLunch!),
              if (_aiDinner != null) _aiBlock('Dinner story', _aiDinner!),
              if (_aiSnack != null) _aiBlock('Snack story', _aiSnack!),
              const SizedBox(height: 24),
              _sectionTitle('🍽️ Food Image Analysis'),
              const Text(
                'Snap a photo of your meal to get instant AI-powered nutritional analysis!',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textMid, height: 1.4),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _analyzingImage ? null : _showImageSourceDialog,
                icon: _analyzingImage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt),
                label:
                    Text(_analyzingImage ? 'Analyzing...' : 'Scan Food Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_selectedImageFile != null) ...[
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FutureBuilder<Uint8List>(
                    future: _selectedImageFile!.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Center(child: Icon(Icons.error));
                      }
                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                    },
                  ),
                ),
              ],
              if (_imageAnalysis != null) ...[
                const SizedBox(height: 16),
                _aiBlock('🍲 Food Analysis', _imageAnalysis!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBasketSelectionSection(DailyMealPlan plan) {
    final availableBaskets =
        plan.baskets.where((basket) => basket.items.isNotEmpty).toList();
    final selectedCount = availableBaskets
        .where((basket) => _selectedBasketSlots.contains(basket.slot))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Select baskets to save',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$selectedCount/${availableBaskets.length} selected',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...plan.baskets.map(
          (basket) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSelectableBasketCard(basket),
          ),
        ),
        Text(
          'Total generated: ${plan.totalPlanCalories} kcal - PHP ${plan.totalEstimatedPricePhp.toStringAsFixed(0)} local-food estimate',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _savingSelectedBaskets ? null : _saveSelectedMealsToLog,
            icon: _savingSelectedBaskets
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _savingSelectedBaskets
                  ? 'Saving selected meals...'
                  : 'Save Selected Meals to Log',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableBasketCard(MealBasket basket) {
    final selected = _selectedBasketSlots.contains(basket.slot);
    final disabled = basket.items.isEmpty || _savingSelectedBaskets;
    final draft = _draftFromBasket(basket);
    final shownIngredients = _basketIngredientLabels(basket).take(8).toList();
    final sourceLabels = _basketSourceLabels(basket);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
        onTap: disabled
            ? null
            : () {
                setState(() {
                  if (selected) {
                    _selectedBasketSlots.remove(basket.slot);
                  } else {
                    _selectedBasketSlots.add(basket.slot);
                  }
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.softGreen.withValues(alpha: 0.72)
                : AppTheme.white,
            borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
            border: Border.all(
              color: selected ? AppTheme.primaryGreen : AppTheme.divider,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: ModernAppTheme.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: selected && basket.items.isNotEmpty,
                    activeColor: AppTheme.primaryGreen,
                    onChanged: disabled
                        ? null
                        : (value) {
                            setState(() {
                              if (value ?? false) {
                                _selectedBasketSlots.add(basket.slot);
                              } else {
                                _selectedBasketSlots.remove(basket.slot);
                              }
                            });
                          },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                basket.slot.label,
                                style: const TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primaryGreen
                                    : ModernAppTheme.backgroundNeutral,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                selected ? 'Selected' : 'Select',
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : AppTheme.textMid,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          basket.items.isEmpty
                              ? 'No items fit this target with current filters.'
                              : draft.displayItems.join(', '),
                          style: const TextStyle(
                            color: AppTheme.textMid,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _recipeMetric('${basket.totalCalories}', 'kcal'),
                  _recipeMetric(
                    draft.hasPriceEstimate
                        ? 'P${draft.price.toStringAsFixed(0)}'
                        : 'TBA',
                    'est. PHP',
                  ),
                  if (draft.protein > 0)
                    _recipeMetric('${draft.protein}g', 'protein'),
                  if (draft.carbs > 0)
                    _recipeMetric('${draft.carbs}g', 'carbs'),
                  if (draft.fat > 0) _recipeMetric('${draft.fat}g', 'fat'),
                ],
              ),
              if (sourceLabels.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sourceLabels.map((label) {
                    final isFallback = label.contains('fallback');
                    final isPrototype = label.contains('prototype');
                    return _sourceTag(
                      label,
                      isFallback || isPrototype
                          ? AppTheme.orangeAccent
                          : AppTheme.primaryGreen,
                    );
                  }).toList(),
                ),
              ],
              if (basket.items.any((item) => item.isPrototypeEstimate)) ...[
                const SizedBox(height: 8),
                const Text(
                  'Local prices and macros are prototype estimates, not live market prices.',
                  style: TextStyle(
                    color: AppTheme.orangeAccent,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (draft.fallbackItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Fallback items are calorie-only prototype estimates and are not counted toward strict budget totals.',
                  style: TextStyle(
                    color: AppTheme.orangeAccent,
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (shownIngredients.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: shownIngredients.map(_recipeTag).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeDatasetSection() {
    final filtered = _filteredRecipes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Recipe dataset'),
        const Text(
          RecipeDatasetService.prototypeDisclosure,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textLight,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        if (_recipesLoading)
          _recipeStateBox(
            icon: Icons.sync,
            child: const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Loading recipe dataset...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_recipesError != null)
          _recipeStateBox(
            icon: Icons.info_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _recipesError!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMid,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _loadRecipeDataset(forceReload: true),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else ...[
          _buildRecipeFilters(),
          const SizedBox(height: 12),
          Text(
            'Showing ${filtered.length} of ${_recipes.length} recipes',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMid,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            _recipeStateBox(
              icon: Icons.search_off,
              child: const Text(
                'No recipes match these filters. Try a wider calorie, price, ingredient, diet, or health-label search.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMid,
                  height: 1.35,
                ),
              ),
            )
          else ...[
            ...filtered.take(8).map(_buildRecipeCard),
            if (filtered.length > 8)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Refine filters to narrow the recipe list.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textLight,
                    height: 1.35,
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _recipeStateBox({
    required IconData icon,
    required Widget child,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
          boxShadow: ModernAppTheme.shadowSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 20),
            const SizedBox(width: 10),
            Expanded(child: child),
          ],
        ),
      );

  Widget _buildRecipeFilters() {
    const mealTypes = ['all', 'breakfast', 'lunch', 'dinner', 'snack'];
    final hasFilters = _recipeSearchCtrl.text.trim().isNotEmpty ||
        _recipeMaxCaloriesCtrl.text.trim().isNotEmpty ||
        _recipeMaxPriceCtrl.text.trim().isNotEmpty ||
        _recipeMealTypeFilter != 'all' ||
        _recipeDietFilters.isNotEmpty ||
        _recipeHealthFilters.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _recipeSearchCtrl,
          decoration: const InputDecoration(
            labelText: 'Search recipes, ingredients, diets, or health labels',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _recipeMaxCaloriesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max kcal',
                  prefixIcon: Icon(Icons.local_fire_department_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _recipeMaxPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max PHP',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: mealTypes.map((mealType) {
            final selected = _recipeMealTypeFilter == mealType;
            return ChoiceChip(
              label: Text(_titleCase(mealType)),
              selected: selected,
              onSelected: (_) =>
                  setState(() => _recipeMealTypeFilter = mealType),
            );
          }).toList(),
        ),
        if (_availableDietLabels.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRecipeLabelFilters(
            title: 'Diet labels',
            labels: _availableDietLabels.take(8).toList(),
            selected: _recipeDietFilters,
          ),
        ],
        if (_availableHealthLabels.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRecipeLabelFilters(
            title: 'Health labels',
            labels: _availableHealthLabels.take(8).toList(),
            selected: _recipeHealthFilters,
          ),
        ],
        if (hasFilters) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _recipeSearchCtrl.clear();
                  _recipeMaxCaloriesCtrl.clear();
                  _recipeMaxPriceCtrl.clear();
                  _recipeMealTypeFilter = 'all';
                  _recipeDietFilters.clear();
                  _recipeHealthFilters.clear();
                });
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear filters'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecipeLabelFilters({
    required String title,
    required List<String> labels,
    required Set<String> selected,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMid,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels.map((label) {
              final isSelected = selected.contains(label);
              return FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      selected.add(label);
                    } else {
                      selected.remove(label);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      );

  Widget _buildRecipeCard(RecipeModel recipe) {
    final saving = _savingRecipeIds.contains(recipe.id);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    recipe.mealEmoji,
                    style: const TextStyle(fontSize: 19),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      recipe.mealTypeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: saving ? null : () => _saveRecipeToMealLog(recipe),
                icon: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add_outlined, size: 16),
                label: Text(saving ? 'Saving' : 'Save'),
              ),
            ],
          ),
          if (recipe.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              recipe.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMid,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _recipeMetric('${recipe.calories}', 'kcal'),
              if (recipe.hasPriceEstimate)
                _recipeMetric(
                  'P${recipe.estimatedPricePhp.toStringAsFixed(0)}',
                  'est.',
                ),
              if (recipe.protein > 0)
                _recipeMetric('${recipe.protein}g', 'protein'),
              if (recipe.carbs > 0) _recipeMetric('${recipe.carbs}g', 'carbs'),
              if (recipe.fat > 0) _recipeMetric('${recipe.fat}g', 'fat'),
            ],
          ),
          if (recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: recipe.ingredients
                  .take(5)
                  .map((ingredient) => _recipeTag(ingredient))
                  .toList(),
            ),
          ],
          if (recipe.dietLabels.isNotEmpty || recipe.healthLabels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...recipe.dietLabels.take(3).map(_recipeLabelTag),
                  ...recipe.healthLabels.take(3).map(_recipeLabelTag),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _recipeMetric(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: ModernAppTheme.backgroundNeutral,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  Widget _recipeTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.softGreen,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _sourceTag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _recipeLabelTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.18),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textMid,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
        ),
      );

  Widget _aiBlock(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryGreen,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: AppTheme.textDark),
              ),
            ],
          ),
        ),
      );
}

enum _DuplicateBasketAction { skip, replace }

class _PlannerProfileStatus {
  const _PlannerProfileStatus(this.missingFields);

  final List<String> missingFields;

  bool get isComplete => missingFields.isEmpty;

  String get missingLabel {
    if (missingFields.isEmpty) return '';
    if (missingFields.length == 1) return missingFields.first;
    return '${missingFields.take(missingFields.length - 1).join(', ')} and ${missingFields.last}';
  }
}

class _BasketMealDraft {
  const _BasketMealDraft({
    required this.slot,
    required this.name,
    required this.type,
    required this.price,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
    required this.displayItems,
    required this.fallbackItems,
    required this.hasPriceEstimate,
    required this.notes,
  });

  final PlannerMealSlot slot;
  final String name;
  final MealType type;
  final double price;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final List<String> ingredients;
  final List<String> displayItems;
  final List<String> fallbackItems;
  final bool hasPriceEstimate;
  final String notes;
}
