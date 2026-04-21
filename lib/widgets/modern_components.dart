import 'package:flutter/material.dart';
import 'modern_app_theme.dart';

/// ============================================================================
/// MODERN BUTTON COMPONENTS
/// ============================================================================

/// Premium primary button with gradient and smooth interactions
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isDisabled;
  final double? width;
  final IconData? iconData;
  final Color? customColor;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.width,
    this.iconData,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: isDisabled
            ? LinearGradient(
                colors: [
                  ModernAppTheme.mediumGray.withValues(alpha: 0.5),
                  ModernAppTheme.lightGray.withValues(alpha: 0.5),
                ],
              )
            : ModernAppTheme.gradientPrimary,
        borderRadius:
            BorderRadius.circular(ModernAppTheme.radiusMd),
        boxShadow: isDisabled
            ? ModernAppTheme.shadowNone
            : ModernAppTheme.shadowMd,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled || isLoading ? null : onPressed,
          borderRadius:
              BorderRadius.circular(ModernAppTheme.radiusMd),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (iconData != null) ...[
                        Icon(iconData, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button with soft background
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isDisabled;
  final IconData? iconData;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isDisabled = false,
    this.iconData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDisabled
            ? ModernAppTheme.mediumGray.withValues(alpha: 0.3)
            : ModernAppTheme.softGreen,
        borderRadius:
            BorderRadius.circular(ModernAppTheme.radiusMd),
        border: Border.all(
          color: isDisabled
              ? ModernAppTheme.mediumGray
              : ModernAppTheme.accentGreen,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius:
              BorderRadius.circular(ModernAppTheme.radiusMd),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconData != null) ...[
                  Icon(iconData,
                      color: ModernAppTheme.primaryGreen, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: ModernAppTheme.primaryGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// CARD COMPONENTS
/// ============================================================================

/// Premium meal card with expandable content
class MealCard extends StatefulWidget {
  final String mealName;
  final String mealType; // 'Breakfast', 'Lunch', etc.
  final double price;
  final int calories;
  final bool isLogged;
  final List<String> ingredients;
  final int protein;
  final int carbs;
  final int fat;
  final VoidCallback onExpand;
  final VoidCallback? onRecipe;
  final VoidCallback? onDelete;
  final VoidCallback? onLog;

  const MealCard({
    super.key,
    required this.mealName,
    required this.mealType,
    required this.price,
    required this.calories,
    required this.isLogged,
    required this.ingredients,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.onExpand,
    this.onRecipe,
    this.onDelete,
    this.onLog,
  });

  @override
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    widget.onExpand();
  }

  String _getMealEmoji(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return '🥞';
      case 'lunch':
        return '🍚';
      case 'dinner':
        return '🍜';
      case 'snack':
        return '🍌';
      default:
        return '🍽️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ModernAppTheme.white,
        borderRadius:
            BorderRadius.circular(ModernAppTheme.radiusLg),
        border: Border.all(
          color: widget.isLogged
              ? ModernAppTheme.accentGreen
              : ModernAppTheme.mediumGray,
          width: 1,
        ),
        boxShadow: ModernAppTheme.shadowMd,
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _toggleExpand,
            borderRadius:
                BorderRadius.circular(ModernAppTheme.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(
                  ModernAppTheme.spacingLg),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: widget.isLogged
                          ? ModernAppTheme.softGreen
                          : ModernAppTheme.lightGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _getMealEmoji(widget.mealType),
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: ModernAppTheme.spacingLg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    ModernAppTheme.softGreen,
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.mealType,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: ModernAppTheme
                                      .primaryGreen,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                            if (widget.isLogged) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      ModernAppTheme.softGreen,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Logged ✓',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: ModernAppTheme
                                        .primaryGreen,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.mealName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w700,
                            color: widget.isLogged
                                ? ModernAppTheme.textMid
                                : ModernAppTheme.textDark,
                            decoration:
                                widget.isLogged
                                    ? TextDecoration
                                        .lineThrough
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '₱${widget.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                                fontSize: 13,
                                color: ModernAppTheme
                                    .primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    ModernAppTheme.mediumGray,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.calories} kcal',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ModernAppTheme.textMid,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (!widget.isLogged &&
                          widget.onLog != null)
                        GestureDetector(
                          onTap: widget.onLog,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: ModernAppTheme
                                  .primaryGreen,
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Log',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      RotationTransition(
                        turns: Tween(begin: 0.0, end: 0.5)
                            .animate(
                                _animationController),
                        child: const Icon(
                          Icons
                              .keyboard_arrow_down,
                          color: ModernAppTheme
                              .textLight,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded)
            Column(
              children: [
                const Divider(
                  color: ModernAppTheme.mediumGray,
                  height: 1,
                ),
                Padding(
                  padding: const EdgeInsets.all(
                      ModernAppTheme.spacingLg),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // Ingredients
                      if (widget.ingredients
                          .isNotEmpty) ...[
                        const Text(
                          'Ingredients',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w700,
                            fontSize: 13,
                            color: ModernAppTheme
                                .textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget
                              .ingredients
                              .map((ing) =>
                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color: ModernAppTheme
                                          .softGreen,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  8),
                                    ),
                                    child: Text(
                                      ing,
                                      style:
                                          const TextStyle(
                                        fontSize: 11,
                                        color: ModernAppTheme
                                            .primaryGreen,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                      ],
                      // Macros
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceAround,
                        children: [
                          _MacroDisplay(
                            value:
                                widget.protein
                                    .toString(),
                            label: 'Protein',
                            color: ModernAppTheme
                                .info,
                          ),
                          _MacroDisplay(
                            value: widget.carbs
                                .toString(),
                            label: 'Carbs',
                            color: ModernAppTheme
                                .warning,
                          ),
                          _MacroDisplay(
                            value:
                                widget.fat.toString(),
                            label: 'Fat',
                            color: ModernAppTheme
                                .error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Action buttons
                      Row(
                        children: [
                          if (widget.onRecipe !=
                              null)
                            Expanded(
                              child:
                                  SecondaryButton(
                                label: '🍳 View Recipe',
                                onPressed:
                                    widget
                                        .onRecipe!,
                              ),
                            ),
                          if (widget.onDelete !=
                              null) ...[
                            const SizedBox(
                                width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: widget
                                    .onDelete,
                                child: Container(
                                  height: 48,
                                  decoration:
                                      BoxDecoration(
                                    color: ModernAppTheme
                                        .error
                                        .withValues(
                                          alpha:
                                              0.1,
                                        ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                              ModernAppTheme
                                                  .radiusMd,
                                            ),
                                    border: Border.all(
                                      color: ModernAppTheme
                                          .error,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '× Delete',
                                      style:
                                          TextStyle(
                                        color: ModernAppTheme
                                            .error,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Helper widget for displaying macro nutrients
class _MacroDisplay extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MacroDisplay({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value + 'g',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: ModernAppTheme.textMid,
          ),
        ),
      ],
    );
  }
}

/// ============================================================================
/// NUTRITION SUMMARY CARD
/// ============================================================================

class NutritionSummaryCard extends StatelessWidget {
  final double bmi;
  final String bmiCategory;
  final double height; // cm
  final double weight; // kg
  final int age;
  final String gender;
  final String advice;

  const NutritionSummaryCard({
    super.key,
    required this.bmi,
    required this.bmiCategory,
    required this.height,
    required this.weight,
    required this.age,
    required this.gender,
    required this.advice,
  });

  @override
  Widget build(BuildContext context) {
    final gradient =
        ModernAppTheme.getBmiGradient(bmiCategory);

    return Container(
      padding: const EdgeInsets.all(
          ModernAppTheme.spacingLg),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(
            ModernAppTheme.radiusXl),
        boxShadow: ModernAppTheme.shadowLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monitor_weight_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Body Mass Index (BMI)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                bmi.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                bmiCategory,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            advice,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// GRADIENT BACKGROUND
/// ============================================================================

class GradientBackground extends StatelessWidget {
  final Widget child;
  final LinearGradient? gradient;

  const GradientBackground({
    super.key,
    required this.child,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ??
            const LinearGradient(
              colors: [
                ModernAppTheme.white,
                ModernAppTheme.backgroundNeutral,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      ),
      child: child,
    );
  }
}
