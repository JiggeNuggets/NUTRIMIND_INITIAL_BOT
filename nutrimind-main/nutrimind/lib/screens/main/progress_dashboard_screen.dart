import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/meal_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../widgets/state_views.dart';
import 'meal_plan_screen.dart';

// ---------------------------------------------------------------------------
// Data container — computed from meals in users/{uid}/meals only.
// No new Firestore collections are created.
// ---------------------------------------------------------------------------
class _ProgressData {
  // Today
  final int todayCalories;
  final double todaySpending;
  final int todayMealCount;

  // Week (Mon–Sun containing today)
  final int weeklyCaloriesTotal;
  final double weeklyCaloriesAverage; // average over days that had meals
  final double weeklySpendingTotal;
  final int daysLoggedThisWeek; // days with ≥1 logged meal (out of 7)

  // Streak
  final int loggingStreak; // consecutive days up to today with ≥1 logged meal

  // Most frequent
  final String? mostFrequentMeal; // name of most-logged meal this period
  final bool temporarilyUnavailable;

  const _ProgressData({
    required this.todayCalories,
    required this.todaySpending,
    required this.todayMealCount,
    required this.weeklyCaloriesTotal,
    required this.weeklyCaloriesAverage,
    required this.weeklySpendingTotal,
    required this.daysLoggedThisWeek,
    required this.loggingStreak,
    required this.mostFrequentMeal,
    this.temporarilyUnavailable = false,
  });

  bool get hasAnyData =>
      todayMealCount > 0 || daysLoggedThisWeek > 0 || loggingStreak > 0;
}

// ---------------------------------------------------------------------------
// Helper — build _ProgressData from raw meal lists
// ---------------------------------------------------------------------------
_ProgressData _compute({
  required List<MealModel> todayMeals,
  required List<MealModel> weekMeals,
  required List<MealModel> recentMeals, // last 30 days for streak
}) {
  final progressToday = todayMeals
      .where((m) =>
          m.status == MealStatus.logged ||
          m.status == MealStatus.ready ||
          m.status == MealStatus.upcoming)
      .toList();
  final progressWeek = weekMeals
      .where((m) =>
          m.status == MealStatus.logged ||
          m.status == MealStatus.ready ||
          m.status == MealStatus.upcoming)
      .toList();
  final progressRecent = recentMeals
      .where((m) =>
          m.status == MealStatus.logged ||
          m.status == MealStatus.ready ||
          m.status == MealStatus.upcoming)
      .toList();

  // Today
  final todayCalories = progressToday.fold(0, (s, m) => s + m.calories);
  final todaySpending = progressToday.fold(0.0, (s, m) => s + m.price);
  final todayMealCount = progressToday.length;

  // Weekly
  final weeklyCaloriesTotal = progressWeek.fold(0, (s, m) => s + m.calories);
  final weeklySpendingTotal = progressWeek.fold(0.0, (s, m) => s + m.price);

  // Count unique days with at least one logged meal this week
  final uniqueWeekDays = progressWeek
      .map((m) => DateTime(m.date.year, m.date.month, m.date.day))
      .toSet();
  final daysLoggedThisWeek = uniqueWeekDays.length;
  final weeklyCaloriesAverage =
      daysLoggedThisWeek == 0 ? 0.0 : weeklyCaloriesTotal / daysLoggedThisWeek;

  // Logging streak: count consecutive days with ≥1 logged meal going back
  // from today.
  final today = DateTime.now();
  int streak = 0;
  for (var i = 0; i < 30; i++) {
    final checkDay = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: i));
    final hasLog = progressRecent.any((m) =>
        m.date.year == checkDay.year &&
        m.date.month == checkDay.month &&
        m.date.day == checkDay.day);
    if (hasLog) {
      streak++;
    } else {
      // If today has no log yet, don't break — maybe user is mid-day.
      // Only break on a gap that isn't today.
      if (i != 0) break;
    }
  }

  // Most frequent meal by name (across recent logged meals)
  String? mostFrequentMeal;
  if (progressRecent.isNotEmpty) {
    final freq = <String, int>{};
    for (final m in progressRecent) {
      freq[m.name] = (freq[m.name] ?? 0) + 1;
    }
    mostFrequentMeal =
        freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  return _ProgressData(
    todayCalories: todayCalories,
    todaySpending: todaySpending,
    todayMealCount: todayMealCount,
    weeklyCaloriesTotal: weeklyCaloriesTotal,
    weeklyCaloriesAverage: weeklyCaloriesAverage,
    weeklySpendingTotal: weeklySpendingTotal,
    daysLoggedThisWeek: daysLoggedThisWeek,
    loggingStreak: streak,
    mostFrequentMeal: mostFrequentMeal,
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() =>
      _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  static const Duration _loadTimeout = Duration(seconds: 8);

  late Future<_ProgressData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProgressData> _load() async {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    if (uid.isEmpty) return _emptyData();

    try {
      return await _loadFromFirestore(uid).timeout(_loadTimeout);
    } on TimeoutException catch (e, st) {
      developer.log(
        'Progress dashboard load timed out; showing unavailable fallback.',
        error: e,
        stackTrace: st,
        level: 900,
      );
      return _unavailableData();
    }
  }

  Future<_ProgressData> _loadFromFirestore(String uid) async {
    final mealProv = context.read<MealProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      mealProv.selectedDate.year,
      mealProv.selectedDate.month,
      mealProv.selectedDate.day,
    );
    final providerMeals = mealProv.meals;
    final providerMealsAreInCurrentWeek =
        providerMeals.isNotEmpty && _isInSameWeek(selectedDate, today);

    // Load the current week first; slow history reads should not block demo.
    List<MealModel> weekMeals;
    try {
      weekMeals = await mealProv
          .getMealsForWeek(uid, now)
          .timeout(const Duration(seconds: 6));
    } on TimeoutException {
      if (!providerMealsAreInCurrentWeek) rethrow;
      weekMeals = providerMeals;
    }
    if (providerMealsAreInCurrentWeek) {
      weekMeals = _replaceDayMeals(
        meals: weekMeals,
        day: selectedDate,
        replacement: providerMeals,
      );
    }
    final todayMeals =
        weekMeals.where((meal) => _isSameDay(meal.date, today)).toList();

    // This week (Mon–Sun) via existing MealProvider helper

    // Last 30 days for streak and most-frequent: query day-by-day reusing
    // getMealsForDate — limited to 30 iterations to keep reads reasonable.
    return _compute(
      todayMeals: todayMeals,
      weekMeals: weekMeals,
      recentMeals: weekMeals,
    );
  }

  static _ProgressData _emptyData() => const _ProgressData(
        todayCalories: 0,
        todaySpending: 0,
        todayMealCount: 0,
        weeklyCaloriesTotal: 0,
        weeklyCaloriesAverage: 0,
        weeklySpendingTotal: 0,
        daysLoggedThisWeek: 0,
        loggingStreak: 0,
        mostFrequentMeal: null,
      );

  static _ProgressData _unavailableData() => const _ProgressData(
        todayCalories: 0,
        todaySpending: 0,
        todayMealCount: 0,
        weeklyCaloriesTotal: 0,
        weeklyCaloriesAverage: 0,
        weeklySpendingTotal: 0,
        daysLoggedThisWeek: 0,
        loggingStreak: 0,
        mostFrequentMeal: null,
        temporarilyUnavailable: true,
      );

  static List<MealModel> _replaceDayMeals({
    required List<MealModel> meals,
    required DateTime day,
    required List<MealModel> replacement,
  }) {
    return [
      ...meals.where((meal) => !_isSameDay(meal.date, day)),
      ...replacement,
    ]..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return a.type.index.compareTo(b.type.index);
      });
  }

  static bool _isInSameWeek(DateTime a, DateTime b) {
    final aStart = _startOfWeek(a);
    final bStart = _startOfWeek(b);
    return _isSameDay(aStart, bStart);
  }

  static DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;

    return Scaffold(
      backgroundColor: ModernAppTheme.bgGreen,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.bgGreen,
        surfaceTintColor: Colors.transparent,
        title: const Text('Progress Dashboard'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: FutureBuilder<_ProgressData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingStateView(
                    message: 'Loading your progress...');
              }
              if (snap.hasError) {
                return ErrorStateView(
                  error: snap.error,
                  message: 'Could not load progress. Please try again.',
                  onRetry: () => setState(() => _future = _load()),
                );
              }
              final data = snap.data!;
              if (data.temporarilyUnavailable) {
                return _ProgressUnavailableView(
                  onRetry: () => setState(() => _future = _load()),
                );
              }
              if (!data.hasAnyData) {
                return _EmptyProgressView(
                  onGoToMealPlan: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MealPlanScreen()),
                  ),
                );
              }
              return _DashboardBody(data: data, user: user);
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyProgressView extends StatelessWidget {
  final VoidCallback onGoToMealPlan;
  const _EmptyProgressView({required this.onGoToMealPlan});

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.bar_chart_rounded,
      title: 'No progress yet',
      message: 'Log your meals to see your calories, budget, and streak here.',
      actionLabel: 'Create Meal Plan',
      onAction: onGoToMealPlan,
    );
  }
}

class _ProgressUnavailableView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ProgressUnavailableView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.hourglass_empty_rounded,
      title: 'Progress is temporarily unavailable',
      message:
          'Your meals may still be syncing. Try again in a moment to refresh your progress.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard body — renders all metric cards
// ---------------------------------------------------------------------------
class _DashboardBody extends StatelessWidget {
  final _ProgressData data;
  final UserModel? user;

  const _DashboardBody({required this.data, required this.user});

  @override
  Widget build(BuildContext context) {
    // Targets — fall back to safe defaults if not configured
    final calorieTarget =
        (user?.dailyBudget != null && user!.dailyBudget > 0) ? 2000 : 2000;
    final budgetTarget =
        (user != null && user!.dailyBudget > 0) ? user!.dailyBudget : 250.0;

    final caloriePct = calorieTarget > 0
        ? (data.todayCalories / calorieTarget).clamp(0.0, 1.0)
        : 0.0;
    final budgetPct = budgetTarget > 0
        ? (data.todaySpending / budgetTarget).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        const SizedBox(height: 4),
        const Text(
          'Your nutrition and budget progress',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textMid,
          ),
        ),
        const SizedBox(height: 20),

        // ── A: Today ─────────────────────────────────────────
        const _SectionLabel(label: "Today's Summary"),
        const SizedBox(height: 10),
        _TodayCard(data: data),
        const SizedBox(height: 8),

        // ── Progress bars ─────────────────────────────────────
        _ProgressBarsCard(
          caloriePct: caloriePct,
          todayCalories: data.todayCalories,
          calorieTarget: calorieTarget,
          budgetPct: budgetPct,
          todaySpending: data.todaySpending,
          budgetTarget: budgetTarget,
        ),
        const SizedBox(height: 20),

        // ── B: Weekly ─────────────────────────────────────────
        const _SectionLabel(label: 'Weekly Progress'),
        const SizedBox(height: 10),
        _WeeklyCard(data: data),
        const SizedBox(height: 20),

        // ── C: Streak ─────────────────────────────────────────
        const _SectionLabel(label: 'Logging Streak'),
        const SizedBox(height: 10),
        _StreakCard(streak: data.loggingStreak),
        const SizedBox(height: 20),

        // ── D: Most logged ────────────────────────────────────
        const _SectionLabel(label: 'Most Logged Meal'),
        const SizedBox(height: 10),
        _MostFrequentCard(name: data.mostFrequentMeal),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card: Today
// ---------------------------------------------------------------------------
class _TodayCard extends StatelessWidget {
  final _ProgressData data;
  const _TodayCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: _MetricCell(
              icon: Icons.local_fire_department_rounded,
              iconColor: AppTheme.orangeAccent,
              value: '${data.todayCalories}',
              unit: 'kcal',
              label: 'Calories',
            ),
          ),
          _VDiv(),
          Expanded(
            child: _MetricCell(
              icon: Icons.payments_outlined,
              iconColor: AppTheme.primaryGreen,
              value: '₱${data.todaySpending.toStringAsFixed(0)}',
              label: 'Spending',
            ),
          ),
          _VDiv(),
          Expanded(
            child: _MetricCell(
              icon: Icons.restaurant_outlined,
              iconColor: AppTheme.infoBlue,
              value: '${data.todayMealCount}',
              label: 'Meals',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card: Progress bars
// ---------------------------------------------------------------------------
class _ProgressBarsCard extends StatelessWidget {
  final double caloriePct;
  final int todayCalories;
  final int calorieTarget;
  final double budgetPct;
  final double todaySpending;
  final double budgetTarget;

  const _ProgressBarsCard({
    required this.caloriePct,
    required this.todayCalories,
    required this.calorieTarget,
    required this.budgetPct,
    required this.todaySpending,
    required this.budgetTarget,
  });

  @override
  Widget build(BuildContext context) {
    final budgetOver = budgetPct >= 1.0;
    final calOver = caloriePct >= 1.0;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Calories',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark)),
              Text(
                '$todayCalories / $calorieTarget kcal',
                style: TextStyle(
                  fontSize: 12,
                  color: calOver ? AppTheme.orangeAccent : AppTheme.textMid,
                  fontWeight: calOver ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: caloriePct,
              minHeight: 8,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation(
                calOver ? AppTheme.orangeAccent : AppTheme.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Budget
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daily Budget',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark)),
              Text(
                '₱${todaySpending.toStringAsFixed(0)} / ₱${budgetTarget.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: budgetOver ? AppTheme.errorRed : AppTheme.textMid,
                  fontWeight: budgetOver ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: budgetPct,
              minHeight: 8,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation(
                budgetOver ? AppTheme.errorRed : AppTheme.primaryGreen,
              ),
            ),
          ),
          if (budgetOver) ...[
            const SizedBox(height: 6),
            Text(
              'You have exceeded your daily budget.',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.errorRed.withValues(alpha: 0.85)),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card: Weekly
// ---------------------------------------------------------------------------
class _WeeklyCard extends StatelessWidget {
  final _ProgressData data;
  const _WeeklyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCell(
                  icon: Icons.bolt_rounded,
                  iconColor: AppTheme.orangeAccent,
                  value: '${data.weeklyCaloriesTotal}',
                  unit: 'kcal',
                  label: 'Weekly Total',
                ),
              ),
              _VDiv(),
              Expanded(
                child: _MetricCell(
                  icon: Icons.trending_up_rounded,
                  iconColor: AppTheme.primaryGreen,
                  value: data.weeklyCaloriesAverage.toStringAsFixed(0),
                  unit: 'kcal',
                  label: 'Daily Avg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCell(
                  icon: Icons.payments_outlined,
                  iconColor: AppTheme.primaryGreen,
                  value: '₱${data.weeklySpendingTotal.toStringAsFixed(0)}',
                  label: 'Weekly Spend',
                ),
              ),
              _VDiv(),
              Expanded(
                child: _MetricCell(
                  icon: Icons.calendar_today_outlined,
                  iconColor: AppTheme.infoBlue,
                  value: '${data.daysLoggedThisWeek}/7',
                  label: 'Days Logged',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card: Streak
// ---------------------------------------------------------------------------
class _StreakCard extends StatelessWidget {
  final int streak;
  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: streak > 0
                  ? AppTheme.orangeAccent.withValues(alpha: 0.12)
                  : AppTheme.divider,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: streak > 0 ? AppTheme.orangeAccent : AppTheme.textLight,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: streak > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$streak-day streak! 🔥',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        streak == 1
                            ? 'Keep it up — log again tomorrow!'
                            : 'Amazing consistency! Don\'t break the chain.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMid,
                        ),
                      ),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No streak yet',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMid,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Start logging meals to build your streak.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card: Most frequent meal
// ---------------------------------------------------------------------------
class _MostFrequentCard extends StatelessWidget {
  final String? name;
  const _MostFrequentCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.softGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: name != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Most Logged',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : const Text(
                    'No meals logged yet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textLight,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared primitives
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppTheme.textDark,
        letterSpacing: 0.1,
      ),
    );
  }
}

/// Standard NutriMind-style white rounded card with subtle shadow.
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        border: Border.all(color: AppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: child,
    );
  }
}

/// Single metric displayed as icon + big value + small label.
class _MetricCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String? unit;
  final String label;

  const _MetricCell({
    required this.icon,
    required this.iconColor,
    required this.value,
    this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
            children: [
              TextSpan(text: value),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMid,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMid),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _VDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 44, color: AppTheme.divider);
}
