import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/community_provider.dart';
import 'home_screen.dart';
import 'meal_plan_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'chatbot_screen.dart';
import 'food_scanner_screen.dart';

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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 88,
        decoration: BoxDecoration(
          color: AppTheme.white,
          border: const Border(
            top: BorderSide(color: AppTheme.divider, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.textDark.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
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
      floatingActionButton: _buildChatbotFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildNavItem(int index) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? _screenActiveIcons[index] : _screenIcons[index],
                color: isActive ? AppTheme.primaryGreen : AppTheme.textLight,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                _screenTitles[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppTheme.primaryGreen : AppTheme.textLight,
                  letterSpacing: 0.2,
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
          MaterialPageRoute(builder: (_) => const FoodScannerScreen()),
        ),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Scan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatbotFAB() {
    return FloatingActionButton(
      heroTag: 'nutribot_fab',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChatbotScreen()),
      ),
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: Colors.white,
      shape: const CircleBorder(),
      elevation: 6,
      tooltip: 'Ask NutriBot',
      child: const Icon(Icons.smart_toy_outlined, size: 26),
    );
  }
}
