import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../models/meal_model.dart';
import 'ai_meal_planner_screen.dart';
import 'generated_recipe_screen.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
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
    await context.read<MealProvider>().selectDate(uid, day);
  }

  Future<void> _logMeal(String mealId) async {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    await context.read<MealProvider>().logMeal(uid, mealId);
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
      await context.read<MealProvider>().deleteMeal(uid, mealId);
    }
  }

  Future<void> _generateWeekPlan() async {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    await context.read<MealProvider>().generateWeekPlan(uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('New weekly plan generated!'),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ));
    }
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
      backgroundColor: AppTheme.bgGreen,
      appBar: AppBar(
        backgroundColor: AppTheme.bgGreen,
        title: const Text('Meal Log'),
        actions: [
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
              onPressed: _generateWeekPlan,
              icon: const Icon(Icons.auto_awesome,
                  size: 14, color: AppTheme.primaryGreen),
              label: const Text('Generate',
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
            color: AppTheme.bgGreen,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                          color: isSel ? AppTheme.primaryGreen : AppTheme.white,
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
              ],
            ),
          ),

          // Nutritional summary
          if (mealProv.meals.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summStat('${mealProv.totalCalories}', 'kcal',
                      AppTheme.primaryGreen),
                  _divLine(),
                  _summStat('₱${mealProv.totalSpent.toStringAsFixed(0)}',
                      'spent', AppTheme.orangeAccent),
                  _divLine(),
                  _summStat('${mealProv.loggedCount}/${mealProv.meals.length}',
                      'logged', AppTheme.lightGreen),
                ],
              ),
            ),

          // Meals list
          Expanded(
            child: orderedMeals.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: orderedMeals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _buildMealCard(orderedMeals[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // Return at most 4 meals (one per type), sorted breakfast→lunch→dinner→snack
  List<MealModel> _orderedMeals(List<MealModel> all) {
    final typeOrder = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];
    final seen = <MealType>{};
    final result = <MealModel>[];
    for (final type in typeOrder) {
      final matches = all.where((m) => m.type == type).toList();
      if (matches.isNotEmpty) {
        matches.sort(_mealPriority);
        result.add(matches.first);
        seen.add(type);
      }
    }
    // Any remaining types not yet added (edge case)
    for (final m in all) {
      if (!seen.contains(m.type) && result.length < 4) {
        result.add(m);
        seen.add(m.type);
      }
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined,
              color: AppTheme.textLight, size: 48),
          const SizedBox(height: 16),
          const Text('No meals for this day',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMid)),
          const SizedBox(height: 8),
          const Text('Tap Generate to create your plan',
              style: TextStyle(fontSize: 13, color: AppTheme.textLight)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generateWeekPlan,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Generate Plan'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)),
          ),
        ],
      ),
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
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: isLogged
                                ? AppTheme.softGreen
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(_mealEmoji(meal.type),
                                style: const TextStyle(fontSize: 28)),
                          ),
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
                              if (isLogged) ...[
                                const SizedBox(width: 6),
                                _chip('Logged ✓', AppTheme.softGreen,
                                    AppTheme.primaryGreen),
                              ],
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
                          GestureDetector(
                            onTap: () => _logMeal(meal.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Log',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ),
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

  String _mealEmoji(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return '🌅';
      case MealType.lunch:
        return '🍱';
      case MealType.dinner:
        return '🍽️';
      case MealType.snack:
        return '🍌';
    }
  }
}
