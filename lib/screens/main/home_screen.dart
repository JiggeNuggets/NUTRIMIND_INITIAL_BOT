import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../models/meal_model.dart';
import 'ai_meal_planner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final mealProv = context.watch<MealProvider>();
    final meals = mealProv.meals;
    final budget = user?.dailyBudget ?? 150;
    final spent = mealProv.totalSpent;
    final budgetPct = (spent / budget).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.bgGreen,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.bgGreen,
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
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
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
                  Stack(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_outlined,
                            color: AppTheme.textDark, size: 18),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppTheme.orangeAccent,
                              shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
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

                // Today's meals
                _buildTodaysMeals(context, meals, user?.uid ?? ''),
                const SizedBox(height: 20),

                // AI Plan card
                _buildAIPlanCard(context),
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
          colors: [AppTheme.darkGreen, AppTheme.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
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

  Widget _buildTodaysMeals(
      BuildContext context, List<MealModel> meals, String uid) {
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
        todayMeals.isEmpty
            ? _buildEmptyMeals()
            : Container(
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
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
              onTap: () => context.read<MealProvider>().logMeal(uid, meal.id),
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

  Widget _buildAIPlanCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
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
              'Optimized for ₱150/day local budget'),
          const SizedBox(height: 6),
          _feat(Icons.eco_outlined, 'Uses only fresh local Davao ingredients'),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () {
              final uid = context.read<AuthProvider>().userModel?.uid ?? '';
              context.read<MealProvider>().generateWeekPlan(uid);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Generating your weekly meal plan...'),
                backgroundColor: AppTheme.primaryGreen,
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('Generate Weekly Plan'),
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
    final foods = [
      {'name': 'Pomelo', 'tag': 'Citrus', 'price': '₱40/kg', 'emoji': '🍊'},
      {'name': 'Durian', 'tag': 'Fruit', 'price': '₱120/kg', 'emoji': '🌵'},
      {
        'name': 'Malunggay',
        'tag': 'Vegetable',
        'price': '₱20/bundle',
        'emoji': '🌿'
      },
      {'name': 'Bangus', 'tag': 'Fish', 'price': '₱110/kg', 'emoji': '🐟'},
      {
        'name': 'Saba Banana',
        'tag': 'Fruit',
        'price': '₱30/bundle',
        'emoji': '🍌'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Favorite Local Foods',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark)),
            TextButton(
              onPressed: () {},
              child: const Text('View All',
                  style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: foods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final food = foods[i];
              return Container(
                width: 115,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food['emoji']!, style: const TextStyle(fontSize: 28)),
                    const Spacer(),
                    Text(food['name']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textDark)),
                    Text(food['tag']!,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textMid)),
                    const SizedBox(height: 2),
                    Text(food['price']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppTheme.primaryGreen)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
