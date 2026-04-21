import 'package:flutter/material.dart';

import '../../models/meal_planner_models.dart';
import '../../theme/app_theme.dart';

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              style: TextStyle(fontSize: 12, color: AppTheme.textMid, height: 1.4),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: basket.items
                  .map(
                    (id) => Chip(
                      label: Text(
                        _formatItemId(id),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: AppTheme.softGreen,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  static String _formatItemId(String id) =>
      id.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');
}
