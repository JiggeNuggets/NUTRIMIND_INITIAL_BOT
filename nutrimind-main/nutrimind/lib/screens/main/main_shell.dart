import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/meal_model.dart';
import '../../models/nutribot_models.dart';
import '../../theme/modern_app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/nutribot/nutribot_launcher.dart';
import 'home_screen.dart';
import 'meal_plan_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'scan_options_screen.dart';
import 'create_post_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null) {
        context.read<MealProvider>().listenToMeals(uid);
        context.read<CommunityProvider>().listenToPosts('Trending');
        context.read<NotificationProvider>().setUser(uid);
      }
    });
  }

  // 4 persistent tabs plus a center Scan action.
  final List<Widget> _screens = const [
    HomeScreen(), // Home/Dashboard
    MealPlanScreen(), // Log (Meal Plan + Recipe/Steps)
    CommunityScreen(), // Community
    ProfileScreen(), // Profile (with BMI)
  ];

  final List<String> _screenTitles = [
    'Home',
    'Log',
    'Community',
    'Profile',
  ];

  final List<IconData> _screenIcons = [
    Icons.home_outlined,
    Icons.menu_book_outlined,
    Icons.people_outline,
    Icons.person_outline,
  ];

  final List<IconData> _screenActiveIcons = [
    Icons.home,
    Icons.menu_book,
    Icons.people,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    final nutribotContext = _currentNutribotContext(context);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SafeArea(
          top: false,
          child: Container(
            height: 74,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: ModernAppTheme.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: ModernAppTheme.mediumGray.withValues(alpha: 0.7),
              ),
              boxShadow: [
                BoxShadow(
                  color: ModernAppTheme.primaryGreen.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildNavItem(0),
                _buildNavItem(1),
                _buildScanNavItem(),
                _buildNavItem(2),
                _buildNavItem(3),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActions(nutribotContext),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildNavItem(int index) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? ModernAppTheme.softGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? _screenActiveIcons[index] : _screenIcons[index],
                color: isActive
                    ? ModernAppTheme.primaryGreen
                    : ModernAppTheme.textLight,
                size: 23,
              ),
              const SizedBox(height: 3),
              Text(
                _screenTitles[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive
                      ? ModernAppTheme.primaryGreen
                      : ModernAppTheme.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanNavItem() {
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScanOptionsScreen()),
        ),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 58,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: ModernAppTheme.gradientPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          ModernAppTheme.primaryGreen.withValues(alpha: 0.34),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActions(NutribotContext nutribotContext) {
    if (_currentIndex != 2) {
      return _buildChatbotFAB(nutribotContext: nutribotContext);
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildChatbotFAB(
            nutribotContext: nutribotContext,
            isSmall: true,
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'community_share_post_fab',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
            ),
            backgroundColor: ModernAppTheme.primaryGreen,
            foregroundColor: Colors.white,
            mini: true,
            shape: const CircleBorder(),
            tooltip: 'Create Post',
            child: const Icon(Icons.add, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildChatbotFAB({
    required NutribotContext nutribotContext,
    bool isSmall = false,
  }) {
    return NutribotFab(
      heroTag: 'nutribot_fab',
      mini: isSmall,
      nutribotContext: nutribotContext,
    );
  }

  NutribotContext _currentNutribotContext(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final mealProvider = context.watch<MealProvider>();

    switch (_currentIndex) {
      case 0:
        return NutribotContext(
          source: NutribotSource.home,
          contextTitle: 'Home Assistant',
          sourceContext: 'Home dashboard overview',
          userGoal: user?.goal,
          data: {
            if (user?.dailyBudget != null) 'dailyBudgetPhp': user!.dailyBudget,
            'spentTodayPhp': mealProvider.totalSpent,
            'loggedMeals': mealProvider.loggedCount,
            'totalCalories': mealProvider.totalCalories,
          },
        );
      case 1:
        return NutribotContext(
          source: NutribotSource.mealLog,
          contextTitle: 'Meal Log',
          sourceContext:
              'Meal Log for ${mealProvider.selectedDate.toIso8601String().split('T').first}',
          userGoal: user?.goal,
          attachedMeal: _featuredMealPayload(mealProvider.meals),
          data: NutribotPayloads.mealLogSummary(
            selectedDate: mealProvider.selectedDate,
            meals: mealProvider.meals,
          ),
        );
      case 2:
        return NutribotContext(
          source: NutribotSource.community,
          contextTitle: 'Community Helper',
          sourceContext: 'Community feed',
          userGoal: user?.goal,
          data: {
            if (user?.location != null) 'location': user!.location,
            if (user?.dailyBudget != null) 'dailyBudgetPhp': user!.dailyBudget,
          },
        );
      case 3:
        return NutribotContext(
          source: NutribotSource.profile,
          contextTitle: 'Profile Insights',
          sourceContext: 'Profile and wellness settings',
          userGoal: user?.goal,
          data: user != null ? NutribotPayloads.profile(user) : null,
        );
      default:
        return const NutribotContext(source: NutribotSource.general);
    }
  }

  Map<String, dynamic>? _featuredMealPayload(List<MealModel> meals) {
    if (meals.isEmpty) return null;

    final orderedMeals = [...meals]..sort((left, right) {
        if (left.status != right.status) {
          return left.status == MealStatus.logged ? -1 : 1;
        }
        final leftTime = left.loggedAt ?? left.date;
        final rightTime = right.loggedAt ?? right.date;
        return rightTime.compareTo(leftTime);
      });

    return NutribotPayloads.meal(orderedMeals.first);
  }
}
