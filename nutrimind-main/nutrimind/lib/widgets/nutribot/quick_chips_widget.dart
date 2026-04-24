import 'package:flutter/material.dart';
import '../../theme/modern_app_theme.dart';

class QuickChipsWidget extends StatelessWidget {
  final List<String> chips;
  final ValueChanged<String> onTap;
  final bool enabled;

  const QuickChipsWidget({
    super.key,
    required this.chips,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final visibleChips = chips.take(4).toList(growable: false);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: visibleChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _Chip(
          label: visibleChips[i],
          onTap: enabled ? () => onTap(visibleChips[i]) : null,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _Chip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: disabled ? ModernAppTheme.lightGray : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                disabled ? ModernAppTheme.divider : ModernAppTheme.accentGreen,
            width: 1.2,
          ),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: ModernAppTheme.primaryGreen.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: disabled
                ? ModernAppTheme.textLight
                : ModernAppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }
}
