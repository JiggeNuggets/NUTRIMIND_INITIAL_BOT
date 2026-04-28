import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const List<Map<String, dynamic>> _goals = [
    {
      'id': 'nutrition',
      'icon': Icons.monitor_heart_outlined,
      'title': 'Nutrition Recovery',
      'subtitle': 'Improve nutritional deficiencies',
    },
    {
      'id': 'weight',
      'icon': Icons.fitness_center_outlined,
      'title': 'Weight Management',
      'subtitle': 'Reach your ideal weight goal',
    },
    {
      'id': 'health',
      'icon': Icons.favorite_border,
      'title': 'Health Improvement',
      'subtitle': 'Boost energy and immunity',
    },
  ];

  String _goal = 'nutrition';
  String _gender = 'Male';
  double _height = 168;
  double _weight = 64;
  int _age = 28;
  double _dailyBudget = 150;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      if (user.goal.trim().isNotEmpty) _goal = user.goal;
      final gender = user.gender.trim();
      if (gender.isNotEmpty) _gender = gender;
      if (user.height > 0) _height = user.height;
      if (user.weight > 0) _weight = user.weight;
      if (user.age > 0) _age = user.age;
      if (user.dailyBudget > 0) _dailyBudget = user.dailyBudget;
    }
  }

  double get _bmi => UserModel.computeBmi(heightCm: _height, weightKg: _weight);

  String get _bmiLabel {
    final bmi = _bmi;
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().updateProfileSetup(
            goal: _goal,
            gender: _gender,
            height: _height,
            weight: _weight,
            age: _age,
            dailyBudget: _dailyBudget,
          );
      if (!mounted) return;
      // AuthGate will react and route to MainShell.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save profile: $e'),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('NutriMind'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set up your profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'NutriMind needs your goal, biometrics, and daily budget to plan Davao-friendly meals.',
                style: TextStyle(
                  color: AppTheme.textMid,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _sectionLabel('Your goal'),
              const SizedBox(height: 10),
              ..._goals.map(_buildGoalCard),
              const SizedBox(height: 12),
              _bmiCard(),
              const SizedBox(height: 24),
              _sectionLabel('Gender'),
              const SizedBox(height: 10),
              Row(
                children: ['Male', 'Female', 'Other'].map((g) {
                  final sel = _gender == g;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _gender = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primaryGreen : AppTheme.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? AppTheme.primaryGreen
                                : AppTheme.divider,
                          ),
                        ),
                        child: Text(
                          g,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: sel ? Colors.white : AppTheme.textDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              _slider(
                label: 'Height',
                value: _height,
                min: 140,
                max: 210,
                unit: 'cm',
                divisions: 140,
                onChanged: (v) => setState(() => _height = v),
              ),
              const SizedBox(height: 18),
              _slider(
                label: 'Weight',
                value: _weight,
                min: 30,
                max: 150,
                unit: 'kg',
                divisions: 240,
                onChanged: (v) => setState(() => _weight = v),
              ),
              const SizedBox(height: 18),
              _slider(
                label: 'Age',
                value: _age.toDouble(),
                min: 10,
                max: 80,
                unit: 'yrs',
                divisions: 70,
                onChanged: (v) => setState(() => _age = v.round()),
              ),
              const SizedBox(height: 22),
              _sectionLabel('Daily food budget (PHP)'),
              const SizedBox(height: 10),
              _slider(
                label: 'Budget',
                value: _dailyBudget,
                min: 50,
                max: 1000,
                unit: 'PHP',
                divisions: 95,
                onChanged: (v) => setState(() => _dailyBudget = v.roundToDouble()),
              ),
              const Text(
                'You can change this any time from Profile.',
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save & Get Started →'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal) {
    final isSelected = _goal == goal['id'];
    return GestureDetector(
      onTap: () => setState(() => _goal = goal['id'] as String),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.softGreen : AppTheme.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                goal['icon'] as IconData,
                color: AppTheme.primaryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal['title'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goal['subtitle'] as String,
                    style: const TextStyle(
                      color: AppTheme.textMid,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.textLight,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bmiCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.lightGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BMI Score',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                _bmi.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _bmiLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              _statChip('${_height.round()} cm', 'Height'),
              const SizedBox(height: 6),
              _statChip(
                '${_weight % 1 == 0 ? _weight.toStringAsFixed(0) : _weight.toStringAsFixed(1)} kg',
                'Weight',
              ),
              const SizedBox(height: 6),
              _statChip('$_age yrs', 'Age'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      );

  Widget _sectionLabel(String label) => Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textDark,
        ),
      );

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel(label),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)} $unit',
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primaryGreen,
            inactiveTrackColor: AppTheme.divider,
            thumbColor: AppTheme.primaryGreen,
            overlayColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
