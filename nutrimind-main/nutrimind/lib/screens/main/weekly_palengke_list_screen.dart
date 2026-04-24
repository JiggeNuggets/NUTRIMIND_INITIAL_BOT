import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/meal_model.dart';
import '../../models/palengke_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../services/palengke_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';

class WeeklyPalengkeListScreen extends StatefulWidget {
  const WeeklyPalengkeListScreen({super.key});

  @override
  State<WeeklyPalengkeListScreen> createState() =>
      _WeeklyPalengkeListScreenState();
}

class _WeeklyPalengkeListScreenState extends State<WeeklyPalengkeListScreen> {
  final PalengkeService _palengkeService = PalengkeService();

  late Future<void> _loadFuture;
  late DateTime _anchorDate;
  late DateTime _weekStart;
  late DateTime _weekEnd;
  bool _initialized = false;
  bool _savingListState = false;
  String _uid = '';
  List<MealModel> _weeklyMeals = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final selectedDate = context.read<MealProvider>().selectedDate;
    _anchorDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    _weekStart = _startOfWeek(_anchorDate);
    _weekEnd = _weekStart.add(const Duration(days: 6));
    _loadFuture = _loadWeeklyMeals();
  }

  Future<void> _loadWeeklyMeals() async {
    final uid = context.read<AuthProvider>().userModel?.uid ?? '';
    _uid = uid;
    final mealProvider = context.read<MealProvider>();
    final meals = await mealProvider.getMealsForWeek(uid, _anchorDate);
    _weeklyMeals = meals;
    await _palengkeService.generateAndPersistWeeklyList(
      uid: uid,
      weekId: _weekId,
      weekStart: _weekStart,
      weekEnd: _weekEnd,
      meals: meals,
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernAppTheme.backgroundNeutral,
      appBar: AppBar(
        backgroundColor: ModernAppTheme.backgroundNeutral,
        surfaceTintColor: Colors.transparent,
        title: const Text('Weekly Grocery & Palengke List'),
      ),
      body: Column(
        children: [
          _buildWeekHeader(),
          Expanded(
            child: FutureBuilder<void>(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildStateMessage(
                    icon: Icons.error_outline,
                    title: 'Could not load Palengke List',
                    message: 'Please check your connection and try again.',
                    action: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _loadFuture = _loadWeeklyMeals();
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  );
                }

                if (_weeklyMeals.isEmpty) {
                  return _buildStateMessage(
                    icon: Icons.shopping_basket_outlined,
                    title: 'No saved meals for this week yet.',
                    message:
                        'Save meals from the AI Planner, Scanner, or Manual Log first.',
                    action: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to Plan'),
                    ),
                  );
                }

                if (_palengkeService.items.isEmpty) {
                  return _buildStateMessage(
                    icon: Icons.checklist_outlined,
                    title: 'No ingredients found yet',
                    message:
                        'Saved meals need ingredients before NutriMind can build a Palengke List.',
                    action: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to Plan'),
                    ),
                  );
                }

                return _buildListContent();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ModernAppTheme.white,
          borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
          border: Border.all(color: ModernAppTheme.divider),
          boxShadow: ModernAppTheme.shadowSm,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.calendar_month_outlined,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected Week',
                    style: TextStyle(
                      color: AppTheme.textMid,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatWeekRange(),
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent() {
    final items = _palengkeService.items;
    final boughtCount = items.where((item) => item.isBought).length;
    final totalCost = _palengkeService.calculateTotalCost();
    final progress = items.isEmpty ? 0.0 : boughtCount / items.length;
    final configError = _palengkeService.marketConfigError;
    final persistenceError = _palengkeService.persistenceError;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text(
          _palengkeService.usesPrototypeEstimates
              ? '${PalengkeService.prototypeDisclosure} List is based on saved meals from Monday to Sunday.'
              : 'List is based on saved meals from Monday to Sunday. Prices and categories loaded from Firestore market config.',
          style: const TextStyle(
            color: AppTheme.textMid,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (configError != null) ...[
          const SizedBox(height: 8),
          Text(
            'Market config could not be loaded, so prototype estimates are shown.',
            style: TextStyle(
              color: AppTheme.orangeAccent.withValues(alpha: 0.90),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (persistenceError != null) ...[
          const SizedBox(height: 8),
          Text(
            'Palengke List sync is unavailable. You can still view the generated list, but bought-state changes may not persist until Firestore rules/config are ready.',
            style: TextStyle(
              color: AppTheme.orangeAccent.withValues(alpha: 0.90),
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildSummaryCard(
          totalCost: totalCost,
          itemCount: items.length,
          boughtCount: boughtCount,
          progress: progress,
        ),
        const SizedBox(height: 16),
        _buildActionButtons(),
        const SizedBox(height: 18),
        ...PalengkeService.marketCategories.map(
          (category) => _buildMarketSection(
            category,
            items
                .where((item) => item.marketCategory == category)
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required double totalCost,
    required int itemCount,
    required int boughtCount,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ModernAppTheme.darkGreen, ModernAppTheme.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: ModernAppTheme.primaryGreen.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shopping_basket_outlined,
                  color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text(
                'PALENGKE BUDGET',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'PHP ${totalCost.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _summaryStat('$itemCount', 'items'),
              _summaryDivider(),
              _summaryStat('$boughtCount', 'bought'),
              _summaryDivider(),
              _summaryStat('${(progress * 100).round()}%', 'done'),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _palengkeService.usesPrototypeEstimates
                ? 'Prototype estimates. Not live market prices.'
                : 'Firestore market price config.',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _summaryStat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.22),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _savingListState
                    ? null
                    : () => _runListMutation(
                          () => _palengkeService.markAllAsBought(
                            uid: _uid,
                            weekId: _weekId,
                          ),
                        ),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Mark All as Bought'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _savingListState
                  ? null
                  : () => _runListMutation(
                        () => _palengkeService.resetBoughtItems(
                          uid: _uid,
                          weekId: _weekId,
                        ),
                      ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(110, 48),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Plan'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: AppTheme.textMid,
              side: const BorderSide(color: AppTheme.divider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarketSection(
    String category,
    List<PalengkeItemModel> categoryItems,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
          border: Border.all(color: AppTheme.divider),
          boxShadow: ModernAppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(
                    _categoryIcon(category),
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _smallCountChip(categoryItems.length),
                ],
              ),
            ),
            if (categoryItems.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'No items estimated here.',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 12),
                ),
              )
            else
              ...categoryItems.map(_buildItemRow),
          ],
        ),
      ),
    );
  }

  Widget _smallCountChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.softGreen,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppTheme.primaryGreen,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildItemRow(PalengkeItemModel item) {
    return InkWell(
      onTap: () {
        if (_savingListState) return;
        _runListMutation(
          () => _palengkeService.toggleBought(
            uid: _uid,
            weekId: _weekId,
            itemId: item.id,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 14, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: item.isBought,
              activeColor: AppTheme.primaryGreen,
              onChanged: _savingListState
                  ? null
                  : (_) => _runListMutation(
                        () => _palengkeService.toggleBought(
                          uid: _uid,
                          weekId: _weekId,
                          itemId: item.id,
                        ),
                      ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color:
                          item.isBought ? AppTheme.textMid : AppTheme.textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration:
                          item.isBought ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.softGreen,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      item.isPrototypeEstimate
                          ? 'prototype estimate'
                          : 'market config',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'PHP ${item.estimatedPricePhp.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runListMutation(Future<void> Function() mutation) async {
    if (_savingListState) return;
    setState(() => _savingListState = true);
    try {
      await mutation();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save Palengke List changes.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingListState = false);
    }
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accentGreen),
              ),
              child: Icon(icon, color: AppTheme.primaryGreen, size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMid,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            action,
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      PalengkeService.publicMarket => Icons.storefront_outlined,
      PalengkeService.supermarket => Icons.local_grocery_store_outlined,
      _ => Icons.kitchen_outlined,
    };
  }

  String _formatWeekRange() {
    final sameMonth =
        _weekStart.year == _weekEnd.year && _weekStart.month == _weekEnd.month;
    final sameYear = _weekStart.year == _weekEnd.year;
    if (sameMonth) {
      return '${DateFormat('MMMM d').format(_weekStart)} - ${_weekEnd.day}, ${_weekEnd.year}';
    }
    if (sameYear) {
      return '${DateFormat('MMMM d').format(_weekStart)} - ${DateFormat('MMMM d, y').format(_weekEnd)}';
    }
    return '${DateFormat('MMMM d, y').format(_weekStart)} - ${DateFormat('MMMM d, y').format(_weekEnd)}';
  }

  String get _weekId => DateFormat('yyyy-MM-dd').format(_weekStart);
}
