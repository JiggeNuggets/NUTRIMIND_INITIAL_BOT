import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../providers/auth_provider.dart';
import 'biometrics_screen.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  String? _selectedGoal;

  final List<Map<String, dynamic>> _goals = [
    {
      'id': 'nutrition',
      'icon': Icons.monitor_heart_outlined,
      'title': 'Nutrition Recovery',
      'subtitle': 'Improve nutritional deficiencies',
      'color': AppTheme.softGreen,
      'iconColor': AppTheme.primaryGreen,
    },
    {
      'id': 'weight',
      'icon': Icons.fitness_center_outlined,
      'title': 'Weight Management',
      'subtitle': 'Reach your ideal weight goal',
      'color': const Color(0xFFFFF4E6),
      'iconColor': AppTheme.orangeAccent,
    },
    {
      'id': 'health',
      'icon': Icons.favorite_border,
      'title': 'Health Improvement',
      'subtitle': 'Boost energy and immunity',
      'color': const Color(0xFFF0F4FF),
      'iconColor': const Color(0xFF4A6CF7),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernAppTheme.backgroundNeutral,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.backgroundNeutral,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.eco, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('NutriMind'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar
            Row(
              children: List.generate(
                  4,
                  (i) => Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: i == 0
                                ? AppTheme.primaryGreen
                                : AppTheme.divider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )),
            ),
            const SizedBox(height: 6),
            const Text('Step 1 of 3',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),

            const Text('What is your goal?',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                    letterSpacing: -0.5)),
            const SizedBox(height: 6),
            const Text('This helps us personalize your nutrition plan.',
                style: TextStyle(color: AppTheme.textMid, fontSize: 14)),
            const SizedBox(height: 32),

            ...(_goals.map((goal) => _buildGoalCard(goal))),
            const Spacer(),

            ElevatedButton(
              onPressed: _selectedGoal != null
                  ? () async {
                      await context
                          .read<AuthProvider>()
                          .updateGoal(_selectedGoal!);
                      if (!context.mounted) return;
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  BiometricsScreen(goal: _selectedGoal!)));
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                disabledBackgroundColor: AppTheme.divider,
                disabledForegroundColor: AppTheme.textLight,
              ),
              child: const Text('Next →'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final isSelected = _selectedGoal == goal['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = goal['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.softGreen : AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: goal['color'] as Color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(goal['icon'] as IconData,
                  color: goal['iconColor'] as Color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal['title'] as String,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark)),
                  const SizedBox(height: 2),
                  Text(goal['subtitle'] as String,
                      style: const TextStyle(
                          color: AppTheme.textMid, fontSize: 13)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              child: isSelected
                  ? const Icon(Icons.check_circle,
                      color: AppTheme.primaryGreen, size: 22)
                  : const Icon(Icons.radio_button_unchecked,
                      color: AppTheme.textLight, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
