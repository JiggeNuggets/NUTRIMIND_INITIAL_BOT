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
import '../../widgets/notification_bell.dart';
import '../../widgets/nutribot/nutribot_launcher.dart';
import '../../widgets/state_views.dart';
import 'ai_meal_planner_screen.dart';
import 'food_scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final mealProv = context.watch<MealProvider>();
    final budget = user?.dailyBudget ?? 150;
    final spent = mealProv.totalSpent;
    final budgetPct = (spent / budget).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: ModernAppTheme.backgroundNeutral,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: ModernAppTheme.backgroundNeutral,
            surfaceTintColor: Colors.transparent,
            pinned: false,
            floating: true,
            toolbarHeight: 70,
            flexibleSpace: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Row(children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: ModernAppTheme.gradientPrimary,
                        borderRadius:
                            BorderRadius.circular(ModernAppTheme.radiusSm),
                        boxShadow: ModernAppTheme.shadowSm,
                      ),
                      child:
                          const Icon(Icons.eco, color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 8),
                    const Text('NutriMind',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.textDark)),
                  ]),
                  const Spacer(),
                  const NotificationBell(boxed: true),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Greeting
                Text(
                  'Good ${_greeting()}, ${user?.name.split(' ').first ?? 'there'}! 👋',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                      letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                const Text("Here's your nutrition summary for today.",
                    style: TextStyle(color: AppTheme.textMid, fontSize: 13)),
                const SizedBox(height: 20),

                // Budget card
                _buildBudgetCard(
                    budget, spent, budgetPct, mealProv.totalCalories),
                const SizedBox(height: 20),

                _buildQuickActions(context),
                const SizedBox(height: 20),

                // Today's meals
                _buildTodaysMeals(context, mealProv, user?.uid ?? ''),
                const SizedBox(height: 20),

                // AI Plan card
                _buildAIPlanCard(context, budget),
                const SizedBox(height: 20),

                // Local foods
                _buildLocalFoods(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }

  Widget _buildBudgetCard(double budget, double spent, double pct, int cal) {
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
            color: ModernAppTheme.primaryGreen.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.restaurant_menu, color: Colors.white70, size: 14),
            SizedBox(width: 6),
            Text('DAILY FOOD BUDGET',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('₱${spent.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800)),
                  Text('of ₱${budget.toStringAsFixed(0)} budget',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text('$cal',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18)),
                        const Text('kcal',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(
                pct > 0.85 ? AppTheme.orangeAccent : Colors.white,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₱${spent.toStringAsFixed(0)} used',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              Text(
                  '₱${(budget - spent).clamp(0, budget).toStringAsFixed(0)} left',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (
        icon: Icons.document_scanner_outlined,
        title: 'Scan Food',
        subtitle: 'Camera or gallery',
        color: ModernAppTheme.primaryGreen,
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const FoodScannerScreen(),
              ),
            ),
      ),
      (
        icon: Icons.auto_awesome,
        title: 'Generate Plan',
        subtitle: 'BMR baskets',
        color: ModernAppTheme.pastelPurple,
        onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AiMealPlannerScreen(),
              ),
            ),
      ),
      (
        icon: Icons.smart_toy_outlined,
        title: 'Ask NutriBot',
        subtitle: 'AI guidance',
        color: ModernAppTheme.info,
        onTap: () {
          final user = context.read<AuthProvider>().userModel;
          final mealProvider = context.read<MealProvider>();
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
                'spentTodayPhp': mealProvider.totalSpent,
                'loggedMeals': mealProvider.loggedCount,
                'totalCalories': mealProvider.totalCalories,
              },
            ),
          );
        },
      ),
    ];

    return Row(
      children: actions
          .map(
            (action) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: action == actions.last ? 0 : 10,
                ),
                child: InkWell(
                  onTap: action.onTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ModernAppTheme.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ModernAppTheme.divider),
                      boxShadow: ModernAppTheme.shadowSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: action.color.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            action.icon,
                            color: action.color == ModernAppTheme.pastelPurple
                                ? ModernAppTheme.primaryGreen
                                : action.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          action.title,
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
                          action.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ModernAppTheme.textLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTodaysMeals(
      BuildContext context, MealProvider mealProv, String uid) {
    final meals = mealProv.meals;
    // Limit to 4 meals max (one per meal type: breakfast, lunch, dinner, snack)
    final typeOrder = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack
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
            const Text("Today's Meals",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark)),
            Text('${todayMeals.length}/4 meals',
                style:
                    const TextStyle(color: AppTheme.textLight, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        if (showLoading)
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
              boxShadow: ModernAppTheme.shadowSm,
            ),
            child: const LoadingStateView(message: "Loading today's meals..."),
          )
        else if (showError)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.divider),
              boxShadow: ModernAppTheme.shadowSm,
            ),
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
              ? _buildEmptyMeals()
              : Container(
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                    boxShadow: ModernAppTheme.shadowSm,
                  ),
                  child: Column(
                    children: todayMeals.asMap().entries.map((entry) {
                      final meal = entry.value;
                      final isLast = entry.key == todayMeals.length - 1;
                      return Column(
                        children: [
                          _buildMealRow(context, meal, uid),
                          if (!isLast)
                            const Divider(
                                height: 1, indent: 68, color: AppTheme.divider),
                        ],
                      );
                    }).toList(),
                  ),
                ),
      ],
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

  Widget _buildEmptyMeals() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.restaurant_outlined,
                color: AppTheme.textLight, size: 36),
            SizedBox(height: 8),
            Text("No meals planned today",
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.textMid)),
            SizedBox(height: 4),
            Text("Tap + to add a meal",
                style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildMealRow(BuildContext context, MealModel meal, String uid) {
    final isLogged = meal.status == MealStatus.logged;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      isLogged ? AppTheme.softGreen : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.restaurant,
                    color:
                        isLogged ? AppTheme.primaryGreen : AppTheme.textLight,
                    size: 20),
              ),
              if (isLogged)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.check, color: Colors.white, size: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meal.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isLogged ? AppTheme.textMid : AppTheme.textDark,
                        decoration:
                            isLogged ? TextDecoration.lineThrough : null)),
                Text(meal.typeLabel,
                    style: const TextStyle(
                        color: AppTheme.textLight, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₱${meal.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.primaryGreen)),
              Text('${meal.calories} kcal',
                  style:
                      const TextStyle(fontSize: 11, color: AppTheme.textMid)),
            ],
          ),
          if (!isLogged) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _logMealFromHome(context, meal, uid),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Log',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAIPlanCard(BuildContext context, double dailyBudget) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: AppTheme.softGreen,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('AI PLAN',
                    style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome,
                  color: AppTheme.primaryGreen, size: 18),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Unlock Your\nDavao Journey',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                  height: 1.2)),
          const SizedBox(height: 8),
          const Text(
            'AI-generated strategy for the Davao lifestyle. Local ingredients, budget-smart, nutrition-optimized.',
            style:
                TextStyle(color: AppTheme.textMid, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          _feat(Icons.psychology_outlined,
              'Intelligent Optimizer — smart daily adjustments'),
          const SizedBox(height: 6),
          _feat(Icons.monetization_on_outlined,
              'Optimized for PHP ${dailyBudget.toStringAsFixed(0)}/day local budget'),
          const SizedBox(height: 6),
          _feat(Icons.eco_outlined, 'Uses only fresh local Davao ingredients'),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AiMealPlannerScreen(),
                ),
              );
            },
            child: const Text('Open AI Meal Planner'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AiMealPlannerScreen(),
                ),
              );
            },
            icon: const Icon(Icons.calculate_outlined, size: 18),
            label: const Text('AI calorie baskets (BMR + knapsack)'),
          ),
        ],
      ),
    );
  }

  Widget _feat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 15),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMid, height: 1.4))),
      ],
    );
  }

  Widget _buildLocalFoods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Local Foods',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('local_foods')
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _localFoodState(
                child: const LoadingStateView(
                  message: 'Loading local foods...',
                ),
              );
            }

            if (snapshot.hasError) {
              return _localFoodState(
                child: ErrorStateView(
                  compact: true,
                  error: snapshot.error,
                  message: 'Could not load local food data.',
                ),
              );
            }

            final foods = (snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                .map(_LocalFoodCard.fromDoc)
                .where((food) => food.isVisible)
                .toList(growable: false);

            if (foods.isEmpty) {
              return _localFoodState(
                child: const EmptyStateView(
                  compact: true,
                  icon: Icons.restaurant_menu_outlined,
                  title: 'No local foods yet',
                  message:
                      'Local food recommendations will appear once market data is available.',
                ),
              );
            }

            return SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: foods.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _buildLocalFoodCard(foods[i]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _localFoodState({required Widget child}) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: child,
    );
  }

  Widget _buildLocalFoodCard(_LocalFoodCard food) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _localFoodIcon(food),
          const Spacer(),
          Text(
            food.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.textDark,
            ),
          ),
          Text(
            food.tag,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMid),
          ),
          const SizedBox(height: 2),
          Text(
            food.priceLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _localFoodIcon(_LocalFoodCard food) {
    if (food.emoji != null) {
      return Text(food.emoji!, style: const TextStyle(fontSize: 28));
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppTheme.softGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          food.initial,
          style: const TextStyle(
            color: AppTheme.primaryGreen,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

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
    await context.read<NotificationProvider>().createBudgetWarningIfNeeded(
          uid: uid,
          meals: mealProvider.meals,
          dailyBudget: user?.dailyBudget ?? 150,
          date: mealProvider.selectedDate,
        );
  }
}

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
    final name = _stringValue(data, ['name', 'foodName', 'title']);
    final priceLabel = _priceLabel(data);
    return _LocalFoodCard(
      name: name.isEmpty ? doc.id : name,
      tag: _stringValue(data, ['tag', 'category', 'marketCategory'],
          fallback: 'Local food'),
      priceLabel: priceLabel,
      emoji: _optionalStringValue(data, ['emoji']),
      isVisible: data['isActive'] is bool ? data['isActive'] as bool : true,
    );
  }

  static String _priceLabel(Map<String, dynamic> data) {
    final label = _optionalStringValue(data, ['priceLabel', 'displayPrice']);
    if (label != null) return label;

    final price = _numValue(data, ['estimatedPricePhp', 'pricePhp', 'price']);
    if (price == null) return 'Price pending';

    final unit = _optionalStringValue(
      data,
      ['unit', 'priceUnit', 'servingSize'],
    );
    final priceText =
        price % 1 == 0 ? price.toStringAsFixed(0) : price.toStringAsFixed(2);
    return unit == null ? 'PHP $priceText' : 'PHP $priceText/$unit';
  }

  static String _stringValue(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    return _optionalStringValue(data, keys) ?? fallback;
  }

  static String? _optionalStringValue(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static double? _numValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
