import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';
import '../../models/meal_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../services/groq_meal_narrative_service.dart';

class GeneratedRecipeScreen extends StatefulWidget {
  final MealModel meal;

  const GeneratedRecipeScreen({super.key, required this.meal});

  @override
  State<GeneratedRecipeScreen> createState() => _GeneratedRecipeScreenState();
}

class _GeneratedRecipeScreenState extends State<GeneratedRecipeScreen> {
  late final GroqMealNarrativeService _groq;

  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _recipeDescription;
  List<String> _cookingSteps = [];

  bool get _alreadySaved =>
      widget.meal.recipe != null && widget.meal.recipe!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _groq = GroqMealNarrativeService();
    if (_alreadySaved) {
      _recipeDescription = widget.meal.recipe;
      _cookingSteps = List<String>.from(widget.meal.cookingSteps);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateRecipe());
    }
  }

  @override
  void dispose() {
    _groq.dispose();
    super.dispose();
  }

  Future<void> _generateRecipe() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _groq.generateRecipeSteps(
        widget.meal.name,
        widget.meal.ingredients,
      );
      if (mounted) {
        setState(() {
          _recipeDescription = result['description'] as String? ?? '';
          _cookingSteps = List<String>.from(result['steps'] as List? ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to generate recipe. Please try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveRecipe() async {
    if (_recipeDescription == null || _recipeDescription!.isEmpty) return;
    final user = context.read<AuthProvider>().userModel;
    final uid = user?.uid ?? '';
    setState(() => _saving = true);
    try {
      await context.read<MealProvider>().updateMealRecipe(
            uid,
            widget.meal.id,
            _recipeDescription!,
            _cookingSteps,
            displayName: user?.name ?? '',
            photoUrl: user?.photoUrl,
            dailyBudget: user?.dailyBudget ?? 150,
          );
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Recipe saved to meal log!'),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return Scaffold(
      backgroundColor: ModernAppTheme.backgroundNeutral,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.backgroundNeutral,
        surfaceTintColor: Colors.transparent,
        title: const Text('Recipe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_recipeDescription != null && !_alreadySaved)
            _saving
                ? const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  )
                : TextButton.icon(
                    onPressed: _saveRecipe,
                    icon: const Icon(Icons.save_outlined,
                        size: 16, color: AppTheme.primaryGreen),
                    label: const Text('Save',
                        style: TextStyle(
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600)),
                  ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMealHeader(meal),
            const SizedBox(height: 16),
            if (meal.ingredients.isNotEmpty) ...[
              _sectionTitle('Ingredients'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: meal.ingredients
                    .map((ing) => _ingredientChip(ing))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],
            if (meal.protein > 0 || meal.carbs > 0 || meal.fat > 0) ...[
              _sectionTitle('Nutrition'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _macroCard('${meal.protein}g', 'Protein', AppTheme.infoBlue),
                  const SizedBox(width: 8),
                  _macroCard('${meal.carbs}g', 'Carbs', AppTheme.orangeAccent),
                  const SizedBox(width: 8),
                  _macroCard('${meal.fat}g', 'Fat', AppTheme.errorRed),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (_loading)
              _buildLoadingState()
            else if (_error != null)
              _buildErrorState()
            else if (_recipeDescription != null) ...[
              _sectionTitle('Recipe Description'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: ModernAppTheme.shadowSm,
                ),
                child: Text(
                  _recipeDescription!,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textMid, height: 1.6),
                ),
              ),
              const SizedBox(height: 20),
              if (_cookingSteps.isNotEmpty) ...[
                _sectionTitle('Cooking Steps'),
                const SizedBox(height: 8),
                ..._cookingSteps.asMap().entries.map(
                      (e) => _buildStepCard(e.key + 1, e.value),
                    ),
              ],
              const SizedBox(height: 8),
              if (_alreadySaved)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.softGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle,
                          color: AppTheme.primaryGreen, size: 18),
                      SizedBox(width: 8),
                      Text('Saved to Meal Log',
                          style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveRecipe,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Save to Meal Log'),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 50)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMealHeader(MealModel meal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ModernAppTheme.gradientWarm,
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(_mealEmoji(meal.type),
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _typeChip(meal.typeLabel),
                    const SizedBox(height: 4),
                    Text(
                      meal.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppTheme.textDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statItem(Icons.local_fire_department_outlined,
                  '${meal.calories} kcal', AppTheme.orangeAccent),
              const SizedBox(width: 16),
              _statItem(Icons.attach_money, '₱${meal.price.toStringAsFixed(0)}',
                  AppTheme.primaryGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 16),
            Text('Generating recipe with AI...',
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text('This may take a few seconds',
                style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 32),
          const SizedBox(height: 8),
          Text(_error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _generateRecipe,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              minimumSize: const Size(120, 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(int num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: ModernAppTheme.shadowSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$num',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textDark, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textDark));

  Widget _ingredientChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.softGreen,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w600)),
      );

  Widget _macroCard(String value, String label, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15, color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMid,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );

  Widget _typeChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.softGreen,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.w700)),
      );

  Widget _statItem(IconData icon, String text, Color color) => Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      );

  String _mealEmoji(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return '🌅';
      case MealType.lunch:
        return '🍱';
      case MealType.dinner:
        return '🍽️';
      case MealType.snack:
        return '🍌';
    }
  }
}
