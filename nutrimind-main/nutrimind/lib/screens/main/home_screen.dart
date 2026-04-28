import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/meal_model.dart';
import '../../models/nutribot_models.dart';
import '../../models/user_model.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/nutribot/nutribot_launcher.dart';
import '../../widgets/safe_image.dart';
import '../../widgets/state_views.dart';
import 'ai_meal_planner_screen.dart';
import 'scan_options_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Mifflin-St Jeor BMR — used only for calorie ring display.
  static int _estimateBmr(UserModel? user) {
    if (user == null) return 0;
    double bmr = 10 * user.weight + 6.25 * user.height - 5 * user.age;
    bmr += user.gender.trim().toLowerCase().startsWith('m') ? 5 : -161;
    return bmr.round().clamp(1000, 5000);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final mealProv = context.watch<MealProvider>();
    final budget = user?.dailyBudget ?? 150;
    final spent = mealProv.totalSpent;
    final budgetPct = (spent / budget).clamp(0.0, 1.0);
    final cal = mealProv.totalCalories;
    final calorieGoal = _estimateBmr(user);
    final caloriePct =
        calorieGoal > 0 ? (cal / calorieGoal).clamp(0.0, 1.0) : 0.0;

    final loggedMeals =
        mealProv.meals.where((m) => m.status == MealStatus.logged).toList();
    final totalProtein = loggedMeals.fold(0, (acc, m) => acc + m.protein);
    final totalCarbs = loggedMeals.fold(0, (acc, m) => acc + m.carbs);
    final totalFat = loggedMeals.fold(0, (acc, m) => acc + m.fat);
    final hasMacros = totalProtein > 0 || totalCarbs > 0 || totalFat > 0;

    return Scaffold(
      backgroundColor: ModernAppTheme.backgroundNeutral,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: ModernAppTheme.backgroundNeutral,
                surfaceTintColor: Colors.transparent,
                pinned: false,
                floating: true,
                toolbarHeight: 64,
                flexibleSpace: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: ModernAppTheme.gradientPrimary,
                          borderRadius:
                              BorderRadius.circular(ModernAppTheme.radiusSm),
                          boxShadow: ModernAppTheme.shadowSm,
                        ),
                        child: const Icon(Icons.eco,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'NutriMind',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const Spacer(),
                      const NotificationBell(boxed: true),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Greeting ───────────────────────────────────────────
                    _buildGreeting(
                      user?.name.split(' ').first ?? 'there',
                      user?.photoUrl,
                    ),
                    const SizedBox(height: 16),

                    // ── Today's Plan Card ──────────────────────────────────
                    _buildTodaysPlanCard(
                      budget: budget,
                      spent: spent,
                      budgetPct: budgetPct,
                      cal: cal,
                      calorieGoal: calorieGoal,
                      caloriePct: caloriePct,
                      loggedCount: mealProv.loggedCount,
                      protein: hasMacros ? totalProtein : null,
                      carbs: hasMacros ? totalCarbs : null,
                      fat: hasMacros ? totalFat : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Quick Actions ──────────────────────────────────────
                    _buildQuickActions(context),
                    const SizedBox(height: 20),

                    // ── Today's Meals ──────────────────────────────────────
                    _buildTodaysMeals(context, mealProv, user?.uid ?? ''),
                    const SizedBox(height: 16),

                    // ── Bottom two-column cards ────────────────────────────
                    _buildBottomCards(context),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  // ── 1. Greeting ─────────────────────────────────────────────────────────────

  Widget _buildGreeting(String firstName, String? photoUrl) {
    final safePhotoUrl = photoUrl?.trim();
    final hasPhoto = safePhotoUrl != null && safePhotoUrl.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_greeting()}, $firstName! 👋',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                "Here's your nutrition summary for today.",
                style: TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Avatar — right side
        CircleAvatar(
          radius: 24,
          backgroundColor: ModernAppTheme.softGreen,
          backgroundImage: hasPhoto ? NetworkImage(safePhotoUrl) : null,
          child: !hasPhoto
              ? Text(
                  firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: ModernAppTheme.primaryGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  // ── 2. Today's Plan Card ─────────────────────────────────────────────────────

  Widget _buildTodaysPlanCard({
    required double budget,
    required double spent,
    required double budgetPct,
    required int cal,
    required int calorieGoal,
    required double caloriePct,
    required int loggedCount,
    int? protein,
    int? carbs,
    int? fat,
  }) {
    final remaining = (budget - spent).clamp(0, budget);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ModernAppTheme.darkGreen, ModernAppTheme.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: ModernAppTheme.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          const Row(children: [
            Icon(Icons.today_outlined, color: Colors.white70, size: 13),
            SizedBox(width: 6),
            Text(
              "TODAY'S PLAN",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Calorie ring + 3 stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular calorie ring
              _buildCalorieRing(cal, calorieGoal, caloriePct),
              const SizedBox(width: 16),

              // 3 stat columns
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _planStat(
                        '₱${spent.toStringAsFixed(0)}',
                        'of ₱${budget.toStringAsFixed(0)}',
                        'budget used',
                      ),
                    ),
                    _vDivider(),
                    Expanded(
                      child: _planStat(
                        '$loggedCount/4',
                        'meals',
                        'logged',
                      ),
                    ),
                    _vDivider(),
                    Expanded(
                      child: _planStat(
                        '₱${remaining.toStringAsFixed(0)}',
                        'remaining',
                        'budget',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Budget progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: budgetPct,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(
                budgetPct > 0.85 ? ModernAppTheme.warning : Colors.white,
              ),
              minHeight: 8,
            ),
          ),

          // Macros strip — only when real logged data has macros
          if (protein != null && carbs != null && fat != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _macroItem(
                        Icons.fitness_center, '${protein}g', 'Protein'),
                  ),
                  _vDivider(),
                  Expanded(
                    child: _macroItem(Icons.grain, '${carbs}g', 'Carbs'),
                  ),
                  _vDivider(),
                  Expanded(
                    child: _macroItem(Icons.water_drop, '${fat}g', 'Fat'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalorieRing(int cal, int calorieGoal, double caloriePct) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: caloriePct,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 7,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$cal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const Text(
                'kcal',
                style: TextStyle(color: Colors.white70, fontSize: 9),
              ),
              if (calorieGoal > 0)
                Text(
                  'of $calorieGoal',
                  style: const TextStyle(color: Colors.white70, fontSize: 8),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _planStat(String value, String line2, String line3) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          line2,
          style: const TextStyle(color: Colors.white70, fontSize: 9),
          textAlign: TextAlign.center,
        ),
        Text(
          line3,
          style: const TextStyle(color: Colors.white70, fontSize: 9),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.25),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _macroItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 9),
        ),
      ],
    );
  }

  // ── 3. Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (
        icon: Icons.document_scanner_outlined,
        label: 'Scan Food',
        sub: 'Camera or gallery',
        iconColor: ModernAppTheme.primaryGreen,
        bgColor: ModernAppTheme.softGreen,
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const ScanOptionsScreen()),
            ),
      ),
      (
        icon: Icons.auto_awesome,
        label: 'AI Meal Plan',
        sub: 'Personalized for you',
        iconColor: const Color(0xFF7B52AB),
        bgColor: const Color(0xFFF3E5F5),
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const AiMealPlannerScreen()),
            ),
      ),
      (
        icon: Icons.smart_toy_outlined,
        label: 'NutriBot',
        sub: 'AI guidance & tips',
        iconColor: ModernAppTheme.info,
        bgColor: const Color(0xFFE3F2FD),
        onTap: () {
          final user = context.read<AuthProvider>().userModel;
          final mp = context.read<MealProvider>();
          NutribotLauncher.open(
            context,
            nutribotContext: NutribotContext(
              source: NutribotSource.home,
              contextTitle: 'Home Assistant',
              sourceContext: 'Home dashboard quick help',
              initialPrompt:
                  'Review my dashboard and give me a practical nutrition focus for today.',
              userGoal: user?.goal,
              data: {
                if (user != null) 'dailyBudgetPhp': user.dailyBudget,
                'spentTodayPhp': mp.totalSpent,
                'loggedMeals': mp.loggedCount,
                'totalCalories': mp.totalCalories,
              },
            ),
          );
        },
      ),
    ];

    return Row(
      children: actions.asMap().entries.map((entry) {
        final i = entry.key;
        final a = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < actions.length - 1 ? 10 : 0),
            child: InkWell(
              onTap: a.onTap,
              borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ModernAppTheme.white,
                  borderRadius: BorderRadius.circular(ModernAppTheme.radiusLg),
                  border: Border.all(color: ModernAppTheme.divider),
                  boxShadow: ModernAppTheme.shadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: a.bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(a.icon, color: a.iconColor, size: 19),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ModernAppTheme.textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ModernAppTheme.textLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 4. Today's Meals ─────────────────────────────────────────────────────────

  Widget _buildTodaysMeals(
      BuildContext context, MealProvider mealProv, String uid) {
    final meals = mealProv.meals;
    final typeOrder = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];
    final todayMeals = <MealModel>[];
    for (final type in typeOrder) {
      final matches = meals.where((m) => m.type == type).toList();
      if (matches.isNotEmpty) {
        matches.sort(_mealPriority);
        todayMeals.add(matches.first);
      }
    }

    final showLoading = mealProv.loading && meals.isEmpty;
    final showError =
        mealProv.error != null && meals.isEmpty && !mealProv.loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Meals",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Text(
                'View all',
                style: TextStyle(
                    color: ModernAppTheme.primaryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              label: const Icon(
                Icons.chevron_right,
                color: ModernAppTheme.primaryGreen,
                size: 16,
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (showLoading)
          _stateBox(
              child:
                  const LoadingStateView(message: "Loading today's meals..."))
        else if (showError)
          _stateBox(
            child: ErrorStateView(
              compact: true,
              message: mealProv.error,
              onRetry: uid.isEmpty
                  ? null
                  : () => context.read<MealProvider>().listenToMeals(uid),
            ),
          )
        else
          todayMeals.isEmpty
              ? _buildEmptyMeals(context, uid)
              : Column(
                  children: todayMeals
                      .map((m) => _buildMealCard(context, m, uid))
                      .toList(),
                ),
      ],
    );
  }

  Widget _stateBox({required Widget child}) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: child,
    );
  }

  int _mealPriority(MealModel a, MealModel b) {
    if (a.status != b.status) {
      return a.status == MealStatus.logged ? -1 : 1;
    }
    final aTime = a.loggedAt ?? a.date;
    final bTime = b.loggedAt ?? b.date;
    return bTime.compareTo(aTime);
  }

  Widget _buildEmptyMeals(BuildContext context, String uid) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: ModernAppTheme.softGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant_outlined,
                color: ModernAppTheme.primaryGreen, size: 26),
          ),
          const SizedBox(height: 10),
          const Text(
            'No meals planned today',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan food or generate a plan to get started.',
            style: TextStyle(fontSize: 12, color: AppTheme.textMid),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ScanOptionsScreen()),
              ),
              icon: const Icon(Icons.document_scanner_outlined, size: 16),
              label: const Text('Scan Food'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Meal type visual identity
  static const Map<MealType, IconData> _mealIcons = {
    MealType.breakfast: Icons.wb_sunny_outlined,
    MealType.lunch: Icons.lunch_dining,
    MealType.dinner: Icons.dinner_dining,
    MealType.snack: Icons.fastfood,
  };

  static const Map<MealType, Color> _mealColors = {
    MealType.breakfast: Color(0xFFFF9800),
    MealType.lunch: Color(0xFF4CAF50),
    MealType.dinner: Color(0xFF7B52AB),
    MealType.snack: Color(0xFF00ACC1),
  };

  static const Map<MealType, Color> _mealBgColors = {
    MealType.breakfast: Color(0xFFFFF3E0),
    MealType.lunch: Color(0xFFE8F5E9),
    MealType.dinner: Color(0xFFEDE7F6),
    MealType.snack: Color(0xFFE0F7FA),
  };

  Widget _buildMealCard(BuildContext context, MealModel meal, String uid) {
    final isLogged = meal.status == MealStatus.logged;
    final iconColor = _mealColors[meal.type] ?? ModernAppTheme.primaryGreen;
    final bgColor = _mealBgColors[meal.type] ?? ModernAppTheme.softGreen;
    final icon = _mealIcons[meal.type] ?? Icons.restaurant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: ModernAppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ModernAppTheme.divider, width: 0.8),
          boxShadow: ModernAppTheme.shadowSm,
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left colored accent bar
              Container(width: 4, color: iconColor),

              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SafeFoodImage(
                        imageUrl: meal.imageUrl,
                        mealName: meal.name,
                        width: 60,
                        height: 60,
                        borderRadius: BorderRadius.circular(10),
                        placeholderIcon: icon,
                        placeholderColor: iconColor,
                      ),
                      const SizedBox(width: 10),

                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Type chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 10, color: iconColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    meal.typeLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: iconColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              meal.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: isLogged
                                    ? AppTheme.textMid
                                    : AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${meal.calories} kcal  •  ₱${meal.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textMid),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Log action
                      isLogged
                          ? _loggedBadge()
                          : _logMealButton(context, meal, uid),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loggedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: ModernAppTheme.primaryGreen),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, color: ModernAppTheme.primaryGreen, size: 12),
          SizedBox(width: 3),
          Text(
            'Logged',
            style: TextStyle(
              color: ModernAppTheme.primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logMealButton(BuildContext context, MealModel meal, String uid) {
    return GestureDetector(
      onTap: () => _logMealFromHome(context, meal, uid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: ModernAppTheme.primaryGreen),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Log Meal',
          style: TextStyle(
            color: ModernAppTheme.primaryGreen,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── 5. Bottom two-column cards ───────────────────────────────────────────────

  Widget _buildBottomCards(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildLocalSpotlightCard()),
          const SizedBox(width: 12),
          Expanded(child: _buildNutriBotTipCard(context)),
        ],
      ),
    );
  }

  Widget _buildLocalSpotlightCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('local_foods')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        String title = 'Local Food Spotlight';
        String body =
            'Davao fruits are rich in vitamins and perfect for your daily health.';

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final food = _LocalFoodCard.fromDoc(snapshot.data!.docs.first);
          if (food.isVisible && food.name.isNotEmpty) {
            body =
                '${food.name} — ${food.tag}. ${food.priceLabel}. Great addition to your daily meals.';
          }
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ModernAppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ModernAppTheme.divider),
            boxShadow: ModernAppTheme.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: ModernAppTheme.softGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.eco,
                        color: ModernAppTheme.primaryGreen, size: 13),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMid,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Explore local foods →',
                    style: TextStyle(
                      color: ModernAppTheme.primaryGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: ModernAppTheme.softGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_florist,
                        color: ModernAppTheme.primaryGreen, size: 17),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNutriBotTipCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ModernAppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    color: ModernAppTheme.info, size: 13),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'NutriBot Tip',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: AppTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Eat a balanced meal with protein, fiber, and healthy fats to keep your energy steady all day!',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textMid,
              height: 1.5,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  final user = context.read<AuthProvider>().userModel;
                  final mp = context.read<MealProvider>();
                  NutribotLauncher.open(
                    context,
                    nutribotContext: NutribotContext(
                      source: NutribotSource.home,
                      contextTitle: 'NutriBot',
                      sourceContext: 'Home dashboard tip',
                      userGoal: user?.goal,
                      data: {
                        if (user != null) 'dailyBudgetPhp': user.dailyBudget,
                        'totalCalories': mp.totalCalories,
                      },
                    ),
                  );
                },
                child: const Text(
                  'Ask NutriBot →',
                  style: TextStyle(
                    color: ModernAppTheme.info,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_outlined,
                    color: ModernAppTheme.info, size: 17),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Log meal (original signature preserved) ──────────────────────────────────

  Future<void> _logMealFromHome(
    BuildContext context,
    MealModel meal,
    String uid,
  ) async {
    if (uid.isEmpty) return;
    final user = context.read<AuthProvider>().userModel;
    final mealProvider = context.read<MealProvider>();
    await mealProvider.logMeal(
      uid,
      meal.id,
      displayName: user?.name ?? '',
      photoUrl: user?.photoUrl,
      dailyBudget: user?.dailyBudget ?? 150,
    );
    if (!context.mounted) return;
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
  }
}

// ── Local food card model (Firestore-backed) ─────────────────────────────────

class _LocalFoodCard {
  const _LocalFoodCard({
    required this.name,
    required this.tag,
    required this.priceLabel,
    required this.isVisible,
    this.emoji,
  });

  final String name;
  final String tag;
  final String priceLabel;
  final bool isVisible;
  final String? emoji;

  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  factory _LocalFoodCard.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = _str(data, ['name', 'foodName', 'title']);
    return _LocalFoodCard(
      name: name.isEmpty ? doc.id : name,
      tag: _str(data, ['tag', 'category', 'marketCategory'],
          fallback: 'Local food'),
      priceLabel: _priceLabel(data),
      emoji: _optStr(data, ['emoji']),
      isVisible: data['isActive'] is bool ? data['isActive'] as bool : true,
    );
  }

  static String _priceLabel(Map<String, dynamic> data) {
    final label = _optStr(data, ['priceLabel', 'displayPrice']);
    if (label != null) return label;
    final price = _num(data, ['estimatedPricePhp', 'pricePhp', 'price']);
    if (price == null) return 'Price pending';
    final unit = _optStr(data, ['unit', 'priceUnit', 'servingSize']);
    final p =
        price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    return unit == null ? 'PHP $p' : 'PHP $p/$unit';
  }

  static String _str(Map<String, dynamic> d, List<String> keys,
          {String fallback = ''}) =>
      _optStr(d, keys) ?? fallback;

  static String? _optStr(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static double? _num(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is num) return v.toDouble();
      if (v is String) {
        final p = double.tryParse(v.trim());
        if (p != null) return p;
      }
    }
    return null;
  }
}
