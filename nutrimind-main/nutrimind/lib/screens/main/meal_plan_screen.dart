import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/meal_model.dart';
import '../../models/nutribot_models.dart';
import '../../services/meal_swap_service.dart';
import '../../widgets/nutribot/nutribot_launcher.dart';
import '../../widgets/safe_image.dart';
import '../../widgets/state_views.dart';
import 'ai_meal_planner_screen.dart';
import 'food_scanner_screen.dart';
import 'generated_recipe_screen.dart';
import 'recipe_browser_screen.dart';
import 'weekly_palengke_list_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealSwapSheet extends StatelessWidget {
  const _MealSwapSheet({
    required this.meal,
    required this.options,
    required this.onChoose,
  });

  final MealModel meal;
  final List<MealSwapOption> options;
  final Future<void> Function(MealSwapOption option) onChoose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: ModernAppTheme.shadowXl,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Swap Meal',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: AppTheme.textMid),
                  ),
                ],
              ),
              Text(
                'Replace ${meal.name} with an alternative from the existing Meal Planner dataset.',
                style: const TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.orangeAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.orangeAccent.withValues(alpha: 0.28),
                  ),
                ),
                child: const Text(
                  'Note: local prices and macros are estimates, not live market prices.',
                  style: TextStyle(
                    color: AppTheme.orangeAccent,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MealSwapOptionCard(
                    option: option,
                    onChoose:
                        option.isAvailable ? () => onChoose(option) : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealSwapOptionCard extends StatelessWidget {
  const _MealSwapOptionCard({
    required this.option,
    required this.onChoose,
  });

  final MealSwapOption option;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final food = option.food;
    final available = food != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: available ? ModernAppTheme.backgroundNeutral : AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _optionColor(option.type).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _optionIcon(option.type),
                  color: _optionColor(option.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.type.label,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      option.reason,
                      style: TextStyle(
                        color: available
                            ? AppTheme.primaryGreen
                            : AppTheme.textLight,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (food != null) ...[
            const SizedBox(height: 12),
            Text(
              food.name,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _swapMetric(
                  'PHP ${food.estimatedPricePhp.toStringAsFixed(0)}',
                  'est. price',
                ),
                _swapMetric('${food.calories}', 'kcal'),
                if (food.protein > 0)
                  _swapMetric('${food.protein}g', 'protein'),
              ],
            ),
            if (food.healthNote.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                food.healthNote,
                style: const TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onChoose,
                icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                label: const Text('Replace'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _swapMetric(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.divider),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          children: [
            TextSpan(text: value),
            TextSpan(
              text: ' $label',
              style: const TextStyle(
                color: AppTheme.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _optionIcon(MealSwapOptionType type) {
    return switch (type) {
      MealSwapOptionType.cheaper => Icons.savings_outlined,
      MealSwapOptionType.higherProtein => Icons.fitness_center_rounded,
      MealSwapOptionType.lowerCalorie => Icons.local_fire_department_outlined,
    };
  }

  static Color _optionColor(MealSwapOptionType type) {
    return switch (type) {
      MealSwapOptionType.cheaper => AppTheme.primaryGreen,
      MealSwapOptionType.higherProtein => AppTheme.infoBlue,
      MealSwapOptionType.lowerCalorie => AppTheme.orangeAccent,
    };
  }
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late DateTime _weekStart;
  late List<DateTime> _weekDays;

  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekDays = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
  }

  Future<void> _selectDay(DateTime day) async {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    try {
      await context.read<MealProvider>().selectDate(uid, day);
    } catch (_) {
      // MealProvider exposes the user-facing error snackbar from build().
    }
  }

  Future<void> _handleLogTap(MealModel meal) async {
    final choice = await _showLogChoiceSheet();
    if (!mounted || choice == null) return;
    if (choice == _LogChoice.scan) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
      );
      return;
    }
    final confirmed = await _confirmManualLog(meal);
    if (!mounted || !confirmed) return;
    await _logMeal(meal.id);
  }

  Future<_LogChoice?> _showLogChoiceSheet() {
    return showModalBottomSheet<_LogChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: ModernAppTheme.shadowLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How do you want to log this meal?',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pop(sheetCtx, _LogChoice.scan),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan this meal'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pop(sheetCtx, _LogChoice.manual),
                  icon: const Icon(Icons.edit_outlined,
                      color: AppTheme.primaryGreen),
                  label: const Text(
                    'Manual log this meal',
                    style: TextStyle(color: AppTheme.primaryGreen),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    side: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textMid),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmManualLog(MealModel meal) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Manual Log',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meal.name,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${meal.calories} kcal',
              style: const TextStyle(color: AppTheme.textMid, fontSize: 13),
            ),
            if (meal.price > 0) ...[
              const SizedBox(height: 4),
              Text(
                '₱${meal.price.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: AppTheme.textMid, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Log this meal to your day?',
              style: TextStyle(
                color: AppTheme.textMid,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textMid),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Log'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _logMeal(String mealId) async {
    final user = context.read<AuthProvider>().userModel;
    final uid = user?.uid ?? '';
    if (uid.isEmpty || mealId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Unable to log meal — please sign in first.'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    final mealProvider = context.read<MealProvider>();
    await mealProvider.logMeal(
      uid,
      mealId,
      displayName: user?.name ?? '',
      photoUrl: user?.photoUrl,
      dailyBudget: user?.dailyBudget ?? 150,
    );
    if (!mounted) return;
    if (mealProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mealProvider.error!),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
      mealProvider.clearError();
      return;
    }
    await context.read<NotificationProvider>().createBudgetWarningIfNeeded(
          uid: uid,
          meals: mealProvider.meals,
          dailyBudget: user?.dailyBudget ?? 150,
          date: mealProvider.selectedDate,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Meal logged successfully!'),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _deleteMeal(String mealId) async {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Meal',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Remove this meal from your plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppTheme.textMid)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              minimumSize: const Size(0, 42),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await context.read<MealProvider>().deleteMeal(uid, mealId);
      } catch (_) {
        // MealProvider exposes the user-facing error snackbar from build().
      }
    }
  }

  Future<void> _openSwapSheet(MealModel meal) async {
    final user = context.read<AuthProvider>().userModel;
    final options = MealSwapService.buildOptions(meal, userGoal: user?.goal);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealSwapSheet(
        meal: meal,
        options: options,
        onChoose: (option) async {
          Navigator.of(context).pop();
          await _confirmAndApplySwap(meal, option);
        },
      ),
    );
  }

  Future<void> _confirmAndApplySwap(
    MealModel meal,
    MealSwapOption option,
  ) async {
    final food = option.food;
    final user = context.read<AuthProvider>().userModel;
    final uid = user?.uid ?? '';
    if (food == null || uid.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Meal Swap',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Replace "${meal.name}" with "${food.name}"?\n\n'
          'This updates your Meal Log only after confirmation. Local prices and macros are estimates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textMid),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace Meal'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<MealProvider>().replaceMealWithSwap(
            uid: uid,
            mealId: meal.id,
            option: option,
            displayName: user?.name ?? '',
            photoUrl: user?.photoUrl,
            dailyBudget: user?.dailyBudget ?? 150,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Swapped to ${food.name}.'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not swap meal. Please try again.'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAiMealPlanner() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiMealPlannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mealProv = context.watch<MealProvider>();
    if (mealProv.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mealProv.error!),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
        mealProv.clearError();
      });
    }
    final selected = mealProv.selectedDate;

    // Group meals by type and limit to 4 per day (breakfast, lunch, dinner, snack)
    final orderedMeals = _orderedMeals(mealProv.meals);

    return Scaffold(
      backgroundColor: ModernAppTheme.bgGreen,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.bgGreen,
        surfaceTintColor: Colors.transparent,
        title: const Text('Meal Log'),
        actions: [
          NutribotAppBarAction(
            nutribotContext: _buildNutribotContext(mealProv),
          ),
          IconButton(
            tooltip: 'Browse Recipes',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecipeBrowserScreen()),
            ),
          ),
          IconButton(
            tooltip: 'AI Meal Planner',
            icon: const Icon(Icons.psychology_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiMealPlannerScreen()),
            ),
          ),
          if (mealProv.loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryGreen)),
              ),
            )
          else
            TextButton.icon(
              onPressed: _openAiMealPlanner,
              icon: const Icon(Icons.auto_awesome,
                  size: 14, color: AppTheme.primaryGreen),
              label: const Text('Plan',
                  style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Week header
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ModernAppTheme.white,
              borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
              border: Border.all(color: ModernAppTheme.divider),
              boxShadow: ModernAppTheme.shadowSm,
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Week of ${DateFormat('MMM d').format(_weekStart)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMid,
                          fontWeight: FontWeight.w600),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(selected),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textMid),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _weekDays.map((day) {
                    final isSel = DateFormat('yyyy-MM-dd').format(day) ==
                        DateFormat('yyyy-MM-dd').format(selected);
                    final isToday = DateFormat('yyyy-MM-dd').format(day) ==
                        DateFormat('yyyy-MM-dd').format(DateTime.now());
                    return GestureDetector(
                      onTap: () => _selectDay(day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 60,
                        decoration: BoxDecoration(
                          color: isSel
                              ? ModernAppTheme.primaryGreen
                              : ModernAppTheme.backgroundNeutral,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel
                                ? AppTheme.primaryGreen
                                : isToday
                                    ? AppTheme.accentGreen
                                    : AppTheme.divider,
                            width: isToday && !isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(day)[0],
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    isSel ? Colors.white70 : AppTheme.textMid,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 16,
                                color: isSel ? Colors.white : AppTheme.textDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RecipeBrowserScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('Browse Recipe Library'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WeeklyPalengkeListScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_basket_outlined, size: 18),
                    label: const Text('View Palengke List'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Nutritional summary
          if (mealProv.meals.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ModernAppTheme.white,
                    ModernAppTheme.softGreen.withValues(alpha: 0.65),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
                border: Border.all(color: AppTheme.divider),
                boxShadow: ModernAppTheme.shadowSm,
              ),
              child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Always show logged stats if any meals are logged
                if (mealProv.loggedCount > 0) ...[
                  _summStat('${mealProv.totalCalories}', 'kcal eaten',
                      AppTheme.primaryGreen),
                  _divLine(),
                  _summStat('₱${mealProv.totalSpent.toStringAsFixed(0)}',
                      'spent', AppTheme.orangeAccent),
                  _divLine(),
                  _summStat('${mealProv.loggedCount}', 'logged',
                      AppTheme.lightGreen),
                ],
                // Show planned stats if any planned meals exist
                if (mealProv.plannedCount > 0) ...[
                  if (mealProv.loggedCount > 0) _divLine(),
                  _summStat('${mealProv.plannedCalories}', 'kcal planned',
                      AppTheme.primaryGreen),
                  _divLine(),
                  _summStat('${mealProv.plannedCount}', 'planned',
                      AppTheme.lightGreen),
                ],
                // Fallback when everything is logged (no planned)
                if (mealProv.plannedCount == 0 && mealProv.loggedCount == 0)
                  _summStat('0', 'meals', AppTheme.textLight),
              ],
            ),
            ),

          // Meals list
          Expanded(
            child: _buildMealsBody(mealProv, orderedMeals),
          ),
        ],
      ),
    );
  }

  // Return all meals sorted breakfast→lunch→dinner→snack.
  // Within each slot, logged meals are shown first, then planned.
  // We do NOT collapse to one per slot so that mixed days show all meals.
  List<MealModel> _orderedMeals(List<MealModel> all) {
    final typeOrder = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];
    final result = <MealModel>[];
    for (final type in typeOrder) {
      final matches = all.where((m) => m.type == type).toList()
        ..sort(_mealPriority);
      result.addAll(matches);
    }
    return result;
  }

  int _mealPriority(MealModel a, MealModel b) {
    if (a.status != b.status) {
      return a.status == MealStatus.logged ? -1 : 1;
    }
    final aTime = a.loggedAt ?? a.date;
    final bTime = b.loggedAt ?? b.date;
    return bTime.compareTo(aTime);
  }

  NutribotContext _buildNutribotContext(MealProvider mealProvider) {
    final user = context.read<AuthProvider>().userModel;
    final orderedMeals = _orderedMeals(mealProvider.meals);

    return NutribotContext(
      source: NutribotSource.mealLog,
      contextTitle: 'Meal Log',
      sourceContext:
          'Meal Log for ${DateFormat('MMM d, yyyy').format(mealProvider.selectedDate)}',
      initialPrompt:
          'Analyze my current meal log and suggest one improvement for today.',
      userGoal: user?.goal,
      attachedMeal: orderedMeals.isEmpty
          ? null
          : NutribotPayloads.meal(orderedMeals.first),
      data: NutribotPayloads.mealLogSummary(
        selectedDate: mealProvider.selectedDate,
        meals: mealProvider.meals,
      ),
    );
  }

  Widget _summStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textMid,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _divLine() => Container(width: 1, height: 28, color: AppTheme.divider);

  Widget _buildMealsBody(MealProvider mealProv, List<MealModel> orderedMeals) {
    // Loading = provider is loading AND we have no cached meals.
    if (mealProv.loading && mealProv.meals.isEmpty) {
      return const LoadingStateView(message: 'Loading your meal log...');
    }
    // On-screen error with retry — snackbar still fires for transient errors
    // but this gives a stable recovery path when the stream fails outright.
    if (mealProv.error != null && mealProv.meals.isEmpty) {
      return ErrorStateView(
        message: mealProv.error,
        onRetry: () {
          final uid = context.read<AuthProvider>().userModel?.uid ?? '';
          if (uid.isEmpty) return;
          mealProv.clearError();
          mealProv.listenToMeals(uid);
        },
      );
    }
    if (orderedMeals.isEmpty) {
      return _buildEmptyState();
    }

    // Status pill: show planned/logged split when both exist on this day.
    final plannedCount = mealProv.plannedCount;
    final loggedCount = mealProv.loggedCount;
    final showStatusPill = plannedCount > 0 && loggedCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showStatusPill)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.softGreen,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppTheme.accentGreen.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '$plannedCount planned · $loggedCount logged',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: orderedMeals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _buildMealCard(orderedMeals[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateView(
      icon: Icons.restaurant_menu_outlined,
      title: 'No meals for this day',
      message: 'Open AI Planner to create and save a plan.',
      actionLabel: 'Open AI Planner',
      onAction: _openAiMealPlanner,
    );
  }

  Widget _buildMealCard(MealModel meal) {
    final isLogged = meal.status == MealStatus.logged;
    final isExpanded = _expandedIds.contains(meal.id);

    return Dismissible(
      key: Key(meal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        await _deleteMeal(meal.id);
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLogged ? AppTheme.accentGreen : AppTheme.divider,
          ),
          boxShadow: ModernAppTheme.shadowSm,
        ),
        child: Column(
          children: [
            // Header row
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedIds.remove(meal.id);
                  } else {
                    _expandedIds.add(meal.id);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        SafeFoodImage(
                                imageUrl: meal.imageUrl,
                                mealName: meal.name,
                                width: 64,
                                height: 64,
                                borderRadius: BorderRadius.circular(12),
                              ),
                        if (isLogged)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.check,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _chip(meal.typeLabel, AppTheme.softGreen,
                                  AppTheme.primaryGreen),
                              const SizedBox(width: 6),
                              if (isLogged)
                                _chip('Logged ✓', AppTheme.softGreen,
                                    AppTheme.primaryGreen)
                              else
                                _chip(
                                  '📋 Planned',
                                  AppTheme.warning.withValues(alpha: 0.18),
                                  AppTheme.warning,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            meal.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: isLogged
                                    ? AppTheme.textMid
                                    : AppTheme.textDark,
                                decoration: isLogged
                                    ? TextDecoration.lineThrough
                                    : null),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('₱${meal.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppTheme.primaryGreen)),
                              const SizedBox(width: 8),
                              _dot(),
                              const SizedBox(width: 8),
                              Text('${meal.calories} kcal',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.textMid)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        if (!isLogged)
                          _mealActionButton(
                            label: 'Log',
                            icon: Icons.check_rounded,
                            filled: true,
                            onTap: () => _handleLogTap(meal),
                          ),
                        if (!isLogged) const SizedBox(height: 8),
                        _mealActionButton(
                          label: 'Swap',
                          icon: Icons.swap_horiz_rounded,
                          onTap: () => _openSwapSheet(meal),
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppTheme.textLight,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Expandable recipe section
            if (isExpanded)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.divider)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ingredients
                    if (meal.ingredients.isNotEmpty) ...[
                      const Text('Ingredients',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textDark)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: meal.ingredients
                            .map((ing) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.softGreen,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(ing,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.primaryGreen,
                                          fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (meal.notes != null &&
                        meal.notes!.trim().isNotEmpty) ...[
                      const Text('Notes',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textDark)),
                      const SizedBox(height: 6),
                      Text(meal.notes!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMid,
                              height: 1.4)),
                      const SizedBox(height: 14),
                    ],

                    // Macros row
                    if (meal.protein > 0 || meal.carbs > 0 || meal.fat > 0) ...[
                      Row(
                        children: [
                          _macroChip(
                              '${meal.protein}g', 'Protein', AppTheme.infoBlue),
                          const SizedBox(width: 8),
                          _macroChip(
                              '${meal.carbs}g', 'Carbs', AppTheme.orangeAccent),
                          const SizedBox(width: 8),
                          _macroChip('${meal.fat}g', 'Fat', AppTheme.errorRed),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Navigate to recipe screen
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GeneratedRecipeScreen(meal: meal),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: Text(
                          (meal.recipe != null && meal.recipe!.isNotEmpty)
                              ? 'View Recipe'
                              : 'Generate Recipe',
                        ),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _mealActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final foreground = filled ? Colors.white : AppTheme.primaryGreen;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? AppTheme.primaryGreen : AppTheme.softGreen,
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: AppTheme.accentGreen),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style:
              TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Widget _dot() => Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
          color: AppTheme.textLight, shape: BoxShape.circle));

}

enum _LogChoice { scan, manual }
