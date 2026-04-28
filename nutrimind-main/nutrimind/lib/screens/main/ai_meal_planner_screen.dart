import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/meal_model.dart';
import '../../models/meal_planner_models.dart';
import '../../models/nutribot_models.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/groq_meal_narrative_service.dart';
import '../../services/meal_planner_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../widgets/nutribot/nutribot_launcher.dart';
import '../../utils/filipino_meal_namer.dart';
import 'meal_plan_screen.dart';
import 'profile_screen.dart';

/// AI Meal Planner — BMR + knapsack/greedy optimizer + optional Groq narratives.
class AiMealPlannerScreen extends StatefulWidget {
  const AiMealPlannerScreen({super.key});

  @override
  State<AiMealPlannerScreen> createState() => _AiMealPlannerScreenState();
}

class _AiMealPlannerScreenState extends State<AiMealPlannerScreen> {
  String _mealStyle = 'Balanced';
  final Set<String> _avoidItems = {};
  MealPlannerAlgorithm _algorithm = MealPlannerAlgorithm.knapsack;
  _PlanMode _planMode = _PlanMode.daily;

  DailyMealPlan? _plan;
  bool _building = false;

  List<_WeeklyDayPlan>? _weeklyPlans;
  bool _buildingWeekly = false;
  bool _savingWeekly = false;

  String? _aiBreakfast;
  String? _aiLunch;
  String? _aiDinner;
  String? _aiSnack;
  bool _generatingAi = false;
  final Set<PlannerMealSlot> _selectedBasketSlots = {};
  bool _savingSelectedBaskets = false;

  // Image analysis state
  XFile? _selectedImageFile;
  String? _imageAnalysis;
  bool _analyzingImage = false;

  late final GroqMealNarrativeService _groq;

  static const List<String> _mealStyleOptions = [
    'Balanced',
    'High Protein',
    'Low Budget',
    'Local Davao Meals',
    'Weight Loss Friendly',
    'Muscle Gain Friendly',
  ];

  static const List<String> _avoidOptions = [
    'Pork',
    'Seafood',
    'Dairy',
    'Eggs',
    'Spicy Food',
    'Expensive Ingredients',
  ];

  @override
  void initState() {
    super.initState();
    _groq = GroqMealNarrativeService();
  }

  @override
  void dispose() {
    _groq.dispose();
    super.dispose();
  }

  List<String> _mealStyleToBreakfastGroups() {
    return switch (_mealStyle) {
      'High Protein' => ['protein'],
      'Local Davao Meals' => ['local_breakfast_meals'],
      'Weight Loss Friendly' => ['fruits', 'vegetables'],
      'Muscle Gain Friendly' => ['protein', 'whole_grains'],
      _ => [],
    };
  }

  List<String> _avoidItemsToExcludedGroups() {
    final groups = <String>[];
    if (_avoidItems.contains('Pork')) {
      groups.addAll(['pork_adobo', 'pork_adobo_dinner']);
    }
    if (_avoidItems.contains('Seafood')) groups.add('fish');
    if (_avoidItems.contains('Dairy')) groups.add('dairy');
    if (_avoidItems.contains('Eggs')) groups.add('egg');
    return groups;
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

  bool _userIsMale(UserModel? user) =>
      (user?.gender ?? '').trim().toLowerCase() == 'male';

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

  void _buildPlan() {
    final user = context.read<AuthProvider>().userModel;
    final profileStatus = _plannerProfileStatus(user);
    if (!profileStatus.isComplete) {
      _showCompleteProfileDialog(profileStatus);
      return;
    }

    setState(() {
      _building = true;
      _plan = null;
      _weeklyPlans = null;
      _aiBreakfast = _aiLunch = _aiDinner = _aiSnack = null;
      _selectedBasketSlots.clear();
    });

    try {
      final currentUser = user!;
      final input = MealPlannerInput(
        weightKg: currentUser.weight,
        heightCm: currentUser.height,
        age: currentUser.age,
        isMale: _userIsMale(currentUser),
        dailyBudgetPhp: currentUser.dailyBudget,
        budgetBufferPct: currentUser.budgetBuffer,
        allowCalorieOnlyFallback: true,
        preferredBreakfastGroups: _mealStyleToBreakfastGroups(),
        excludedGroups: _avoidItemsToExcludedGroups(),
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  void _buildWeeklyPlan() {
    final user = context.read<AuthProvider>().userModel;
    final profileStatus = _plannerProfileStatus(user);
    if (!profileStatus.isComplete) {
      _showCompleteProfileDialog(profileStatus);
      return;
    }

    setState(() {
      _buildingWeekly = true;
      _weeklyPlans = null;
      _plan = null;
      _aiBreakfast = _aiLunch = _aiDinner = _aiSnack = null;
      _selectedBasketSlots.clear();
    });

    try {
      final currentUser = user!;
      final input = MealPlannerInput(
        weightKg: currentUser.weight,
        heightCm: currentUser.height,
        age: currentUser.age,
        isMale: _userIsMale(currentUser),
        dailyBudgetPhp: currentUser.dailyBudget,
        budgetBufferPct: currentUser.budgetBuffer,
        allowCalorieOnlyFallback: true,
        preferredBreakfastGroups: _mealStyleToBreakfastGroups(),
        excludedGroups: _avoidItemsToExcludedGroups(),
        algorithm: _algorithm,
      );

      final today = DateTime.now();
      final monday =
          today.subtract(Duration(days: today.weekday - 1));
      final plans = <_WeeklyDayPlan>[];
      for (var i = 0; i < 7; i++) {
        final day = DateTime(
            monday.year, monday.month, monday.day + i);
        final plan = MealPlannerService().buildDailyPlan(input);
        plans.add(_WeeklyDayPlan(day, plan));
      }

      setState(() => _weeklyPlans = plans);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _buildingWeekly = false);
    }
  }

  Future<void> _saveWeeklyMealsToLog() async {
    final weeklyPlans = _weeklyPlans;
    if (weeklyPlans == null || weeklyPlans.isEmpty) {
      _showSnack(
        'Generate a Weekly Plan before saving.',
        backgroundColor: AppTheme.errorRed,
      );
      return;
    }

    final user = context.read<AuthProvider>().userModel;
    final uid = user?.uid ?? '';
    if (uid.isEmpty) {
      _showSnack(
        'Please sign in before saving meals.',
        backgroundColor: AppTheme.errorRed,
      );
      return;
    }

    setState(() => _savingWeekly = true);

    try {
      final mealProvider = context.read<MealProvider>();
      final notifications = context.read<NotificationProvider>();
      final savedMeals = <MealModel>[];
      for (final dayPlan in weeklyPlans) {
        for (final basket in dayPlan.plan.baskets) {
          if (basket.items.isEmpty) continue;
          final draft = _draftFromBasket(basket);
          final savedMeal = await mealProvider.addPlannedMeal(
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
            imageUrl: draft.imageUrl,
            displayName: user!.name,
            photoUrl: user.photoUrl,
            dailyBudget: user.dailyBudget,
            forDate: dayPlan.date,
          );
          savedMeals.add(savedMeal);
          if (!mounted) break;
        }
        if (!mounted) break;
      }
      if (!mounted) return;

      await notifications.createMealRemindersForMeals(
        uid: uid,
        meals: savedMeals,
      );
      if (!mounted) return;

      await notifications.createBudgetWarningIfNeeded(
        uid: uid,
        meals: mealProvider.meals,
        dailyBudget: user!.dailyBudget,
        date: mealProvider.selectedDate,
      );
      if (!mounted) return;

      if (savedMeals.isNotEmpty) {
        await notifications.createPalengkeReminder(
          uid: uid,
          date: mealProvider.selectedDate,
        );
        if (!mounted) return;
      }

      setState(() => _weeklyPlans = null);
      await _showSavedDialog();
    } catch (_) {
      if (mounted) {
        _showSnack(
          'Something went wrong. Please try again.',
          backgroundColor: AppTheme.errorRed,
        );
      }
    } finally {
      if (mounted) setState(() => _savingWeekly = false);
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
        if (!mounted) return;
      }
      if (plan.lunch.items.isNotEmpty) {
        l = await _groq.generateForBasket(
          slot: PlannerMealSlot.lunch,
          items: plan.lunch.itemNames,
          userName: name,
        );
        if (!mounted) return;
      }
      if (plan.dinner.items.isNotEmpty) {
        d = await _groq.generateForBasket(
          slot: PlannerMealSlot.dinner,
          items: plan.dinner.itemNames,
          userName: name,
        );
        if (!mounted) return;
      }
      if (plan.snack.items.isNotEmpty) {
        s = await _groq.generateForBasket(
          slot: PlannerMealSlot.snack,
          items: plan.snack.itemNames,
          userName: name,
        );
        if (!mounted) return;
      }
      setState(() {
        _aiBreakfast = b;
        _aiLunch = l;
        _aiDinner = d;
        _aiSnack = s;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
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
        'Generate a meal plan before saving.',
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
        'Select at least one meal before saving.',
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
    final currentUser = user!;

    setState(() => _savingSelectedBaskets = true);

    try {
      final mealProvider = context.read<MealProvider>();
      final notifications = context.read<NotificationProvider>();
      final selectedDate = mealProvider.selectedDate;
      await mealProvider.selectDate(uid, selectedDate);
      if (!mounted) return;

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
            if (!mounted) return;
          }
        }
      }

      if (mounted) setState(() => _savingSelectedBaskets = true);
      final savedMeals = <MealModel>[];
      for (final draft in drafts) {
        final meal = await _savePlannerDraftToMealLog(
          mealProvider: mealProvider,
          uid: uid,
          user: currentUser,
          draft: draft,
        );
        if (!mounted) return;
        savedMeals.add(meal);
      }

      await notifications.createMealRemindersForMeals(
        uid: uid,
        meals: savedMeals,
      );
      if (!mounted) return;
      await notifications.createBudgetWarningIfNeeded(
        uid: uid,
        meals: mealProvider.meals,
        dailyBudget: currentUser.dailyBudget,
        date: selectedDate,
      );
      if (!mounted) return;
      if (savedMeals.isNotEmpty) {
        await notifications.createPalengkeReminder(
          uid: uid,
          date: selectedDate,
        );
        if (!mounted) return;
      }

      setState(() {
        _selectedBasketSlots.removeAll(drafts.map((draft) => draft.slot));
      });
      await _showSavedDialog();
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Something went wrong. Please try again.',
        backgroundColor: AppTheme.errorRed,
      );
    } finally {
      if (mounted) setState(() => _savingSelectedBaskets = false);
    }
  }

  Future<MealModel> _savePlannerDraftToMealLog({
    required MealProvider mealProvider,
    required String uid,
    required UserModel user,
    required _BasketMealDraft draft,
  }) {
    return mealProvider.addPlannedMeal(
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
      imageUrl: draft.imageUrl,
      displayName: user.name,
      photoUrl: user.photoUrl,
      dailyBudget: user.dailyBudget,
    );
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
          'This date already has: $labels. NutriMind keeps one breakfast, lunch, dinner, and snack per day. Replace existing meals or skip the duplicates?',
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
        'mealStyle': _mealStyle,
        if (_avoidItems.isNotEmpty) 'avoidItems': _avoidItems.toList(),
        if (profileStatus.isComplete && user != null)
          'isMale': _userIsMale(user),
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
      'Generated from NutriMind AI Meal Planner using BMR targets, Davao/local food availability, and estimated macros. These are not live market prices.',
      'Meal items: ${basket.itemNames.join(', ')}',
      if (localCount > 0)
        '$localCount item${localCount == 1 ? '' : 's'} came from the local Davao food dataset.',
      if (fallbackCount > 0)
        '$fallbackCount fallback item${fallbackCount == 1 ? '' : 's'} are calorie-only estimates and were not used for strict budget calculation.',
      if (hasPriceEstimate)
        'Estimated local price: PHP ${basket.totalPricePhp.toStringAsFixed(0)}.'
      else
        'No structured price estimate was available for these meal items.',
    ];

    return _BasketMealDraft(
      slot: basket.slot,
      name: FilipinoMealNamer.nameFromItems(
        basket.itemNames,
        basket.slot.label,
      ),
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
      imageUrl: basket.imageUrl,
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
      labels.add('estimated data');
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

  Future<bool> _confirmLeaveWhileGenerating() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Generation in progress',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Your meal is still generating. Are you sure you want to go back?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'No',
              style: TextStyle(color: AppTheme.textMid),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showSavedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppTheme.softGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: AppTheme.primaryGreen,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Meal plan saved successfully',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MealPlanScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('View My Plan'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(color: AppTheme.textMid),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _askNutribotForBasket(MealBasket basket, _BasketMealDraft draft) {
    NutribotLauncher.open(
      context,
      nutribotContext: NutribotContext(
        source: NutribotSource.mealPlanner,
        contextTitle: 'Ask NutriBot',
        sourceContext: 'AI Meal Planner basket',
        initialPrompt:
            'Help me cook or improve "${draft.name}" with these ingredients.',
        data: {
          'name': draft.name,
          'items': basket.itemNames,
          if (draft.ingredients.isNotEmpty) 'ingredients': draft.ingredients,
          if (draft.imageUrl != null && draft.imageUrl!.isNotEmpty)
            'imageUrl': draft.imageUrl,
          'calories': basket.totalCalories,
          if (draft.hasPriceEstimate) 'estimatedPricePhp': draft.price,
        },
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
      if (!mounted) return;
      final analysis = await _groq.analyzeFoodImageBytes(imageBytes);
      if (!mounted) return;
      setState(() => _imageAnalysis = analysis);
    } on PlatformException catch (e) {
      if (mounted) {
        final code = e.code.toLowerCase();
        final message = code.contains('camera_access')
            ? 'Camera access denied. Enable camera permission in Settings, or pick an image from your gallery.'
            : code.contains('photo_access') || code.contains('gallery')
                ? 'Photo library access denied. Enable photo permission in Settings.'
                : 'Could not open the camera. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(message), backgroundColor: AppTheme.errorRed),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Something went wrong. Please try again.';
        if (e.toString().contains('API key is missing')) {
          errorMessage =
              'Groq API key is missing. Run Flutter with --dart-define=GROQ_API_KEY=your_key';
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

  Widget _buildProfileSummaryCard(UserModel user) {
    final weightLabel = user.weight % 1 == 0
        ? user.weight.toStringAsFixed(0)
        : user.weight.toStringAsFixed(1);
    final heightLabel = user.height % 1 == 0
        ? user.height.toStringAsFixed(0)
        : user.height.toStringAsFixed(1);
    final genderLabel = user.gender.trim().isEmpty
        ? '—'
        : user.gender.trim().toLowerCase();
    final summary =
        '${user.age} yrs • $weightLabel kg • $heightLabel cm • $genderLabel';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.softGreen.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_circle_outlined,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Using your profile',
                  style: TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: const TextStyle(
                    color: AppTheme.textMid,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _openProfile,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        ],
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

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Meal Style'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _mealStyleOptions.map((style) {
            final selected = _mealStyle == style;
            return ChoiceChip(
              label: Text(style),
              selected: selected,
              selectedColor: AppTheme.primaryGreen,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppTheme.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              onSelected: (_) => setState(() => _mealStyle = style),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _sectionTitle('Avoid'),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _avoidOptions.map((item) {
            final selected = _avoidItems.contains(item);
            return FilterChip(
              label: Text(item),
              selected: selected,
              selectedColor: AppTheme.errorRed.withValues(alpha: 0.13),
              checkmarkColor: AppTheme.errorRed,
              labelStyle: TextStyle(
                color: selected ? AppTheme.errorRed : AppTheme.textDark,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              onSelected: (v) => setState(() {
                if (v) {
                  _avoidItems.add(item);
                } else {
                  _avoidItems.remove(item);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final profileStatus = _plannerProfileStatus(user);

    return PopScope(
      canPop: !_generatingAi,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldLeave = await _confirmLeaveWhileGenerating();
        if (shouldLeave) navigator.pop();
      },
      child: _buildScaffold(user, profileStatus),
    );
  }

  Widget _buildScaffold(UserModel? user, _PlannerProfileStatus profileStatus) {
    return Scaffold(
      backgroundColor: ModernAppTheme.bgGreen,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.bgGreen,
        surfaceTintColor: Colors.transparent,
        title: const Text('AI Meal Planner'),
        actions: [
          NutribotAppBarAction(
            nutribotContext: _buildNutribotContext(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Hero banner
          Container(
            padding: const EdgeInsets.all(18),
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
                    'Hi ${user?.name.split(' ').first ?? 'there'} — generate a Davao-friendly meal plan from your profile, budget, and goal. Prices are estimated.',
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
          const SizedBox(height: 16),

          // Profile card
          if (!profileStatus.isComplete) ...[
            _buildCompleteProfileCard(profileStatus),
            const SizedBox(height: 16),
          ] else if (user != null) ...[
            _buildProfileSummaryCard(user),
            const SizedBox(height: 16),
          ],

          // Preferences
          _buildPreferencesSection(),
          const SizedBox(height: 20),

          // Plan mode selector
          _sectionTitle('Plan Mode'),
          SegmentedButton<_PlanMode>(
            segments: const [
              ButtonSegment(
                value: _PlanMode.daily,
                label: Text('Daily Plan'),
                icon: Icon(Icons.today_outlined),
              ),
              ButtonSegment(
                value: _PlanMode.weekly,
                label: Text('Weekly Plan'),
                icon: Icon(Icons.calendar_month_outlined),
              ),
            ],
            selected: {_planMode},
            onSelectionChanged: (s) => setState(() {
              _planMode = s.first;
              _plan = null;
              _weeklyPlans = null;
              _selectedBasketSlots.clear();
            }),
          ),
          const SizedBox(height: 20),

          // Algorithm picker
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

          // Build button
          ElevatedButton.icon(
            onPressed: (_building || _buildingWeekly)
                ? null
                : profileStatus.isComplete
                    ? (_planMode == _PlanMode.daily
                        ? _buildPlan
                        : _buildWeeklyPlan)
                    : () => _showCompleteProfileDialog(profileStatus),
            icon: (_building || _buildingWeekly)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(
              (_building || _buildingWeekly)
                  ? 'Generating...'
                  : _planMode == _PlanMode.daily
                      ? 'Generate Daily Plan'
                      : 'Generate Weekly Plan',
            ),
          ),

          // Weekly plan results
          if (_weeklyPlans != null) ...[
            const SizedBox(height: 24),
            _buildWeeklyPlanSection(_weeklyPlans!),
          ],

          // Daily plan results
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
                      '${_plan!.bmr.toStringAsFixed(1)} kcal/day target, split across breakfast, lunch, dinner, and snack.',
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
            _sectionTitle('Food Image Analysis'),
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
              _aiBlock('Food Analysis', _imageAnalysis!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyPlanSection(List<_WeeklyDayPlan> weeklyPlans) {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('7-Day Meal Plan'),
        const SizedBox(height: 8),
        ...weeklyPlans.map((dayPlan) {
          final dayName = dayNames[dayPlan.date.weekday - 1];
          final dateLabel =
              '${dayPlan.date.month}/${dayPlan.date.day}/${dayPlan.date.year}';
          final plan = dayPlan.plan;
          final filledBaskets =
              plan.baskets.where((b) => b.items.isNotEmpty).toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius:
                    BorderRadius.circular(ModernAppTheme.radiusLg),
                border: Border.all(color: AppTheme.divider),
                boxShadow: ModernAppTheme.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: AppTheme.textMid,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${plan.totalPlanCalories} kcal · PHP ${plan.totalEstimatedPricePhp.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.textMid,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (filledBaskets.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...filledBaskets.map((basket) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  basket.slot.label,
                                  style: const TextStyle(
                                    color: AppTheme.primaryGreen,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  basket.itemNames.join(', '),
                                  style: const TextStyle(
                                    color: AppTheme.textDark,
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ] else ...[
                    const SizedBox(height: 8),
                    const Text(
                      'No meals generated for this day.',
                      style:
                          TextStyle(color: AppTheme.textLight, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _savingWeekly ? null : _saveWeeklyMealsToLog,
            icon: _savingWeekly
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label:
                Text(_savingWeekly ? 'Saving...' : 'Save Weekly Plan'),
          ),
        ),
      ],
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
                'Select meals to save',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$selectedCount meals selected',
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
          'Total generated: ${plan.totalPlanCalories} kcal — PHP ${plan.totalEstimatedPricePhp.toStringAsFixed(0)} local-food estimate',
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
                  ? 'Saving...'
                  : 'Save to Day Plan',
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
                    final isEstimated = label.contains('estimated');
                    return _sourceTag(
                      label,
                      isFallback || isEstimated
                          ? AppTheme.orangeAccent
                          : AppTheme.primaryGreen,
                    );
                  }).toList(),
                ),
              ],
              if (basket.items.any((item) => item.isPrototypeEstimate)) ...[
                const SizedBox(height: 8),
                const Text(
                  'Local prices and macros are estimated values, not live market data.',
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
                  'Fallback items use estimated calorie values and are not counted toward strict budget totals.',
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
              if (basket.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _askNutribotForBasket(basket, draft),
                    icon: const Icon(Icons.smart_toy_outlined, size: 16),
                    label: const Text('Ask NutriBot'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
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

enum _PlanMode { daily, weekly }

class _WeeklyDayPlan {
  const _WeeklyDayPlan(this.date, this.plan);
  final DateTime date;
  final DailyMealPlan plan;
}

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
    required this.imageUrl,
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
  final String? imageUrl;
}
