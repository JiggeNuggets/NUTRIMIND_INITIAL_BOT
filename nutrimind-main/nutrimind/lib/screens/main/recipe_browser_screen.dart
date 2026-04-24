import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/nutribot_models.dart';
import '../../models/recipe_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/recipe_api_service.dart';
import '../../theme/modern_app_theme.dart';
import '../../widgets/nutribot/nutribot_launcher.dart';

class RecipeBrowserScreen extends StatefulWidget {
  const RecipeBrowserScreen({super.key});

  @override
  State<RecipeBrowserScreen> createState() => _RecipeBrowserScreenState();
}

class _RecipeBrowserScreenState extends State<RecipeBrowserScreen> {
  static const int _defaultLimit = 50;
  static const List<(String value, String label)> _mealTypeOptions = [
    ('all', 'All'),
    ('breakfast', 'Breakfast'),
    ('lunch/dinner', 'Lunch / Dinner'),
    ('snack', 'Snack'),
    ('teatime', 'Tea Time'),
    ('brunch', 'Brunch'),
  ];

  late final TextEditingController _searchController;
  late final RecipeApiService _recipeApiService;

  Timer? _searchDebounce;
  List<RecipeModel> _recipes = const [];
  bool _loading = true;
  String? _error;
  String _selectedMealType = 'all';
  int _requestId = 0;
  bool _backendHealthy = true;
  late String _dataNotice;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _recipeApiService = RecipeApiService();
    _dataNotice = _recipeApiService.disclosure;
    _runInitialLoad();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _recipeApiService.dispose();
    super.dispose();
  }

  Future<void> _runInitialLoad() async {
    await _checkHealth();
    await _loadRecipes();
  }

  Future<void> _checkHealth() async {
    try {
      final health = await _recipeApiService.healthCheck();
      if (!mounted) return;
      setState(() {
        _backendHealthy = true;
        _dataNotice = _recipeApiService.disclosureFromHealth(health);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _backendHealthy = false;
        _dataNotice = _recipeApiService.disclosure;
      });
    }
  }

  Future<void> _loadRecipes() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final recipes = await _recipeApiService.fetchRecipes(
        query: _searchController.text,
        limit: _defaultLimit,
        mealType: _selectedMealType == 'all' ? null : _selectedMealType,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _recipes = recipes;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _recipes = const [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadRecipes);
  }

  NutribotContext _buildBrowserNutribotContext() {
    final user = context.read<AuthProvider>().userModel;

    return NutribotContext(
      source: NutribotSource.recipeBrowser,
      contextTitle: 'Recipe Helper',
      sourceContext: 'Recipe Browser',
      initialPrompt:
          'Help me find recipes that match my current nutrition goals and budget.',
      userGoal: user?.goal,
      data: {
        if (_searchController.text.trim().isNotEmpty)
          'searchQuery': _searchController.text.trim(),
        'mealTypeFilter': _selectedMealType,
        'resultsLoaded': _recipes.length,
      },
    );
  }

  NutribotContext _buildRecipeNutribotContext(RecipeModel recipe) {
    final user = context.read<AuthProvider>().userModel;

    return NutribotContext(
      source: NutribotSource.recipeBrowser,
      contextTitle: 'Recipe Helper',
      sourceContext: 'Recipe details for ${recipe.recipeName}',
      initialPrompt:
          'Explain this recipe and suggest a healthier or more budget-friendly version.',
      userGoal: user?.goal,
      attachedRecipe: NutribotPayloads.recipe(recipe),
      data: {
        if (_searchController.text.trim().isNotEmpty)
          'searchQuery': _searchController.text.trim(),
        'mealTypeFilter': _selectedMealType,
      },
    );
  }

  Future<void> _showRecipeDetails(RecipeModel recipe) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Container(
            decoration: const BoxDecoration(
              color: ModernAppTheme.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: FutureBuilder<RecipeModel>(
              future: _recipeApiService.fetchRecipeById(recipe.id),
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ModernAppTheme.primaryGreen,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _DetailScaffold(
                    child: _StateBox(
                      icon: Icons.error_outline,
                      title: 'Recipe details are unavailable',
                      message: snapshot.error.toString(),
                    ),
                  );
                }

                final detail = snapshot.data ?? recipe;
                return _DetailScaffold(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: ModernAppTheme.mediumGray,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            height: 220,
                            width: double.infinity,
                            child: detail.imageUrl == null
                                ? _placeholderImage(iconSize: 42)
                                : Image.network(
                                    detail.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _placeholderImage(iconSize: 42),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _DataNoticeBox(
                          message: detail.dataNotice.trim().isEmpty
                              ? _dataNotice
                              : detail.dataNotice,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          detail.recipeName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: ModernAppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _detailChip(
                              Icons.local_fire_department_outlined,
                              '${detail.calories} kcal',
                            ),
                            if (detail.mealTypeDisplay.isNotEmpty)
                              _detailChip(
                                Icons.breakfast_dining_outlined,
                                detail.mealTypeDisplay,
                              ),
                            if (detail.cuisineTypes.isNotEmpty)
                              _detailChip(
                                Icons.public_outlined,
                                detail.cuisineTypeDisplay,
                              ),
                            if (detail.servings != null)
                              _detailChip(
                                Icons.people_outline,
                                '${detail.servings} servings',
                              ),
                            if (detail.protein > 0)
                              _detailChip(
                                Icons.fitness_center_outlined,
                                '${detail.protein}g protein',
                              ),
                            if (detail.carbs > 0)
                              _detailChip(
                                Icons.grain_outlined,
                                '${detail.carbs}g carbs',
                              ),
                            if (detail.fat > 0)
                              _detailChip(
                                Icons.opacity_outlined,
                                '${detail.fat}g fat',
                              ),
                            _detailChip(
                              Icons.payments_outlined,
                              detail.hasPriceEstimate
                                  ? 'PHP ${detail.estimatedPricePhp.toStringAsFixed(0)} est.'
                                  : 'Price unavailable',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              NutribotLauncher.open(
                                context,
                                nutribotContext:
                                    _buildRecipeNutribotContext(detail),
                              );
                            },
                            icon:
                                const Icon(Icons.smart_toy_outlined, size: 18),
                            label: const Text('Ask NutriBot About This Recipe'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Ingredients',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ModernAppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (detail.displayIngredientLines.isEmpty)
                          const Text(
                            'No ingredient lines were available for this recipe.',
                            style: TextStyle(color: ModernAppTheme.textMid),
                          )
                        else
                          ...detail.displayIngredientLines.map(
                            (ingredient) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 7),
                                    child: Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: ModernAppTheme.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      ingredient,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.45,
                                        color: ModernAppTheme.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (detail.source.trim().isNotEmpty) ...[
                          const Text(
                            'Source',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ModernAppTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            detail.source.trim(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: ModernAppTheme.textMid,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (detail.url != null && detail.url!.trim().isNotEmpty)
                          SelectableText(
                            detail.url!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: ModernAppTheme.info,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showInitialLoading = _loading && _recipes.isEmpty && _error == null;

    return Scaffold(
      backgroundColor: ModernAppTheme.backgroundNeutral,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.backgroundNeutral,
        surfaceTintColor: Colors.transparent,
        title: const Text('Recipe Library'),
        actions: [
          NutribotAppBarAction(
            nutribotContext: _buildBrowserNutribotContext(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading && _recipes.isNotEmpty)
            const LinearProgressIndicator(
              color: ModernAppTheme.primaryGreen,
              minHeight: 2,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  _buildSearchPanel(),
                  const SizedBox(height: 16),
                  _DataNoticeBox(message: _dataNotice),
                  const SizedBox(height: 12),
                  if (!_backendHealthy)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ModernAppTheme.warmBlush,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ModernAppTheme.warning.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        'Backend health check did not succeed, but recipe requests may still work once the API is up.',
                        style: TextStyle(
                          fontSize: 12,
                          color: ModernAppTheme.textDark,
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Recipe API: ${_recipeApiService.baseUrl}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ModernAppTheme.textMid,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: showInitialLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: ModernAppTheme.primaryGreen,
                            ),
                          )
                        : _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ModernAppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) {
              _onSearchChanged(value);
              setState(() {});
            },
            onSubmitted: (_) => _loadRecipes(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search recipe names, cuisines, or ingredients',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _loadRecipes();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _mealTypeOptions.map((option) {
              final selected = _selectedMealType == option.$1;
              return ChoiceChip(
                label: Text(option.$2),
                selected: selected,
                onSelected: (_) {
                  if (selected) return;
                  setState(() => _selectedMealType = option.$1);
                  _loadRecipes();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: _StateBox(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load recipes',
          message: _error!,
          actionLabel: 'Try again',
          onPressed: _loadRecipes,
        ),
      );
    }

    if (_recipes.isEmpty) {
      return const Center(
        child: _StateBox(
          icon: Icons.menu_book_outlined,
          title: 'No recipes found',
          message: 'Try a different keyword or a wider meal type filter.',
        ),
      );
    }

    return RefreshIndicator(
      color: ModernAppTheme.primaryGreen,
      onRefresh: _loadRecipes,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
        itemCount: _recipes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildRecipeCard(_recipes[index]),
      ),
    );
  }

  Widget _buildRecipeCard(RecipeModel recipe) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRecipeDetails(recipe),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ModernAppTheme.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ModernAppTheme.divider),
            boxShadow: ModernAppTheme.shadowSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: recipe.imageUrl == null
                      ? _placeholderImage()
                      : Image.network(
                          recipe.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderImage(),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.recipeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ModernAppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _cardChip('${recipe.calories} kcal'),
                        if (recipe.mealTypeDisplay.isNotEmpty)
                          _cardChip(recipe.mealTypeDisplay),
                        if (recipe.cuisineTypes.isNotEmpty)
                          _cardChip(recipe.cuisineTypeDisplay),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      recipe.displayIngredientLines.take(2).join(' • '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: ModernAppTheme.textMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ModernAppTheme.softGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ModernAppTheme.primaryGreen,
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ModernAppTheme.softGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ModernAppTheme.primaryGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ModernAppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage({double iconSize = 28}) {
    return Container(
      color: ModernAppTheme.softGreen,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_menu_outlined,
        size: iconSize,
        color: ModernAppTheme.primaryGreen,
      ),
    );
  }
}

class _StateBox extends StatelessWidget {
  const _StateBox({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ModernAppTheme.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: ModernAppTheme.primaryGreen),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: ModernAppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: ModernAppTheme.textMid,
            ),
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onPressed,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _DataNoticeBox extends StatelessWidget {
  const _DataNoticeBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ModernAppTheme.warmBlush,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ModernAppTheme.warning.withValues(alpha: 0.26),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: ModernAppTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.trim(),
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: ModernAppTheme.textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(child: child),
        ],
      ),
    );
  }
}
