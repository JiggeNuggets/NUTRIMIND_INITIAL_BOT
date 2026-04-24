import 'package:flutter/material.dart';

import '../../models/meal_planner_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/modern_app_theme.dart';

class MealBasketCard extends StatelessWidget {
  const MealBasketCard({
    super.key,
    required this.basket,
  });

  final MealBasket basket;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(ModernAppTheme.radiusXl),
        border: Border.all(color: AppTheme.divider),
        boxShadow: ModernAppTheme.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: ModernAppTheme.gradientPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                basket.slot.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const Spacer(),
              Text(
                '${basket.totalCalories} / ~${basket.targetCalories.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (basket.items.isEmpty)
            const Text(
              'No items fit this target with current filters. Try relaxing exclusions or switching algorithm.',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.textMid, height: 1.4),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: basket.items
                      .map(
                        (item) => Chip(
                          label: Text(
                            item.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: item.isCalorieOnlyFallback
                              ? AppTheme.orangeAccent.withValues(alpha: 0.12)
                              : AppTheme.softGreen,
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metric('${basket.totalCalories}', 'kcal'),
                    _metric(
                      basket.items.any((item) => item.hasPrice)
                          ? 'P${basket.totalPricePhp.toStringAsFixed(0)}'
                          : 'TBA',
                      'price',
                    ),
                    if (basket.totalProtein > 0)
                      _metric('${basket.totalProtein}g', 'protein'),
                    if (basket.totalCarbs > 0)
                      _metric('${basket.totalCarbs}g', 'carbs'),
                    if (basket.totalFat > 0)
                      _metric('${basket.totalFat}g', 'fat'),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (basket.items.any((item) => item.isLocalDavao))
                      _sourcePill('local Davao food', AppTheme.primaryGreen),
                    if (basket.hasCalorieOnlyFallback)
                      _sourcePill(
                        'calorie-only fallback',
                        AppTheme.orangeAccent,
                      ),
                  ],
                ),
                if (basket.hasCalorieOnlyFallback) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Fallback items are prototype calorie estimates and are not counted toward strict budget totals.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: AppTheme.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: ModernAppTheme.backgroundNeutral,
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: AppTheme.textDark,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          children: [
            TextSpan(text: value),
            TextSpan(
              text: ' $label',
              style: const TextStyle(
                color: AppTheme.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourcePill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
