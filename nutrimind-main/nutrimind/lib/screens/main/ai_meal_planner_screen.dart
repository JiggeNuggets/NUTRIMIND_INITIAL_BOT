import 'dart:async';

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
    if (_avoidItems.contains('Spicy Food')) groups.add('spicy_food');
    if (_avoidItems.contains('Expensive Ingredients')) {
      groups.add('expensive_ingredients');
    }
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
    return normalized == 'male' ||
        normalized == 'female' ||
        normalized == 'other';
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
      final input = _plannerInputFor(currentUser);
      final plan = MealPlannerService().buildDailyPlan(input);
      final resolvedPlan =
          _planHasMeals(plan) ? plan : _buildDemoFallbackPlan(currentUser);
      setState(() {
        _plan = resolvedPlan;
        _selectedBasketSlots
          ..clear()
          ..addAll(
            resolvedPlan.baskets
                .where((basket) => basket.items.isNotEmpty)
                .map((basket) => basket.slot),
          );
      });
      if (!_planHasMeals(plan) && mounted) {
        _showSnack(
          'Planner could not match the current settings, so NutriMind loaded a safe demo meal plan instead.',
          backgroundColor: AppTheme.orangeAccent,
        );
      }
    } catch (_) {
      if (mounted) {
        final fallbackPlan = _buildDemoFallbackPlan(user!);
        setState(() {
          _plan = fallbackPlan;
          _selectedBasketSlots
            ..clear()
            ..addAll(
              fallbackPlan.baskets
                  .where((basket) => basket.items.isNotEmpty)
                  .map((basket) => basket.slot),
            );
        });
        _showSnack(
          'Planner hit an issue, so NutriMind loaded a safe demo meal plan instead.',
          backgroundColor: AppTheme.orangeAccent,
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
      final plannerService = MealPlannerService();

      final today = DateTime.now();
      final monday = today.subtract(Duration(days: today.weekday - 1));
      final plans = <_WeeklyDayPlan>[];
      var previousDayItemIds = <String>{};
      var usedFallback = false;
      for (var i = 0; i < 7; i++) {
        final day = DateTime(monday.year, monday.month, monday.day + i);
        var plan = plannerService.buildDailyPlan(
          _plannerInputFor(
            currentUser,
            extraExcluded: previousDayItemIds.toList(growable: false),
          ),
        );
        if (!_planHasMeals(plan) && previousDayItemIds.isNotEmpty) {
          plan = plannerService.buildDailyPlan(_plannerInputFor(currentUser));
        }
        if (!_planHasMeals(plan)) {
          plan = _buildDemoFallbackPlan(currentUser, dayIndex: i);
          usedFallback = true;
        }
        plans.add(_WeeklyDayPlan(day, plan));
        previousDayItemIds = _planItemIds(plan);
      }

      setState(() => _weeklyPlans = plans);
      if (usedFallback && mounted) {
        _showSnack(
          'Some weekly days needed safe demo meals to keep the planner stable.',
          backgroundColor: AppTheme.orangeAccent,
        );
      }
    } catch (_) {
      if (mounted) {
        final monday = DateTime.now().subtract(
          Duration(days: DateTime.now().weekday - 1),
        );
        setState(() {
          _weeklyPlans = List.generate(
            7,
            (index) => _WeeklyDayPlan(
              DateTime(monday.year, monday.month, monday.day + index),
              _buildDemoFallbackPlan(user!, dayIndex: index),
            ),
          );
        });
        _showSnack(
          'Weekly planner hit an issue, so NutriMind loaded safe demo meal suggestions instead.',
          backgroundColor: AppTheme.orangeAccent,
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

    final currentUser = user!;
    setState(() => _savingWeekly = true);
    var failureStage = 'start';
    var failureContext = '';

    try {
      final mealProvider = context.read<MealProvider>();
      final notifications = context.read<NotificationProvider>();
      failureStage = 'getMealsForWeek';
      failureContext = 'anchorDate=${weeklyPlans.first.date.toIso8601String()}';
      debugPrint(
        '[WeeklySave] stage=$failureStage $failureContext weeklyDays=${weeklyPlans.length}',
      );
      final existingMeals = await mealProvider.getMealsForWeek(
        uid,
        weeklyPlans.first.date,
      );
      debugPrint(
        '[WeeklySave] stage=$failureStage success existingMeals=${existingMeals.length}',
      );
      final existingKeys = existingMeals
          .map((meal) => _mealDateTypeKey(meal.date, meal.type))
          .toSet();
      final savedMeals = <MealModel>[];
      var skippedMeals = 0;
      for (final dayPlan in weeklyPlans) {
        for (final basket in dayPlan.plan.baskets) {
          if (basket.items.isEmpty) continue;
          final draft = _draftFromBasket(basket);
          final mealKey = _mealDateTypeKey(dayPlan.date, draft.type);
          if (existingKeys.contains(mealKey)) {
            skippedMeals++;
            continue;
          }
          failureStage = 'addPlannedMeal';
          failureContext =
              'date=${dayPlan.date.toIso8601String()} type=${draft.type.name} name=${draft.name}';
          debugPrint('[WeeklySave] stage=$failureStage $failureContext');
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
            displayName: currentUser.name,
            photoUrl: currentUser.photoUrl,
            dailyBudget: currentUser.dailyBudget,
            forDate: dayPlan.date,
          );
          savedMeals.add(savedMeal);
          existingKeys.add(mealKey);
          debugPrint(
            '[WeeklySave] stage=$failureStage success mealId=${savedMeal.id} $failureContext',
          );
          if (!mounted) break;
        }
        if (!mounted) break;
      }
      if (!mounted) return;
      if (savedMeals.isEmpty) {
        _showSnack(
          skippedMeals > 0
              ? 'Nothing new to save. This weekly plan already exists in your Meal Log.'
              : 'No meals were available to save from this weekly plan.',
          backgroundColor:
              skippedMeals > 0 ? AppTheme.orangeAccent : AppTheme.errorRed,
        );
        return;
      }

      _runOptionalMealSideEffect(
        operation: 'WeeklySave.notificationCreation.mealReminders',
        context:
            'uid=$uid savedMeals=${savedMeals.length} selectedDate=${mealProvider.selectedDate.toIso8601String()}',
        action: () => notifications.createMealRemindersForMeals(
          uid: uid,
          meals: savedMeals,
        ),
      );
      _runOptionalMealSideEffect(
        operation: 'WeeklySave.notificationCreation.budgetWarning',
        context:
            'uid=$uid savedMeals=${savedMeals.length} selectedDate=${mealProvider.selectedDate.toIso8601String()}',
        action: () => notifications.createBudgetWarningIfNeeded(
          uid: uid,
          meals: mealProvider.meals,
          dailyBudget: currentUser.dailyBudget,
          date: mealProvider.selectedDate,
        ),
      );
      _runOptionalMealSideEffect(
        operation: 'WeeklySave.notificationCreation.palengkeReminder',
        context:
            'uid=$uid savedMeals=${savedMeals.length} selectedDate=${mealProvider.selectedDate.toIso8601String()}',
        action: () => notifications.createPalengkeReminder(
          uid: uid,
          date: mealProvider.selectedDate,
        ),
      );

      _showSnack(
        skippedMeals > 0
            ? 'Saved ${savedMeals.length} weekly meal${savedMeals.length == 1 ? '' : 's'} and skipped $skippedMeals duplicate meal${skippedMeals == 1 ? '' : 's'}.'
            : 'Saved ${savedMeals.length} weekly meal${savedMeals.length == 1 ? '' : 's'} to Meal Log.',
        backgroundColor:
            skippedMeals > 0 ? AppTheme.orangeAccent : AppTheme.primaryGreen,
      );
      setState(() => _weeklyPlans = null);
      await _showSavedDialog();
    } on TimeoutException catch (e, st) {
      debugPrint(
        '[WeeklySave] timeout stage=$failureStage context="$failureContext" error=$e',
      );
      debugPrintStack(label: '[WeeklySave] timeout stack', stackTrace: st);
      if (mounted) {
        _showSnack(
          'Save timed out. Please check your connection and try again.',
          backgroundColor: AppTheme.errorRed,
        );
      }
    } catch (e, st) {
      debugPrint(
        '[WeeklySave] genericCatch stage=$failureStage context="$failureContext" error=$e',
      );
      debugPrintStack(label: '[WeeklySave] genericCatch stack', stackTrace: st);
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
    final name = context.read<AuthProvider>().userModel?.name ?? 'there';
    if (!_groq.isConfigured) {
      setState(() {
        _aiBreakfast = _localNarrativeForBasket(
          slot: PlannerMealSlot.breakfast,
          items: plan.breakfast.itemNames,
          userName: name,
        );
        _aiLunch = _localNarrativeForBasket(
          slot: PlannerMealSlot.lunch,
          items: plan.lunch.itemNames,
          userName: name,
        );
        _aiDinner = _localNarrativeForBasket(
          slot: PlannerMealSlot.dinner,
          items: plan.dinner.itemNames,
          userName: name,
        );
        _aiSnack = _localNarrativeForBasket(
          slot: PlannerMealSlot.snack,
          items: plan.snack.itemNames,
          userName: name,
        );
      });
      _showSnack(
        'Groq is optional. NutriMind generated local meal descriptions for the demo.',
        backgroundColor: AppTheme.orangeAccent,
      );
      return;
    }

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
        setState(() {
          _aiBreakfast = _localNarrativeForBasket(
            slot: PlannerMealSlot.breakfast,
            items: plan.breakfast.itemNames,
            userName: name,
          );
          _aiLunch = _localNarrativeForBasket(
            slot: PlannerMealSlot.lunch,
            items: plan.lunch.itemNames,
            userName: name,
          );
          _aiDinner = _localNarrativeForBasket(
            slot: PlannerMealSlot.dinner,
            items: plan.dinner.itemNames,
            userName: name,
          );
          _aiSnack = _localNarrativeForBasket(
            slot: PlannerMealSlot.snack,
            items: plan.snack.itemNames,
            userName: name,
          );
        });
        _showSnack(
          'AI descriptions failed, so NutriMind switched to local demo descriptions.',
          backgroundColor: AppTheme.orangeAccent,
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
    var failureStage = 'start';
    var failureContext = '';

    try {
      final mealProvider = context.read<MealProvider>();
      final notifications = context.read<NotificationProvider>();
      final selectedDate = mealProvider.selectedDate;

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
            failureStage = 'deleteDuplicateMeal';
            failureContext =
                'uid=$uid mealId=${meal.id} selectedDate=${selectedDate.toIso8601String()}';
            debugPrint('[DayPlanSave] stage=$failureStage $failureContext');
            await mealProvider.deleteMeal(uid, meal.id);
            if (!mounted) return;
          }
        }
      }

      if (mounted) setState(() => _savingSelectedBaskets = true);
      final savedMeals = <MealModel>[];
      for (final draft in drafts) {
        failureStage = 'addPlannedMeal';
        failureContext =
            'uid=$uid selectedDate=${selectedDate.toIso8601String()} type=${draft.type.name} name=${draft.name}';
        debugPrint('[DayPlanSave] stage=$failureStage $failureContext');
        final meal = await _savePlannerDraftToMealLog(
          mealProvider: mealProvider,
          uid: uid,
          user: currentUser,
          draft: draft,
        ).timeout(const Duration(seconds: 30));
        if (!mounted) return;
        savedMeals.add(meal);
        debugPrint(
          '[DayPlanSave] stage=$failureStage success uid=$uid mealId=${meal.id} selectedDate=${selectedDate.toIso8601String()}',
        );
      }

      _runOptionalMealSideEffect(
        operation: 'DayPlan.notificationCreation.mealReminders',
        context:
            'uid=$uid savedMeals=${savedMeals.length} selectedDate=${selectedDate.toIso8601String()}',
        action: () => notifications.createMealRemindersForMeals(
          uid: uid,
          meals: savedMeals,
        ),
      );
      _runOptionalMealSideEffect(
        operation: 'DayPlan.notificationCreation.budgetWarning',
        context:
            'uid=$uid savedMeals=${savedMeals.length} selectedDate=${selectedDate.toIso8601String()}',
        action: () => notifications.createBudgetWarningIfNeeded(
          uid: uid,
          meals: mealProvider.meals,
          dailyBudget: currentUser.dailyBudget,
          date: selectedDate,
        ),
      );
      _runOptionalMealSideEffect(
        operation: 'DayPlan.notificationCreation.palengkeReminder',
        context:
            'uid=$uid savedMeals=${savedMeals.length} selectedDate=${selectedDate.toIso8601String()}',
        action: () =>
            notifications.createPalengkeReminder(uid: uid, date: selectedDate),
      );

      setState(() {
        _selectedBasketSlots.removeAll(drafts.map((draft) => draft.slot));
      });
      await _showSavedDialog();
    } on TimeoutException catch (e, st) {
      debugPrint(
        '[DayPlanSave] timeout stage=$failureStage context="$failureContext" error=$e',
      );
      debugPrintStack(label: '[DayPlanSave] timeout stack', stackTrace: st);
      if (!mounted) return;
      _showSnack(
        'Save timed out. Please check your connection and try again.',
        backgroundColor: AppTheme.errorRed,
      );
    } catch (e, st) {
      debugPrint(
        '[DayPlanSave] genericCatch stage=$failureStage context="$failureContext" error=$e',
      );
      debugPrintStack(
          label: '[DayPlanSave] genericCatch stack', stackTrace: st);
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

  void _runOptionalMealSideEffect({
    required String operation,
    required String context,
    required Future<void> Function() action,
  }) {
    debugPrint('[MealOptional] operation=$operation context="$context" start');
    unawaited(
      action().timeout(const Duration(seconds: 8)).then((_) {
        debugPrint(
          '[MealOptional] operation=$operation context="$context" success',
        );
      }).catchError((Object e, StackTrace st) {
        debugPrint(
          '[MealOptional] operation=$operation context="$context" failed error=$e',
        );
        debugPrintStack(
          label: '[MealOptional] operation=$operation stack',
          stackTrace: st,
        );
      }),
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
        scrollable: true,
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
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

  bool _planHasMeals(DailyMealPlan plan) =>
      plan.baskets.any((basket) => basket.items.isNotEmpty);

  Set<String> _planItemIds(DailyMealPlan plan) {
    return plan.baskets
        .expand((basket) => basket.items)
        .map((item) => item.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  String _formatMealDate(DateTime date) =>
      '${date.month}/${date.day}/${date.year}';

  String _mealDateTypeKey(DateTime date, MealType type) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year-$month-$day|${type.name}';
  }

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

  MealPlannerInput _plannerInputFor(
    UserModel user, {
    List<String> extraExcluded = const [],
  }) {
    final excludedGroups = <String>{
      ..._avoidItemsToExcludedGroups(),
      if (_mealStyle == 'Low Budget') 'expensive_ingredients',
      ...extraExcluded.map((value) => value.trim()).where(
            (value) => value.isNotEmpty,
          ),
    };
    return MealPlannerInput(
      weightKg: user.weight,
      heightCm: user.height,
      age: user.age,
      isMale: _userIsMale(user),
      dailyBudgetPhp: user.dailyBudget,
      budgetBufferPct: _mealStyle == 'Low Budget' ? 0 : user.budgetBuffer,
      allowCalorieOnlyFallback: user.allowNonLocal,
      preferredBreakfastGroups: _mealStyleToBreakfastGroups(),
      excludedGroups: excludedGroups.toList(growable: false),
      algorithm: _algorithm,
    );
  }

  /// Returns a demo fallback [DailyMealPlan] whose meals vary by [dayIndex].
  ///
  /// Three rotating sets (A / B / C) prevent every fallback day from showing
  /// the same meals.  dayIndex 0,3,6 → set A; 1,4 → set B; 2,5 → set C.
  /// The normal MealPlannerService generation path is completely unaffected.
  DailyMealPlan _buildDemoFallbackPlan(UserModel user, {int dayIndex = 0}) {
    final targetBudget = user.dailyBudget > 0 ? user.dailyBudget : 150;
    final rotation = dayIndex % 3; // 0 = set A, 1 = set B, 2 = set C

    // ── Set A (Mon / Thu / Sun) ──────────────────────────────────────────────
    if (rotation == 0) {
      return DailyMealPlan(
        bmr: 1850,
        breakfast: _demoBasket(
          slot: PlannerMealSlot.breakfast,
          targetCalories: 650,
          items: [
            _demoItem(
              id: 'demo-bf-a1',
              name: 'Arroz Caldo',
              calories: 320,
              pricePhp: targetBudget * 0.20,
              protein: 16,
              carbs: 42,
              fat: 8,
              category: 'local_breakfast_meals',
              imageUrl: 'assets/images/food/arroz_caldo.jpg',
            ),
            _demoItem(
              id: 'demo-bf-a2',
              name: 'Boiled Egg',
              calories: 78,
              pricePhp: targetBudget * 0.06,
              protein: 6,
              carbs: 1,
              fat: 5,
              category: 'protein',
            ),
          ],
        ),
        lunch: _demoBasket(
          slot: PlannerMealSlot.lunch,
          targetCalories: 555,
          items: [
            _demoItem(
              id: 'demo-ln-a1',
              name: 'Chicken Adobo',
              calories: 430,
              pricePhp: targetBudget * 0.28,
              protein: 31,
              carbs: 42,
              fat: 15,
              category: 'local_lunch_meals',
              imageUrl: 'assets/images/food/chicken_adobo.jpg',
            ),
          ],
        ),
        dinner: _demoBasket(
          slot: PlannerMealSlot.dinner,
          targetCalories: 463,
          items: [
            _demoItem(
              id: 'demo-dn-a1',
              name: 'Tinolang Manok',
              calories: 360,
              pricePhp: targetBudget * 0.27,
              protein: 30,
              carbs: 25,
              fat: 14,
              category: 'local_dinner_meals',
              imageUrl: 'assets/images/food/tinola_manok.jpg',
            ),
          ],
        ),
        snack: _demoBasket(
          slot: PlannerMealSlot.snack,
          targetCalories: 185,
          items: [
            _demoItem(
              id: 'demo-sn-a1',
              name: 'Fruit Cup',
              calories: 120,
              pricePhp: targetBudget * 0.10,
              carbs: 28,
              category: 'local_snacks',
            ),
          ],
        ),
      );
    }

    // ── Set B (Tue / Fri) ────────────────────────────────────────────────────
    if (rotation == 1) {
      return DailyMealPlan(
        bmr: 1850,
        breakfast: _demoBasket(
          slot: PlannerMealSlot.breakfast,
          targetCalories: 650,
          items: [
            _demoItem(
              id: 'demo-bf-b1',
              name: 'Champorado',
              calories: 310,
              pricePhp: targetBudget * 0.16,
              protein: 6,
              carbs: 62,
              fat: 5,
              category: 'local_breakfast_meals',
              imageUrl: 'assets/images/food/champorado.jpg',
            ),
            _demoItem(
              id: 'demo-bf-b2',
              name: 'Tuna Pandesal',
              calories: 240,
              pricePhp: targetBudget * 0.14,
              protein: 16,
              carbs: 25,
              fat: 8,
              category: 'sandwich',
            ),
          ],
        ),
        lunch: _demoBasket(
          slot: PlannerMealSlot.lunch,
          targetCalories: 555,
          items: [
            _demoItem(
              id: 'demo-ln-b1',
              name: 'Sinigang na Bangus',
              calories: 420,
              pricePhp: targetBudget * 0.32,
              protein: 35,
              carbs: 28,
              fat: 16,
              category: 'local_lunch_meals',
              imageUrl: 'assets/images/food/bangus_sinigang.jpg',
            ),
          ],
        ),
        dinner: _demoBasket(
          slot: PlannerMealSlot.dinner,
          targetCalories: 463,
          items: [
            _demoItem(
              id: 'demo-dn-b1',
              name: 'Ginisang Gulay',
              calories: 220,
              pricePhp: targetBudget * 0.18,
              protein: 8,
              carbs: 26,
              fat: 10,
              category: 'local_dinner_meals',
            ),
            _demoItem(
              id: 'demo-dn-b2',
              name: 'Grilled Fish',
              calories: 280,
              pricePhp: targetBudget * 0.20,
              protein: 32,
              carbs: 8,
              fat: 12,
              category: 'local_dinner_meals',
              imageUrl: 'assets/images/food/grilled_fish.jpg',
            ),
          ],
        ),
        snack: _demoBasket(
          slot: PlannerMealSlot.snack,
          targetCalories: 185,
          items: [
            _demoItem(
              id: 'demo-sn-b1',
              name: 'Boiled Saba',
              calories: 160,
              pricePhp: targetBudget * 0.08,
              carbs: 40,
              category: 'local_snacks',
            ),
          ],
        ),
      );
    }

    // ── Set C (Wed / Sat) ────────────────────────────────────────────────────
    return DailyMealPlan(
      bmr: 1850,
      breakfast: _demoBasket(
        slot: PlannerMealSlot.breakfast,
        targetCalories: 650,
        items: [
          _demoItem(
            id: 'demo-bf-c1',
            name: 'Garlic Rice with Egg',
            calories: 430,
            pricePhp: targetBudget * 0.18,
            protein: 12,
            carbs: 58,
            fat: 16,
            category: 'local_breakfast_meals',
          ),
          _demoItem(
            id: 'demo-bf-c2',
            name: 'Taho',
            calories: 180,
            pricePhp: targetBudget * 0.08,
            protein: 7,
            carbs: 32,
            fat: 4,
            category: 'local_breakfast_meals',
          ),
        ],
      ),
      lunch: _demoBasket(
        slot: PlannerMealSlot.lunch,
        targetCalories: 555,
        items: [
          _demoItem(
            id: 'demo-ln-c1',
            name: 'Monggo with Malunggay',
            calories: 330,
            pricePhp: targetBudget * 0.20,
            protein: 18,
            carbs: 48,
            fat: 8,
            category: 'local_lunch_meals',
            imageUrl: 'assets/images/food/monggo_soup.jpg',
          ),
          _demoItem(
            id: 'demo-ln-c2',
            name: 'Pandesal',
            calories: 120,
            pricePhp: targetBudget * 0.05,
            protein: 4,
            carbs: 22,
            fat: 2,
            category: 'bakery',
          ),
        ],
      ),
      dinner: _demoBasket(
        slot: PlannerMealSlot.dinner,
        targetCalories: 463,
        items: [
          _demoItem(
            id: 'demo-dn-c1',
            name: 'Pinakbet',
            calories: 300,
            pricePhp: targetBudget * 0.22,
            protein: 11,
            carbs: 35,
            fat: 13,
            category: 'local_dinner_meals',
            imageUrl: 'assets/images/food/pinakbet.jpg',
          ),
        ],
      ),
      snack: _demoBasket(
        slot: PlannerMealSlot.snack,
        targetCalories: 185,
        items: [
          _demoItem(
            id: 'demo-sn-c1',
            name: 'Peanuts',
            calories: 170,
            pricePhp: targetBudget * 0.08,
            protein: 8,
            carbs: 6,
            fat: 14,
            category: 'local_snacks',
          ),
        ],
      ),
    );
  }

  MealBasket _demoBasket({
    required PlannerMealSlot slot,
    required double targetCalories,
    required List<PlannerFoodItem> items,
  }) {
    return MealBasket(
      slot: slot,
      items: items,
      totalCalories: items.fold(0, (sum, item) => sum + item.calories),
      targetCalories: targetCalories,
    );
  }

  PlannerFoodItem _demoItem({
    required String id,
    required String name,
    required int calories,
    double? pricePhp,
    int protein = 0,
    int carbs = 0,
    int fat = 0,
    String category = '',
    String? imageUrl,
  }) {
    return PlannerFoodItem(
      id: id,
      name: name,
      calories: calories,
      source: PlannerFoodSource.localDavaoFoods,
      pricePhp: pricePhp,
      protein: protein,
      carbs: carbs,
      fat: fat,
      ingredients: [name],
      imageUrl: imageUrl,
      mealType: category,
      category: category,
      dataSource: 'NutriMind demo fallback',
      sourceType: 'demo_fallback',
    );
  }

  String _localNarrativeForBasket({
    required PlannerMealSlot slot,
    required List<String> items,
    required String userName,
  }) {
    if (items.isEmpty) return '';
    final joinedItems = items.join(', ');
    return '$userName, your ${slot.label.toLowerCase()} focuses on $joinedItems. '
        'This is a practical demo suggestion that fits the current planner settings and keeps the flow moving even without live AI.';
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
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
                    Navigator.of(context).pop(true);
                  },
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('Back to Meal Log'),
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
          SnackBar(content: Text(message), backgroundColor: AppTheme.errorRed),
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
    final genderLabel =
        user.gender.trim().isEmpty ? '—' : user.gender.trim().toLowerCase();
    final summary =
        '${user.age} yrs • $weightLabel kg • $heightLabel cm • $genderLabel';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.softGreen.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
        border:
            Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.22)),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_PlanMode>(
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
              ),
              const SizedBox(height: 20),

              // Algorithm picker
              _sectionTitle('Algorithm'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<MealPlannerAlgorithm>(
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
                  onSelectionChanged: (s) =>
                      setState(() => _algorithm = s.first),
                ),
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
              if (_building || _buildingWeekly) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _planMode == _PlanMode.daily
                              ? 'Building your meal suggestions...'
                              : 'Building your weekly meal suggestions...',
                          style: const TextStyle(
                            color: AppTheme.textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                    borderRadius:
                        BorderRadius.circular(ModernAppTheme.radiusLg),
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
                          _plan!.baskets
                              .every((basket) => basket.items.isEmpty))
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
                      'AI descriptions are optional; local meal suggestions remain available for demo stability.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textLight,
                          height: 1.35),
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
                  label: Text(
                      _analyzingImage ? 'Analyzing...' : 'Scan Food Image'),
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
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
        ),
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
                borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
                border: Border.all(color: AppTheme.divider),
                boxShadow: ModernAppTheme.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          color: AppTheme.textMid,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                      style: TextStyle(color: AppTheme.textLight, fontSize: 12),
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
            label: Text(_savingWeekly ? 'Saving...' : 'Save Weekly Plan'),
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
              _savingSelectedBaskets ? 'Saving...' : 'Save to Day Plan',
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
