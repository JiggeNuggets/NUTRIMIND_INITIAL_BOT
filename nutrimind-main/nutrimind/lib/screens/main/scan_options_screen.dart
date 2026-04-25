import 'package:flutter/material.dart';

import '../../theme/modern_app_theme.dart';
import 'food_scanner_screen.dart';
import 'pantry_screen.dart';
import 'scan_history_screen.dart';

class ScanOptionsScreen extends StatelessWidget {
  const ScanOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernAppTheme.bgGreen,
      appBar: AppBar(
        title: const Text('Add Food'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: ModernAppTheme.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ModernAppTheme.mediumGray),
                boxShadow: ModernAppTheme.shadowSm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: ModernAppTheme.gradientPrimary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How do you want to add food?',
                          style: TextStyle(
                            color: ModernAppTheme.textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choose the right flow for cooked meals, pantry ingredients, or manual logs.',
                          style: TextStyle(
                            color: ModernAppTheme.textMid,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openScanHistory(context),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('View Scan History'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                alignment: Alignment.center,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Choose input method',
              style: TextStyle(
                color: ModernAppTheme.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _ScanOptionCard(
              icon: Icons.document_scanner_outlined,
              iconColor: ModernAppTheme.primaryGreen,
              title: 'Scan Meal',
              subtitle: 'Use AI food scanner for cooked meals.',
              trailingLabel: 'Meal Log after review',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FoodScannerScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ScanOptionCard(
              icon: Icons.kitchen_outlined,
              iconColor: ModernAppTheme.warning,
              title: 'Add Pantry Item',
              subtitle: 'Track ingredients at home or palengke items.',
              trailingLabel: 'Saves to Pantry',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PantryScreen(openAddOnStart: true),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ScanOptionCard(
              icon: Icons.qr_code_scanner_outlined,
              iconColor: ModernAppTheme.info,
              title: 'Barcode Scan',
              subtitle: 'For supermarket/package items only.',
              trailingLabel: 'Coming Soon',
              onTap: () => _showBarcodeComingSoon(context),
            ),
            const SizedBox(height: 12),
            _ScanOptionCard(
              icon: Icons.edit_note_outlined,
              iconColor: ModernAppTheme.pastelPurple,
              title: 'Manual Meal Log',
              subtitle: 'Enter a meal yourself without scanning.',
              trailingLabel: 'Meal Log',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FoodScannerScreen(
                    openManualLogOnStart: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openScanHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ScanHistoryScreen(),
      ),
    );
  }

  static void _showBarcodeComingSoon(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Barcode Scan Coming Soon'),
        content: const Text(
          'This will be for supermarket/package items only. No barcode data is added yet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _ScanOptionCard extends StatelessWidget {
  const _ScanOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ModernAppTheme.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ModernAppTheme.mediumGray),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: ModernAppTheme.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: ModernAppTheme.textMid,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      trailingLabel,
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: ModernAppTheme.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
