import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/meal_planner_food_data.dart';
import '../../models/meal_planner_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/groq_meal_narrative_service.dart';
import '../../services/meal_planner_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/meal_planner/meal_basket_card.dart';

/// AI Meal Planner — ported from Python/Streamlit (`streamlit_meal_planner.py`, `data.py`).
/// Uses BMR + knapsack (or random greedy) + optional Groq narratives (`prompts.py`).
class AiMealPlannerScreen extends StatefulWidget {
  const AiMealPlannerScreen({super.key});

  @override
  State<AiMealPlannerScreen> createState() => _AiMealPlannerScreenState();
}

class _AiMealPlannerScreenState extends State<AiMealPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ageCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _heightFtCtrl;
  late final TextEditingController _heightInCtrl;

  bool _useMetric = true;
  bool _isMale = true;
  final Set<String> _preferredBreakfast = {};
  final Set<String> _excludedGroups = {};
  MealPlannerAlgorithm _algorithm = MealPlannerAlgorithm.knapsack;

  DailyMealPlan? _plan;
  bool _building = false;

  String? _aiBreakfast;
  String? _aiLunch;
  String? _aiDinner;
  bool _generatingAi = false;

  // Image analysis state
  XFile? _selectedImageFile;
  String? _imageAnalysis;
  bool _analyzingImage = false;

  late final GroqMealNarrativeService _groq;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    _ageCtrl = TextEditingController(text: '${user?.age ?? 28}');
    _weightCtrl = TextEditingController(text: '${user?.weight ?? 64}');
    _heightCtrl = TextEditingController(text: '${user?.height ?? 168}');
    _heightFtCtrl = TextEditingController(text: '5');
    _heightInCtrl = TextEditingController(text: '10');
    _isMale = (user?.gender.toLowerCase() != 'female');
    _groq = GroqMealNarrativeService();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _heightFtCtrl.dispose();
    _heightInCtrl.dispose();
    _groq.dispose();
    super.dispose();
  }

  (double kg, double cm) _metricFromFields() {
    final age = int.tryParse(_ageCtrl.text) ?? 28;
    if (age < 1) throw const FormatException('Invalid age');

    if (_useMetric) {
      final w = double.tryParse(_weightCtrl.text) ?? 64;
      final h = double.tryParse(_heightCtrl.text) ?? 168;
      return (w, h);
    }

    final lb = double.tryParse(_weightCtrl.text) ?? 150;
    final ft = int.tryParse(_heightFtCtrl.text) ?? 5;
    final inch = int.tryParse(_heightInCtrl.text) ?? 10;
    return (
      MealPlannerService.lbToKg(lb),
      MealPlannerService.imperialHeightToCm(feet: ft, inches: inch),
    );
  }

  void _buildPlan() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _building = true;
      _plan = null;
      _aiBreakfast = _aiLunch = _aiDinner = null;
    });

    try {
      final (kg, cm) = _metricFromFields();
      final input = MealPlannerInput(
        weightKg: kg,
        heightCm: cm,
        age: int.tryParse(_ageCtrl.text) ?? 28,
        isMale: _isMale,
        preferredBreakfastGroups: _preferredBreakfast.toList(),
        excludedGroups: _excludedGroups.toList(),
        algorithm: _algorithm,
      );
      final plan = MealPlannerService().buildDailyPlan(input);
      setState(() => _plan = plan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _building = false);
    }
  }

  Future<void> _generateAiNarratives() async {
    final plan = _plan;
    if (plan == null) return;
    if (!_groq.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set GROQ_API_KEY: flutter run --dart-define=GROQ_API_KEY=your_key',
          ),
        ),
      );
      return;
    }

    final name = context.read<AuthProvider>().userModel?.name ?? 'there';

    setState(() {
      _generatingAi = true;
      _aiBreakfast = _aiLunch = _aiDinner = null;
    });

    try {
      String? b;
      String? l;
      String? d;
      if (plan.breakfast.items.isNotEmpty) {
        b = await _groq.generateForBasket(
          slot: PlannerMealSlot.breakfast,
          items: plan.breakfast.items,
          userName: name,
        );
      }
      if (plan.lunch.items.isNotEmpty) {
        l = await _groq.generateForBasket(
          slot: PlannerMealSlot.lunch,
          items: plan.lunch.items,
          userName: name,
        );
      }
      if (plan.dinner.items.isNotEmpty) {
        d = await _groq.generateForBasket(
          slot: PlannerMealSlot.dinner,
          items: plan.dinner.items,
          userName: name,
        );
      }
      if (mounted) {
        setState(() {
          _aiBreakfast = b;
          _aiLunch = l;
          _aiDinner = d;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingAi = false);
    }
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);

    if (pickedFile == null) return;

    setState(() {
      _selectedImageFile = pickedFile;
      _imageAnalysis = null;
      _analyzingImage = true;
    });

    try {
      final imageBytes = await pickedFile.readAsBytes();
      final analysis = await _groq.analyzeFoodImageBytes(imageBytes);
      if (mounted) {
        setState(() => _imageAnalysis = analysis);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Analysis failed: $e';
        if (e.toString().contains('API key is missing')) {
          errorMessage = 'Groq API key is missing. Run Flutter with --dart-define=GROQ_API_KEY=your_key';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Camera permission was denied. Please allow camera access or upload an image.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _analyzingImage = false);
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndAnalyzeImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndAnalyzeImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel;
    final breakfastKeys = MealPlannerFoodData.breakfastGroupKeys();
    final allKeys = MealPlannerFoodData.allGroupKeys();

    return Scaffold(
      backgroundColor: AppTheme.bgGreen,
      appBar: AppBar(
        backgroundColor: AppTheme.bgGreen,
        title: const Text('AI Meal Planner'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Hi ${user?.name.split(' ').first ?? 'there'} — optimize baskets from your BMR, then optionally generate meal blurbs via Groq (same prompts as the Python app).',
              style: const TextStyle(color: AppTheme.textMid, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Units'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Metric'), icon: Icon(Icons.straighten)),
                ButtonSegment(value: false, label: Text('Imperial'), icon: Icon(Icons.balance)),
              ],
              selected: {_useMetric},
              onSelectionChanged: (s) => setState(() => _useMetric = s.first),
            ),
            const SizedBox(height: 16),
            _sectionTitle('Profile'),
            TextFormField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
              validator: (v) =>
                  (v == null || int.tryParse(v) == null) ? 'Enter age' : null,
            ),
            const SizedBox(height: 10),
            if (_useMetric) ...[
              TextFormField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                validator: (v) =>
                    (v == null || double.tryParse(v) == null) ? 'Enter weight' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _heightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Height (cm)'),
                validator: (v) =>
                    (v == null || double.tryParse(v) == null) ? 'Enter height' : null,
              ),
            ] else ...[
              TextFormField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Weight (lb)'),
                validator: (v) =>
                    (v == null || double.tryParse(v) == null) ? 'Enter weight' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightFtCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Height (ft)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heightInCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Height (in)'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _sectionTitle('Gender'),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Male')),
                ButtonSegment(value: false, label: Text('Female')),
              ],
              selected: {_isMale},
              onSelectionChanged: (s) => setState(() => _isMale = s.first),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Breakfast group preferences (optional)'),
            const Text(
              'If you pick none, all breakfast groups are used. Matches Streamlit multiselect on breakfast categories.',
              style: TextStyle(fontSize: 11, color: AppTheme.textLight, height: 1.35),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: breakfastKeys.map((k) {
                final selected = _preferredBreakfast.contains(k);
                return FilterChip(
                  label: Text(k.replaceAll('_', ' ')),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _preferredBreakfast.add(k);
                    } else {
                      _preferredBreakfast.remove(k);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Exclude groups (allergies / avoid)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allKeys.map((k) {
                final selected = _excludedGroups.contains(k);
                return FilterChip(
                  label: Text(k.replaceAll('_', ' ')),
                  selected: selected,
                  selectedColor: AppTheme.errorRed.withValues(alpha: 0.15),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _excludedGroups.add(k);
                    } else {
                      _excludedGroups.remove(k);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Algorithm'),
            SegmentedButton<MealPlannerAlgorithm>(
              segments: const [
                ButtonSegment(
                  value: MealPlannerAlgorithm.knapsack,
                  label: Text('Knapsack'),
                  icon: Icon(Icons.functions),
                ),
                ButtonSegment(
                  value: MealPlannerAlgorithm.randomGreedy,
                  label: Text('Random greedy'),
                  icon: Icon(Icons.shuffle),
                ),
              ],
              selected: {_algorithm},
              onSelectionChanged: (s) =>
                  setState(() => _algorithm = s.first),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _building ? null : _buildPlan,
              icon: _building
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.shopping_basket_outlined),
              label: Text(_building ? 'Building…' : 'Create calorie baskets'),
            ),
            if (_plan != null) ...[
              const SizedBox(height: 24),
              _sectionTitle('Your BMR & targets'),
              Text(
                'Estimated BMR: ${_plan!.bmr.toStringAsFixed(1)} kcal/day '
                '(breakfast 50%, lunch ⅓, dinner ⅙ — same as Python).',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMid, height: 1.4),
              ),
              const SizedBox(height: 12),
              MealBasketCard(basket: _plan!.breakfast),
              const SizedBox(height: 12),
              MealBasketCard(basket: _plan!.lunch),
              const SizedBox(height: 12),
              MealBasketCard(basket: _plan!.dinner),
              const SizedBox(height: 8),
              Text(
                'Total selected: ${_plan!.totalPlanCalories} kcal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: (_generatingAi ||
                        (_plan!.breakfast.items.isEmpty &&
                            _plan!.lunch.items.isEmpty &&
                            _plan!.dinner.items.isEmpty))
                    ? null
                    : _generateAiNarratives,
                icon: _generatingAi
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(_generatingAi ? 'Calling Groq…' : 'Generate AI meal descriptions (Groq)'),
              ),
              if (!_groq.isConfigured)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Groq is optional. Build with: --dart-define=GROQ_API_KEY=... '
                    'Optional: --dart-define=GROQ_MODEL=llama-3.3-70b-versatile',
                    style: TextStyle(fontSize: 11, color: AppTheme.textLight, height: 1.35),
                  ),
                ),
              if (_aiBreakfast != null) ...[
                const SizedBox(height: 16),
                _aiBlock('Breakfast story', _aiBreakfast!),
              ],
              if (_aiLunch != null) _aiBlock('Lunch story', _aiLunch!),
              if (_aiDinner != null) _aiBlock('Dinner story', _aiDinner!),
              const SizedBox(height: 24),
              _sectionTitle('🍽️ Food Image Analysis'),
              const Text(
                'Snap a photo of your meal to get instant AI-powered nutritional analysis!',
                style: TextStyle(fontSize: 13, color: AppTheme.textMid, height: 1.4),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _analyzingImage ? null : _showImageSourceDialog,
                icon: _analyzingImage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_analyzingImage ? 'Analyzing...' : 'Scan Food Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_selectedImageFile != null) ...[
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FutureBuilder<Uint8List>(
                    future: _selectedImageFile!.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Center(child: Icon(Icons.error));
                      }
                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                    },
                  ),
                ),
              ],
              if (_imageAnalysis != null) ...[
                const SizedBox(height: 16),
                _aiBlock('🍲 Food Analysis', _imageAnalysis!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppTheme.textDark,
          ),
        ),
      );

  Widget _aiBlock(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryGreen,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(fontSize: 13, height: 1.45, color: AppTheme.textDark),
              ),
            ],
          ),
        ),
      );
}
