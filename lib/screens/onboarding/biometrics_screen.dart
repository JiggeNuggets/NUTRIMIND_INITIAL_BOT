import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../main/main_shell.dart';

class BiometricsScreen extends StatefulWidget {
  final String goal;
  const BiometricsScreen({super.key, required this.goal});

  @override
  State<BiometricsScreen> createState() => _BiometricsScreenState();
}

class _BiometricsScreenState extends State<BiometricsScreen> {
  double _height = 168;
  double _weight = 64;
  int _age = 28;
  String _gender = 'Male';

  double get _bmi => _weight / ((_height / 100) * (_height / 100));

  String get _bmiLabel {
    if (_bmi < 18.5) return 'Underweight';
    if (_bmi < 25) return 'Normal';
    if (_bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    await auth.updateOnboarding(
      goal: widget.goal,
      gender: _gender,
      height: _height,
      weight: _weight,
      age: _age,
    );
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.eco, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('NutriMind'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(4, (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i < 2 ? AppTheme.primaryGreen : AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 6),
            const Text('Step 2 of 3', style: TextStyle(
                fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),

            const Text('Your Biometrics', style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800,
                color: AppTheme.textDark, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            const Text('Personalizes your daily plan, ingredients, and calorie targets.',
                style: TextStyle(color: AppTheme.textMid, fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),

            // BMI card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.lightGreen],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BMI Score', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(_bmi.toStringAsFixed(1), style: const TextStyle(
                          color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_bmiLabel, style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      _statChip('${_height.toInt()}cm', 'Height'),
                      const SizedBox(height: 8),
                      _statChip('${_weight.toStringAsFixed(1)}kg', 'Weight'),
                      const SizedBox(height: 8),
                      _statChip('$_age yrs', 'Age'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Gender
            _sectionLabel('Gender'),
            const SizedBox(height: 10),
            Row(
              children: ['Male', 'Female', 'Other'].map((g) {
                final sel = _gender == g;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _gender = g),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primaryGreen : AppTheme.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? AppTheme.primaryGreen : AppTheme.divider),
                      ),
                      child: Text(g, textAlign: TextAlign.center, style: TextStyle(
                          color: sel ? Colors.white : AppTheme.textDark,
                          fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            _buildSlider('Height', _height, 140, 210, 'cm',
                (v) => setState(() => _height = v)),
            const SizedBox(height: 20),
            _buildSlider('Weight', _weight, 30, 150, 'kg',
                (v) => setState(() => _weight = v)),
            const SizedBox(height: 20),
            _buildSlider('Age', _age.toDouble(), 10, 80, 'yrs',
                (v) => setState(() => _age = v.toInt())),

            const SizedBox(height: 36),

            ElevatedButton(
              onPressed: auth.loading ? null : _save,
              child: auth.loading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Get Started →'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label, style: const TextStyle(
      fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textDark));

  Widget _buildSlider(String label, double value, double min, double max,
      String unit, ValueChanged<double> onChanged) {
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
                color: AppTheme.softGreen, borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)} $unit',
                style: const TextStyle(color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
            value: value, min: min, max: max,
            divisions: ((max - min) * 2).toInt(),
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${min.toInt()} $unit',
                style: const TextStyle(color: AppTheme.textLight, fontSize: 10)),
            Text('${max.toInt()} $unit',
                style: const TextStyle(color: AppTheme.textLight, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
